/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

#import "FBParsedType.h"

/**
 FBParsedStruct will represent a struct parsed by the struct parser. It will hold all types that
 the struct has within itself, including nested structs.
 */
@interface FBParsedStruct : FBParsedType

/**
 Type name for a struct is exactly a type of struct. For example:
 struct SomeStruct {};

 has structTypeName: SomeStruct
 */
@property (nonatomic, copy, readonly, nullable) NSString *structTypeName;

/**
 This array will hold all types parser parsed within this struct.
 */
@property (nonatomic, copy, readonly, nonnull) NSArray<FBParsedType *> *typesContainedInStruct;

- (nonnull instancetype)initWithName:(nullable NSString *)name
                        typeEncoding:(nonnull NSString *)typeEncoding
                      structTypeName:(nullable NSString *)structTypeName
              typesContainedInStruct:(nonnull NSArray<FBParsedType *> *)typesContainedInStruct;

/**
 To flatten a struct means to literally forgot about nested struct structure. For every struct
 it will just retrieve all it's types inside and flatten them. Returned array is guaranteed
 to consist only basic types.
 */
- (nonnull NSArray<FBParsedType *> *)flattenTypes;

@end
