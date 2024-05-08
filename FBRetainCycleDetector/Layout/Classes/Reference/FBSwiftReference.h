/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#import "FBObjectReference.h"

@interface FBSwiftReference : NSObject <FBObjectReference>

@property (nonatomic, copy, readonly) NSString *name;

- (nonnull instancetype)initWithName:(NSString *)name;

@end
