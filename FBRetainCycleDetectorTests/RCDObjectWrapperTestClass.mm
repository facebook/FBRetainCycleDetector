// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

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
