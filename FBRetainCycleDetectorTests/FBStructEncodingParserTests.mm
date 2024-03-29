/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <objc/runtime.h>

#import <XCTest/XCTest.h>

#import <FBRetainCycleDetector/FBStructEncodingParser.h>
#import <FBRetainCycleDetector/Struct.h>
#import <FBRetainCycleDetector/Type.h>

#import <memory>
#import <vector>

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

struct _RCDTestStructWithUnnamedStruct {
  struct {
    bool value;
  };
};

@interface _RCDParserTestClass : NSObject
@property (nonatomic, assign) _RCDTestStructWithPrimitive structWithPrimitive;
@property (nonatomic, assign) _RCDTestStructWithObject structWithObject;
@property (nonatomic, assign) _RCDTestStructWithObjectPrimitiveMixin structWithObjectPrimitiveMixin;
@property (nonatomic, assign) _RCDTestStructWithNestedStruct structWithNestedStruct;
@property (nonatomic, assign) _RCDTestStructWithUnnamedBitfield structWithUnnamedBitfield;
@property (nonatomic, assign) _RCDTestStructWithUnnamedStruct structWithUnnamedStruct;
@end
@implementation _RCDParserTestClass
@end


@implementation FBStructEncodingTests

- (std::string)_getIvarEncodingByName:(nonnull NSString *)ivarName forClass:(Class)aCls
{
  unsigned int count;
  Ivar *ivars = class_copyIvarList(aCls, &count);

  std::string typeEncoding = "";

  for (unsigned int i = 0; i < count; ++i) {
    Ivar ivar = ivars[i];
    const char *ivarNameCString = ivar_getName(ivar);
    if (ivarNameCString != nil && [@(ivarNameCString) isEqualToString:ivarName]) {
      typeEncoding = std::string(ivar_getTypeEncoding(ivar));
      break;
    }
  }

  free(ivars);

  return typeEncoding;
}

- (void)testThatParserWillParseStructWithPrimitive
{
  std::string encoding = [self _getIvarEncodingByName:@"_structWithPrimitive" forClass:[_RCDParserTestClass class]];
  XCTAssertTrue(encoding.length() > 0);
  FB::RetainCycleDetector::Parser::Struct parsedStruct =
  FB::RetainCycleDetector::Parser::parseStructEncoding(encoding);

  XCTAssertEqual(parsedStruct.typesContainedInStruct.size(), 1);
  XCTAssertEqual(parsedStruct.structTypeName, "_RCDTestStructWithPrimitive");
  XCTAssertEqual(parsedStruct.typesContainedInStruct[0]->typeEncoding, "i");
  XCTAssertEqual(parsedStruct.typesContainedInStruct[0]->name, "testPrimitive");
}

- (void)testThatParserWillParseStructWithObject
{
  std::string encoding = [self _getIvarEncodingByName:@"_structWithObject" forClass:[_RCDParserTestClass class]];
  XCTAssertTrue(encoding.length() > 0);
  FB::RetainCycleDetector::Parser::Struct parsedStruct =
  FB::RetainCycleDetector::Parser::parseStructEncoding(encoding);

  XCTAssertEqual(parsedStruct.typesContainedInStruct.size(), 1);
  XCTAssertEqual(parsedStruct.structTypeName, "_RCDTestStructWithObject");
  XCTAssertEqual(parsedStruct.typesContainedInStruct[0]->typeEncoding, "@");
  XCTAssertEqual(parsedStruct.typesContainedInStruct[0]->name, "object");
}

- (void)testThatParserWillParseStructWithObjectsAndPrimitives
{
  std::string encoding = [self _getIvarEncodingByName:@"_structWithObjectPrimitiveMixin" forClass:[_RCDParserTestClass class]];
  XCTAssertTrue(encoding.length() > 0);
  FB::RetainCycleDetector::Parser::Struct parsedStruct =
  FB::RetainCycleDetector::Parser::parseStructEncoding(encoding);

  XCTAssertEqual(parsedStruct.typesContainedInStruct.size(), 4);
  XCTAssertEqual(parsedStruct.structTypeName, "_RCDTestStructWithObjectPrimitiveMixin");
  XCTAssertEqual(parsedStruct.typesContainedInStruct[0]->typeEncoding, "i");
  XCTAssertEqual(parsedStruct.typesContainedInStruct[0]->name, "someInt");
  XCTAssertEqual(parsedStruct.typesContainedInStruct[1]->typeEncoding, "@");
  XCTAssertEqual(parsedStruct.typesContainedInStruct[1]->name, "someObject");
  XCTAssertEqual(parsedStruct.typesContainedInStruct[2]->typeEncoding, "^f");
  XCTAssertEqual(parsedStruct.typesContainedInStruct[2]->name, "someFloatPointer");
  XCTAssertEqual(parsedStruct.typesContainedInStruct[3]->typeEncoding, "@");
  XCTAssertEqual(parsedStruct.typesContainedInStruct[3]->name, "someWeakObject");
}

