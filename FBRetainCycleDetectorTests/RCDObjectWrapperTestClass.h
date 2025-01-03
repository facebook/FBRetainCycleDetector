// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.
/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

@interface RCDObjectWrapperTestClass : NSObject
- (instancetype)initWithOtherObject:(RCDObjectWrapperTestClass *)object;
@property (nonatomic, strong) NSObject *someObject;
@property (nonatomic, copy) NSString *someString;
@property (nonatomic, weak) NSObject *irrelevantObject;
@property (nonatomic, strong) id aCls;
@end


@interface RCDObjectWrapperTestClassSubclass : RCDObjectWrapperTestClass
@end
