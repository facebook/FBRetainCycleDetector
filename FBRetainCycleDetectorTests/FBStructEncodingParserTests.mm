/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <objc/runtime.h>

#import <XCTest/XCTest.h>

#import <FBRetainCycleDetector/FBStructEncodingParser.h>

@interface FBStructEncodingTests : XCTestCase
@end

struct _RCDTestStructWithPrimitive {
  int testPrimitive;
};

struct _RCDTestStructWithObject {
  NSObject *object;
};

struct _RCDTestStructWithObjectPrimitiveMixin {
  int someInt;
  NSObject *someObject;
  float *someFloatPointer;
  __weak NSObject *someWeakObject;
};

struct _RCDTestStructWithNestedStruct {
  int someInt;
  struct _RCDTestStructWithObjectPrimitiveMixin mixingStruct;
};

struct _RCDTestStructWithUnnamedBitfield {
  unsigned : 4;
};

@interface _RCDParserTestClass : NSObject
@property (nonatomic, assign) _RCDTestStructWithPrimitive structWithPrimitive;
@property (nonatomic, assign) _RCDTestStructWithObject structWithObject;
@property (nonatomic, assign) _RCDTestStructWithObjectPrimitiveMixin structWithObjectPrimitiveMixin;
@property (nonatomic, assign) _RCDTestStructWithNestedStruct structWithNestedStruct;
@property (nonatomic, assign) _RCDTestStructWithUnnamedBitfield structWithUnnamedBitfield;
@end
@implementation _RCDParserTestClass
@end



@implementation FBStructEncodingTests

- (NSString *)_getIvarEncodingByName:(NSString *)ivarName forClass:(Class)aCls
{
  unsigned int count;
  Ivar *ivars = class_copyIvarList(aCls, &count);

  NSString *typeEncoding = nil;

  for (unsigned int i = 0; i < count; ++i) {
    Ivar ivar = ivars[i];
    if ([@(ivar_getName(ivar)) isEqualToString:ivarName]) {
      typeEncoding = @(ivar_getTypeEncoding(ivar));
      break;
    }
  }

  free(ivars);

  return typeEncoding;
}

- (void)testThatParserWillParseStructWithPrimitive
{
  NSString *encoding = [self _getIvarEncodingByName:@"_structWithPrimitive" forClass:[_RCDParserTestClass class]];
  XCTAssertNotNil(encoding);
  FBParsedStruct *parsedStruct = FBParseStructEncoding(encoding);

  XCTAssertEqual([parsedStruct.typesContainedInStruct count], 1);
  XCTAssertEqualObjects(parsedStruct.structTypeName, @"_RCDTestStructWithPrimitive");
  XCTAssertEqualObjects(parsedStruct.typesContainedInStruct[0].typeEncoding, @"i");
  XCTAssertEqualObjects(parsedStruct.typesContainedInStruct[0].name, @"testPrimitive");
}

- (void)testThatParserWillParseStructWithObject
{
  NSString *encoding = [self _getIvarEncodingByName:@"_structWithObject" forClass:[_RCDParserTestClass class]];
  XCTAssertNotNil(encoding);
  FBParsedStruct *parsedStruct = FBParseStructEncoding(encoding);

  XCTAssertEqual([parsedStruct.typesContainedInStruct count], 1);
  XCTAssertEqualObjects(parsedStruct.structTypeName, @"_RCDTestStructWithObject");
  XCTAssertEqualObjects(parsedStruct.typesContainedInStruct[0].typeEncoding, @"@");
  XCTAssertEqualObjects(parsedStruct.typesContainedInStruct[0].name, @"object");
}

- (void)testThatParserWillParseStructWithObjectsAndPrimitives
{
  NSString *encoding = [self _getIvarEncodingByName:@"_structWithObjectPrimitiveMixin" forClass:[_RCDParserTestClass class]];
  XCTAssertNotNil(encoding);
  FBParsedStruct *parsedStruct = FBParseStructEncoding(encoding);

  XCTAssertEqual([parsedStruct.typesContainedInStruct count], 4);
  XCTAssertEqualObjects(parsedStruct.structTypeName, @"_RCDTestStructWithObjectPrimitiveMixin");
  XCTAssertEqualObjects(parsedStruct.typesContainedInStruct[0].typeEncoding, @"i");
  XCTAssertEqualObjects(parsedStruct.typesContainedInStruct[0].name, @"someInt");
  XCTAssertEqualObjects(parsedStruct.typesContainedInStruct[1].typeEncoding, @"@");
  XCTAssertEqualObjects(parsedStruct.typesContainedInStruct[1].name, @"someObject");
  XCTAssertEqualObjects(parsedStruct.typesContainedInStruct[2].typeEncoding, @"^f");
  XCTAssertEqualObjects(parsedStruct.typesContainedInStruct[2].name, @"someFloatPointer");
  XCTAssertEqualObjects(parsedStruct.typesContainedInStruct[3].typeEncoding, @"@");
  XCTAssertEqualObjects(parsedStruct.typesContainedInStruct[3].name, @"someWeakObject");
}

