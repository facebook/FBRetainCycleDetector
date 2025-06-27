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
 We will be blackboxing variables that the block holds with our own custom class,
 and we will check which of them were retained.

 The idea is based on the approach Circle uses:
 https://github.com/mikeash/Circle
 https://github.com/mikeash/Circle/blob/master/Circle/CircleIVarLayout.m
 */

static NSArray *_GetStrongReferencesCompactLayout(struct BlockLiteral *blockLiteral) {
  NSMutableArray *strongReferences = [NSMutableArray array];

  const char *blockLayout = blockLiteral->descriptor->layout;

  int strongReferenceCount = ((uintptr_t)blockLayout & 0xF00) >> 8;
  int byrefReferenceCount = ((uintptr_t)blockLayout & 0x0F0) >> 4;

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

static NSArray *_GetStrongReferencesExtendedLayout(struct BlockLiteral *blockLiteral)
{
  NSMutableArray *strongReferences = [NSMutableArray array];
  const char *blockLayout = blockLiteral->descriptor->layout;

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
  
  // If the layout field is less than 0x1000, then it is a compact encoding
  // of the form 0xXYZ: X strong pointers, then Y byref pointers,
  // then Z weak pointers.
  
  // If the layout field is 0x1000 or greater, it points to a
  // string of layout bytes. Each byte is of the form 0xPN.
  // Operator P is from the list below. Value N is a parameter for the operator.
  // Byte 0x00 terminates the layout; remaining block data is non-pointer bytes.
  const char *layout = blockLiteral->descriptor->layout;
  if ((int)layout < 0x1000) {
    return _GetStrongReferencesCompactLayout(blockLiteral);
  } else {
    return _GetStrongReferencesExtendedLayout(blockLiteral);
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
