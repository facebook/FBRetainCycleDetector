/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBParsedType.h"

@implementation FBParsedType
- (instancetype)initWithName:(NSString *)name
                typeEncoding:(NSString *)typeEncoding
{
  if (self = [super init]) {
    _name = name;
    _typeEncoding = typeEncoding;
  }

  return self;
}

- (void)passTypePath:(NSArray<NSString *> *)typePath
{
  _typePath = [typePath copy];
}

@end
