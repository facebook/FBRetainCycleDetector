/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#if __has_feature(objc_arc)
#error This file must be compiled with MRR. Use -fno-objc-arc flag.
#endif

#import "FBBlockStrongLayout.h"

#import <malloc/malloc.h>
#import <objc/runtime.h>

#import "FBBlockInterface.h"
#import "FBBlockStrongRelationDetector.h"

/**
 Validate that a raw pointer is safe to bridge to `id` and retain.
 Blocks may capture non-ObjC heap objects (e.g. Swift closure contexts),
 and blindly bridging those to `id` causes EXC_BAD_ACCESS in objc_retain.

 Validation chain:
  1. Non-null
  2. 8-byte aligned (all heap objects are)
  3. Non-heap pointers (e.g. global blocks in __DATA) are accepted — Swift
     capture boxes are always heap-allocated, so malloc_size == 0 is safe.
  4. For heap-allocated pointers, ISA must resolve to a class in __DATA
     (malloc_size == 0), not heap-allocated Swift metadata.
 */
static BOOL _FBIsRetainableObjCPointer(const void *ptr) {
  if (!ptr) return NO;
  if ((uintptr_t)ptr & 0x7) return NO;

  // Non-heap pointers (e.g. global blocks in __DATA) are valid ObjC objects
  // when they appear as strong captures in a block layout. Swift capture
  // box metadata — the thing we need to reject — is always heap-allocated.
  if (malloc_size(ptr) == 0) return YES;

  // Heap-allocated pointer: verify its ISA is a real ObjC class (lives in
  // __DATA, malloc_size == 0) rather than heap-allocated Swift metadata.
  Class cls = object_getClass((__bridge id)ptr);
  if (!cls) return NO;
  if (malloc_size((void *)cls) > 0) return NO;

  return YES;
}

/**
 Extract strong references from a block by parsing the block descriptor's
 layout encoding. The layout field describes which captured variables are
 strong, weak, byref, etc.

 The block descriptor is a variable-length structure. Fields after
 `reserved` and `size` are conditionally present depending on flag bits
 in the block literal. We must compute the layout field's offset
 dynamically rather than using a fixed struct member access.

 See: http://clang.llvm.org/docs/Block-ABI-Apple.html
 */

/**
 Compute the address of the layout field in the block descriptor.
 The descriptor has a variable layout:
   [reserved] [size]                                        -- always
   [copy_helper] [dispose_helper]                           -- if BLOCK_HAS_COPY_DISPOSE
   [signature]                                              -- if BLOCK_HAS_SIGNATURE
   [layout]                                                 -- if BLOCK_HAS_EXTENDED_LAYOUT
 */
static const char *_GetBlockDescriptorLayout(struct BlockLiteral *blockLiteral) {
  uint8_t *desc = (uint8_t *)blockLiteral->descriptor;

  // Skip past reserved and size (always present).
  desc += sizeof(unsigned long int); // reserved
  desc += sizeof(unsigned long int); // size

  if (blockLiteral->flags & BLOCK_HAS_COPY_DISPOSE) {
    desc += sizeof(void *); // copy_helper
    desc += sizeof(void *); // dispose_helper
  }

  if (blockLiteral->flags & BLOCK_HAS_SIGNATURE) {
    desc += sizeof(void *); // signature
  }

  return *(const char **)desc;
}

static NSArray *_GetStrongReferencesCompactLayout(struct BlockLiteral *blockLiteral, const char *layout) {
  NSMutableArray *strongReferences = [NSMutableArray array];

  int strongReferenceCount = ((uintptr_t)layout & 0xF00) >> 8;
  int byrefReferenceCount = ((uintptr_t)layout & 0x0F0) >> 4;

  uintptr_t *storagePointer = (uintptr_t *)((uintptr_t)blockLiteral + sizeof(*blockLiteral));
  if (strongReferenceCount > 0) {
    for (int i = 0; i < strongReferenceCount; i += 1, storagePointer += 1) {
      void *rawPtr = *((void **)storagePointer);
      if (rawPtr && _FBIsRetainableObjCPointer(rawPtr)) {
        [strongReferences addObject:(__bridge id)rawPtr];
      }
    }
  }

  if (byrefReferenceCount > 0) {
    for (int i = 0; i < byrefReferenceCount; i += 1, storagePointer += 1) {
      void *rawByref = *((void **)storagePointer);
      if (!rawByref || malloc_size(rawByref) == 0) continue;
      struct Block_byref *blockByref = (struct Block_byref *)rawByref;
      BOOL isStrongLayout = (blockByref->flags & BLOCK_BYREF_LAYOUT_MASK) == BLOCK_BYREF_LAYOUT_STRONG;
      BOOL hasCopyDispose = blockByref->flags & BLOCK_BYREF_HAS_COPY_DISPOSE;
      if (hasCopyDispose && isStrongLayout) {
        void *byrefDesc = (uint8_t *)blockByref + sizeof(*blockByref);
        void *rawPtr = *((void **)byrefDesc);
        if (rawPtr && _FBIsRetainableObjCPointer(rawPtr)) {
          [strongReferences addObject:(__bridge id)rawPtr];
        }
      }
    }
  }

  return strongReferences;
}

