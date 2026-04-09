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
 A reference to a Swift object field discovered via Swift ABI metadata.
 Reads the field value directly at the given byte offset, without
 going through SwiftIntrospector / Mirror.
 */
@interface FBSwiftABIReference : NSObject <FBObjectReference>

- (nonnull instancetype)initWithName:(nonnull NSString *)name offset:(uintptr_t)offset;

@end
