/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBParsedStruct.h"

@implementation FBParsedStruct

- (instancetype)initWithName:(NSString *)name
                typeEncoding:(NSString *)typeEncoding
              structTypeName:(NSString *)structTypeName
      typesContainedInStruct:(NSArray<FBParsedType *> *)typesContainedInStruct
{
  if (self = [super initWithName:name
                    typeEncoding:typeEncoding]) {
    _structTypeName = structTypeName;
    _typesContainedInStruct = typesContainedInStruct;
  }
  return self;
}

- (NSArray<FBParsedType *> *)flattenTypes
{
  NSMutableArray<FBParsedType *> *simpleTypes = [NSMutableArray new];

  for (id type in _typesContainedInStruct) {
    if ([type isKindOfClass:[FBParsedStruct class]]) {
      [simpleTypes addObjectsFromArray:[type flattenTypes]];
    } else {
      [simpleTypes addObject:type];
    }
  }

  return simpleTypes;
}

- (void)passTypePath:(NSArray<NSString *> *)typePath
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
  self.typePath = typePath;
  NSMutableArray<NSString *> *typePathToPass = [typePath mutableCopy] ?: [NSMutableArray new];
  if (self.name) {
    [typePathToPass addObject:self.name];
  }
  if (_structTypeName && ![_structTypeName isEqualToString:@"?"]) {
    [typePathToPass addObject:_structTypeName];
  }
  for (FBParsedType *type in _typesContainedInStruct) {
    [type passTypePath:typePathToPass];
  }
#pragma clang diagnostic pop
}

@end
