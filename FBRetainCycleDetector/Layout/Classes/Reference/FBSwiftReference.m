/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBSwiftReference.h"

#if __has_include("FBRetainCycleDetector-Swift.h")
    #import "FBRetainCycleDetector-Swift.h"
#else
    #import <FBRetainCycleDetector/FBRetainCycleDetector-Swift.h>
#endif

@implementation FBSwiftReference

- (nonnull instancetype)initWithName:(NSString *)name {
  if (self = [super init]) {
      _name = name;
  }
  return self;
}

#pragma mark - FBObjectReference

- (id)objectReferenceFromObject:(id)object {
    return [SwiftIntrospector getPropertyValueWithObject:object name:_name];
}

- (NSArray<NSString *> *)namePath {
    return @[_name];
}

@end
