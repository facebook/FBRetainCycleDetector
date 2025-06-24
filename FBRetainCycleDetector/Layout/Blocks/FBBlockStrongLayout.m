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

NSArray *FBGetBlockStrongReferences(void *block) {
  // TODO: fix crashes in this function logic
  return @[];

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
  
  int strongReferenceCount = 0;
  int byrefReferenceCount = 0;
  if ((int)layout < 0x1000) {
    strongReferenceCount = ((int)layout & 0xF00) >> 8;
    byrefReferenceCount = ((int)layout & 0x0F0) >> 4;
  } else {
    for (int i = 0; layout[i] != 0x00; i++) {
      int p = (layout[i] & 0xF0) >> 4;
      if (p == BLOCK_LAYOUT_STRONG) {
        strongReferenceCount += (layout[i] & 0x0F) + 1;
      } else if (p == BLOCK_LAYOUT_BYREF) {
        byrefReferenceCount += (layout[i] & 0x0F) + 1;
      }
    }
  }
  
  void *desc = (uint8_t *)block + sizeof(*blockLiteral);
  
  if (strongReferenceCount) {
    for (int i = 0; i < strongReferenceCount; i++, desc += sizeof(void *)) {
      id strongRef = (__bridge id)(*((void **)desc));
      if (strongRef) [results addObject:strongRef];
    }
  }
  
  if (byrefReferenceCount) {
    for (int i = 0; i < byrefReferenceCount; i++, desc += sizeof(void *)) {
      struct Block_byref *blockByref = (struct Block_byref *)(*((void **)desc));
      if ((blockByref->flags & BLOCK_BYREF_HAS_COPY_DISPOSE) && (blockByref->flags & BLOCK_BYREF_LAYOUT_STRONG)) {
        void *byrefDesc = (uint8_t *)blockByref + sizeof(*blockByref);
        id strongRef = (__bridge id)(*((void **)byrefDesc));
        if (strongRef) [results addObject:strongRef];
      }
    }
  }
  
  return results;
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
