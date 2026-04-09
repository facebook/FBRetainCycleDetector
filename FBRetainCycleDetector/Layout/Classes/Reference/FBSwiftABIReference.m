/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBSwiftABIReference.h"

#import <malloc/malloc.h>

@implementation FBSwiftABIReference {
  NSString *_name;
  uintptr_t _offset;
}

- (nonnull instancetype)initWithName:(nonnull NSString *)name offset:(uintptr_t)offset {
  if (self = [super init]) {
    _name = [name copy];
    _offset = offset;
  }
  return self;
}

#pragma mark - FBObjectReference

- (nullable id)objectReferenceFromObject:(nullable id)object {
  if (!object) return nil;

  const void *objectPtr = (__bridge const void *)object;
  const void *fieldValue = *(const void **)((const char *)objectPtr + _offset);

  if (!fieldValue) return nil;
  if ((uintptr_t)fieldValue & 0x7) return nil;
  if ((uintptr_t)fieldValue >> 63) return nil;
  if (malloc_size(fieldValue) == 0) return nil;

  return (__bridge id)fieldValue;
}

- (nullable NSArray<NSString *> *)namePath {
  return @[_name];
}

@end
