// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

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