- (void)testThatParserWillParseStructWithNestedStruct
{
  std::string encoding = [self _getIvarEncodingByName:@"_structWithNestedStruct" forClass:[_RCDParserTestClass class]];
  XCTAssertTrue(encoding.length() > 0);
  FB::RetainCycleDetector::Parser::Struct parsedStruct =
  FB::RetainCycleDetector::Parser::parseStructEncoding(encoding);

  XCTAssertEqual(parsedStruct.typesContainedInStruct.size(), 2);
  XCTAssertEqual(parsedStruct.structTypeName, "_RCDTestStructWithNestedStruct");
  XCTAssertEqual(parsedStruct.typesContainedInStruct[0]->typeEncoding, "i");

  std::shared_ptr<FB::RetainCycleDetector::Parser::Struct> innerStruct =
  std::dynamic_pointer_cast<FB::RetainCycleDetector::Parser::Struct>(parsedStruct.typesContainedInStruct[1]);
  XCTAssertTrue(innerStruct);

  XCTAssertEqual(innerStruct->typesContainedInStruct.size(), 4);
  XCTAssertEqual(innerStruct->structTypeName, "_RCDTestStructWithObjectPrimitiveMixin");
  XCTAssertEqual(innerStruct->typesContainedInStruct[0]->typeEncoding, "i");
  XCTAssertEqual(innerStruct->typesContainedInStruct[0]->name, "someInt");
  XCTAssertEqual(innerStruct->typesContainedInStruct[1]->typeEncoding, "@");
  XCTAssertEqual(innerStruct->typesContainedInStruct[1]->name, "someObject");
  XCTAssertEqual(innerStruct->typesContainedInStruct[2]->typeEncoding, "^f");
  XCTAssertEqual(innerStruct->typesContainedInStruct[2]->name, "someFloatPointer");
  XCTAssertEqual(innerStruct->typesContainedInStruct[3]->typeEncoding, "@");
  XCTAssertEqual(innerStruct->typesContainedInStruct[3]->name, "someWeakObject");
}

- (void)testThatParserWillParseStructWithUnnamedBitfield
{
  std::string encoding = [self _getIvarEncodingByName:@"_structWithUnnamedBitfield" forClass:[_RCDParserTestClass class]];
  XCTAssertTrue(encoding.length() > 0);
  FB::RetainCycleDetector::Parser::Struct parsedStruct =
  FB::RetainCycleDetector::Parser::parseStructEncoding(encoding);

  XCTAssertEqual(parsedStruct.typesContainedInStruct.size(), 1);
  XCTAssertEqual(parsedStruct.structTypeName, "_RCDTestStructWithUnnamedBitfield");
  XCTAssertEqual(parsedStruct.typesContainedInStruct[0]->typeEncoding, "b4");
  XCTAssertEqual(parsedStruct.typesContainedInStruct[0]->name, "");
}

- (void)testThatParserWillParseStructAndPassTypePath
{
  std::string encoding = [self _getIvarEncodingByName:@"_structWithNestedStruct" forClass:[_RCDParserTestClass class]];
  XCTAssertTrue(encoding.length() > 0);
  FB::RetainCycleDetector::Parser::Struct parsedStruct =
  FB::RetainCycleDetector::Parser::parseStructEncoding(encoding);

  XCTAssertEqual(parsedStruct.typesContainedInStruct.size(), 2);
  std::shared_ptr<FB::RetainCycleDetector::Parser::Struct> innerStruct =
  std::dynamic_pointer_cast<FB::RetainCycleDetector::Parser::Struct>(parsedStruct.typesContainedInStruct[1]);
  XCTAssertTrue(innerStruct);

  std::vector<std::string> expectedNamePath = {
    "_RCDTestStructWithNestedStruct",
    "mixingStruct",
    "_RCDTestStructWithObjectPrimitiveMixin",
  };
  XCTAssertEqual(innerStruct->typesContainedInStruct[1]->typePath, expectedNamePath);
}

- (void)testThatParserWillParseStructWithUnnamedStruct
{
  std::string encoding = [self _getIvarEncodingByName:@"_structWithUnnamedStruct"
                                             forClass:[_RCDParserTestClass class]];
  XCTAssertTrue(encoding.length() > 0);
  FB::RetainCycleDetector::Parser::Struct parsedStruct =
  FB::RetainCycleDetector::Parser::parseStructEncoding(encoding);

  XCTAssertEqual(parsedStruct.typesContainedInStruct.size(), 1);

  std::shared_ptr<FB::RetainCycleDetector::Parser::Struct> innerStruct =
  std::dynamic_pointer_cast<FB::RetainCycleDetector::Parser::Struct>(parsedStruct.typesContainedInStruct[0]);
  XCTAssertTrue(innerStruct);

  XCTAssertEqual(innerStruct->typesContainedInStruct.size(), 1);
  XCTAssertEqual(innerStruct->typesContainedInStruct[0]->name, "value");
  XCTAssertEqual(innerStruct->typesContainedInStruct[0]->typeEncoding, "B");
}

@end