static NSArray *_GetStrongReferencesExtendedLayout(struct BlockLiteral *blockLiteral, const char *blockLayout)
{
  NSMutableArray *strongReferences = [NSMutableArray array];

  uintptr_t *storagePointer = (uintptr_t *)((uintptr_t)blockLiteral + sizeof(*blockLiteral));
  uintptr_t wordOffset = 0;

  for (int i = 0; blockLayout[i] != 0x00; i++) {
    int p = (blockLayout[i] & 0xF0) >> 4;
    int n = (blockLayout[i] & 0x0F) + 1;
    if (p == BLOCK_LAYOUT_STRONG) {
      for (int j = 0; j < n; j++) {
        void *ptr = ((uintptr_t *)storagePointer + wordOffset + j);
        void *rawPtr = *((void **)ptr);
        if (rawPtr && _FBIsRetainableObjCPointer(rawPtr)) {
          [strongReferences addObject:(__bridge id)rawPtr];
        }
      }
    } else if (p == BLOCK_LAYOUT_BYREF) {
      for (int j = 0; j < n; j++) {
        uintptr_t *ptr = ((uintptr_t *)storagePointer + wordOffset + j);
        void *rawByref = *((void **)ptr);
        if (!rawByref || malloc_size(rawByref) == 0) continue;
        struct Block_byref *blockByref = (struct Block_byref *)rawByref;
        BOOL isStrongLayout = (blockByref->flags & BLOCK_BYREF_LAYOUT_MASK) == BLOCK_BYREF_LAYOUT_STRONG;
        BOOL hasCopyDispose = blockByref->flags & BLOCK_BYREF_HAS_COPY_DISPOSE;
        if (hasCopyDispose && isStrongLayout) {
          void *byrefPtr = (uint8_t *)blockByref + sizeof(*blockByref);
          void *rawPtr = *((void **)byrefPtr);
          if (rawPtr && _FBIsRetainableObjCPointer(rawPtr)) {
            [strongReferences addObject:(__bridge id)rawPtr];
          }
        }
      }
    }
    wordOffset += n;
  }

  return strongReferences;
}

NSArray *FBGetBlockStrongReferences(void *block) {
  if (!FBObjectIsBlock(block)) {
    return nil;
  }

  NSMutableArray *results = [NSMutableArray new];

  struct BlockLiteral *blockLiteral = block;

  if (!(blockLiteral->flags & BLOCK_HAS_EXTENDED_LAYOUT) ||
      !(blockLiteral->flags & BLOCK_HAS_COPY_DISPOSE)) return results;

  // The layout field's position in the descriptor depends on which optional
  // fields are present. Compute it dynamically based on flag bits.
  const char *layout = _GetBlockDescriptorLayout(blockLiteral);
  if ((uintptr_t)layout < 0x1000) {
    return _GetStrongReferencesCompactLayout(blockLiteral, layout);
  } else {
    return _GetStrongReferencesExtendedLayout(blockLiteral, layout);
  }
}

static Class _BlockClass(void) {
  static dispatch_once_t onceToken;
  static Class blockClass;
  dispatch_once(&onceToken, ^{
    void (^testBlock)(void) = [^{} copy];
    blockClass = [testBlock class];
    while(class_getSuperclass(blockClass) && class_getSuperclass(blockClass) != [NSObject class]) {
      blockClass = class_getSuperclass(blockClass);
    }
    [testBlock release];
  });
  return blockClass;
}

BOOL FBObjectIsBlock(void *object) {
  Class blockClass = _BlockClass();

  Class candidate = object_getClass((__bridge id)object);
  return [candidate isSubclassOfClass:blockClass];
}
