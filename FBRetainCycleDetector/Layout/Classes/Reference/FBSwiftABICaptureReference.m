/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBSwiftABICaptureReference.h"

#import <malloc/malloc.h>

@implementation FBSwiftABICaptureReference {
  NSString *_name;
  uintptr_t _closureFieldOffset;
  uintptr_t _captureBoxOffset;
}

- (nonnull instancetype)initWithName:(nonnull NSString *)name
                  closureFieldOffset:(uintptr_t)closureFieldOffset
                    captureBoxOffset:(uintptr_t)captureBoxOffset {
  if (self = [super init]) {
    _name = [name copy];
    _closureFieldOffset = closureFieldOffset;
    _captureBoxOffset = captureBoxOffset;
  }
  return self;
}

#pragma mark - FBObjectReference

- (nullable id)objectReferenceFromObject:(nullable id)object {
  if (!object) return nil;

  const char *objectPtr = (const char *)(__bridge const void *)object;

  // Read context pointer (second word of the closure, at fieldOffset + 8)
  const void *contextPtr = *(const void **)(objectPtr + _closureFieldOffset + 8);
  if (!contextPtr) return nil;
  if ((uintptr_t)contextPtr & 0x7) return nil;
  if (malloc_size(contextPtr) == 0) return nil;

  // Read the captured object from the capture box
  const void *captured = *(const void **)((const char *)contextPtr + _captureBoxOffset);
  if (!captured) return nil;
  if ((uintptr_t)captured & 0x7) return nil;
  if ((uintptr_t)captured >> 63) return nil;
  if (malloc_size(captured) == 0) return nil;

  return (__bridge id)captured;
}

- (nullable NSArray<NSString *> *)namePath {
  return @[_name];
}

@end