- (void)testThatParserWillParseStructWithNestedStruct
{
  NSString *encoding = [self _getIvarEncodingByName:@"_structWithNestedStruct" forClass:[_RCDParserTestClass class]];
  XCTAssertNotNil(encoding);
  FBParsedStruct *parsedStruct = FBParseStructEncoding(encoding);

  XCTAssertEqual([parsedStruct.typesContainedInStruct count], 2);
  XCTAssertEqualObjects(parsedStruct.structTypeName, @"_RCDTestStructWithNestedStruct");
  XCTAssertEqualObjects(parsedStruct.typesContainedInStruct[0].typeEncoding, @"i");

  XCTAssertTrue([parsedStruct.typesContainedInStruct[1] isKindOfClass:[FBParsedStruct class]]);
  FBParsedStruct *innerStruct = (FBParsedStruct *)(parsedStruct.typesContainedInStruct[1]);

  XCTAssertEqual([innerStruct.typesContainedInStruct count], 4);
  XCTAssertEqualObjects(innerStruct.structTypeName, @"_RCDTestStructWithObjectPrimitiveMixin");
  XCTAssertEqualObjects(innerStruct.typesContainedInStruct[0].typeEncoding, @"i");
  XCTAssertEqualObjects(innerStruct.typesContainedInStruct[0].name, @"someInt");
  XCTAssertEqualObjects(innerStruct.typesContainedInStruct[1].typeEncoding, @"@");
  XCTAssertEqualObjects(innerStruct.typesContainedInStruct[1].name, @"someObject");
  XCTAssertEqualObjects(innerStruct.typesContainedInStruct[2].typeEncoding, @"^f");
  XCTAssertEqualObjects(innerStruct.typesContainedInStruct[2].name, @"someFloatPointer");
  XCTAssertEqualObjects(innerStruct.typesContainedInStruct[3].typeEncoding, @"@");
  XCTAssertEqualObjects(innerStruct.typesContainedInStruct[3].name, @"someWeakObject");
}

- (void)testThatParserWillParseStructWithUnnamedBitfield
{
  NSString *encoding = [self _getIvarEncodingByName:@"_structWithUnnamedBitfield" forClass:[_RCDParserTestClass class]];
  XCTAssertNotNil(encoding);
  FBParsedStruct *parsedStruct = FBParseStructEncoding(encoding);

  XCTAssertEqual([parsedStruct.typesContainedInStruct count], 1);
  XCTAssertEqualObjects(parsedStruct.structTypeName, @"_RCDTestStructWithUnnamedBitfield");
  XCTAssertEqualObjects(parsedStruct.typesContainedInStruct[0].typeEncoding, @"b4");
  XCTAssertNil(parsedStruct.typesContainedInStruct[0].name);
}

- (void)testThatParserWillParseStructAndPassTypePath
{
  NSString *encoding = [self _getIvarEncodingByName:@"_structWithNestedStruct" forClass:[_RCDParserTestClass class]];
  XCTAssertNotNil(encoding);
  FBParsedStruct *parsedStruct = FBParseStructEncoding(encoding);

  XCTAssertEqual([parsedStruct.typesContainedInStruct count], 2);
  XCTAssertTrue([parsedStruct.typesContainedInStruct[1] isKindOfClass:[FBParsedStruct class]]);
  FBParsedStruct *innerStruct = (FBParsedStruct *)(parsedStruct.typesContainedInStruct[1]);
  NSArray *expectedNamePath = @[@"_RCDTestStructWithNestedStruct",
                                @"mixingStruct",
                                @"_RCDTestStructWithObjectPrimitiveMixin"];
  XCTAssertEqualObjects(innerStruct.typesContainedInStruct[1].typePath, expectedNamePath);
}

@end
