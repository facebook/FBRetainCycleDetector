/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

/**
 Defines an outgoing reference.
 */

@protocol FBObjectReference <NSObject>

/**
 For given object we need to be able to grab that object reference.
 */
- (nullable id)objectReferenceFromObject:(nullable id)object;

/**
 For given reference in an object, there can be a path of names that leads to it.
 For example it can be an ivar, thus the path will consist of ivar name only:
 @[@"_myIvar"]

 But it also can be a reference in some nested struct like:
 struct SomeStruct {
   NSObject *myObject;
 };

 If that struct will be used in class, then name path would look like this:
 @[@"_myIvar", @"SomeStruct", @"myObject"]
 */
- (nullable NSArray<NSString *> *)namePath;

@end
