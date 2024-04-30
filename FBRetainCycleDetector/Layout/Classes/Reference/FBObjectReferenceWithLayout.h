/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#import "FBObjectReference.h"

/**
 Defines an outgoing reference from Objective-C object.
 */

@protocol FBObjectReferenceWithLayout <FBObjectReference>

/**
 What is the index of that reference in ivar layout?
 index * sizeof(void *) gives you offset from the
 beginning of the object.
 */
- (NSUInteger)indexInIvarLayout;

@end
