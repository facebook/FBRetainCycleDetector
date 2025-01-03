// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.
/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCDObjectWrapperTestClass.h"


@implementation RCDObjectWrapperTestClass
{
  RCDObjectWrapperTestClass *_someTestClassInstance;
}

- (instancetype)initWithOtherObject:(RCDObjectWrapperTestClass *)object
{
  if (self = [super init]) {
    _someTestClassInstance = object;
  }

  return self;
}

@end


@implementation RCDObjectWrapperTestClassSubclass
@end
