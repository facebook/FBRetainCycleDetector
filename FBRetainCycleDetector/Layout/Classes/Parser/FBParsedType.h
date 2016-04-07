/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

/**
 FBParsedType is a class representing a basic token created from struct parser.
 */
@interface FBParsedType : NSObject

/**
 Name inside of struct:
 struct SomeStruct {
   NSObject *name; <--- this name
 };
 */
@property (nonatomic, copy, readonly, nullable) NSString *name;

/**
 Part of the parsed type encoding responsible for just this type.
 */
@property (nonatomic, copy, readonly, nonnull) NSString *typeEncoding;

/**
 Type Path inside the struct is a naming path that leads to this type. For example:

 struct SomeStruct {
   NSObject *object;
 }

 struct SomeOtherStruct {
   struct SomeStruct someStruct;
 }

 If we take an object in context of SomeOtherStruct, then the typePath for this object is:
 @[@"SomeOtherStruct", @"someStruct", @"SomeStruct"]

 This is helpful when we are trying to quickly figure out where in the struct should we look for.
 */
@property (nonatomic, copy, nullable) NSArray<NSString *> *typePath;

- (nonnull instancetype)initWithName:(nullable NSString *)name
                        typeEncoding:(nonnull NSString *)typeEncoding;

/**
 This is the helper function for passing the type path. Once the parser creates tokens for given struct
 encoding, it will call passTypePath on it's root, which should transfer whole path to every object.
 */
- (void)passTypePath:(nullable NSArray<NSString *> *)typePath;

@end
