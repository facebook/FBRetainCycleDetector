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

#import <objc/runtime.h>

#import "FBBlockInterface.h"
#import "FBBlockStrongRelationDetector.h"

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
      id strongRef = (__bridge id)(*((void **)storagePointer));
      if (strongRef) {
        [strongReferences addObject:strongRef];
      }
    }
  }

  if (byrefReferenceCount > 0) {
    for (int i = 0; i < byrefReferenceCount; i += 1, storagePointer += 1) {
      struct Block_byref *blockByref = (struct Block_byref *)(*((void **)storagePointer));
      BOOL isStrongLayout = (blockByref->flags & BLOCK_BYREF_LAYOUT_MASK) == BLOCK_BYREF_LAYOUT_STRONG;
      BOOL hasCopyDispose = blockByref->flags & BLOCK_BYREF_HAS_COPY_DISPOSE;
      if (hasCopyDispose && isStrongLayout) {
        void *byrefDesc = (uint8_t *)blockByref + sizeof(*blockByref);
        id strongRef = (__bridge id)(*((void **)byrefDesc));
        if (strongRef) {
          [strongReferences addObject:strongRef];
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
        id strongRef = (__bridge id)(*((void **)ptr));
        if (strongRef) {
          [strongReferences addObject:strongRef];
        }
      }
    } else if (p == BLOCK_LAYOUT_BYREF) {
      for (int j = 0; j < n; j++) {
        uintptr_t *ptr = ((uintptr_t *)storagePointer + wordOffset + j);
        struct Block_byref *blockByref = (struct Block_byref *)(*((void **)ptr));
        BOOL isStrongLayout = (blockByref->flags & BLOCK_BYREF_LAYOUT_MASK) == BLOCK_BYREF_LAYOUT_STRONG;
        BOOL hasCopyDispose = blockByref->flags & BLOCK_BYREF_HAS_COPY_DISPOSE;
        if (hasCopyDispose && isStrongLayout) {
          void *byrefPtr = (uint8_t *)blockByref + sizeof(*blockByref);
          id strongRef = (__bridge id)(*((void **)byrefPtr));
          if (strongRef) {
            [strongReferences addObject:strongRef];
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
