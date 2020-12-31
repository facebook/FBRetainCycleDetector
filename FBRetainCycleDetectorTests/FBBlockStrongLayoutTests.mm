/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <memory>
#import <unordered_map>
#import <vector>

#import <XCTest/XCTest.h>

#import <FBRetainCycleDetector/FBBlockStrongLayout.h>
#import <FBRetainCycleDetector/FBRetainCycleUtils.h>
@interface FBBlockStrongLayoutTests : XCTestCase
@end

@implementation FBBlockStrongLayoutTests

- (void)testBlockDoesntRetainWeakReference
{
  __attribute__((objc_precise_lifetime)) NSObject *object = [NSObject new];
  __weak NSObject *weakObject = object;
  
  void (^block)() = ^{
    __unused NSObject *someObject = weakObject;
  };
  
  NSArray *retainedObjects = FBGetBlockStrongReferences((__bridge void *)(block));
  
  XCTAssertEqual([retainedObjects count], 0);
}

- (void)testBlockRetainsStrongReference
{
  NSObject *object = [NSObject new];
  
  void (^block)() = ^{
    __unused NSObject *someObject = object;
  };
  
  NSArray *retainedObjects = FBGetBlockStrongReferences((__bridge void *)(block));
  
  XCTAssertEqual([retainedObjects count], 1);
  XCTAssertEqualObjects(retainedObjects[0], object);
}

- (void)testThatBlockRetainingVectorOfObjectsDoNotCrash
{
  NSObject *object = [NSObject new];
  std::vector<id> vector = {object};
  
  void (^block)() = ^{
    __unused std::vector<id> someVector = vector;
  };
  
  NSArray *retainedObjects = FBGetBlockStrongReferences((__bridge void *)(block));
  
  XCTAssertEqual([retainedObjects count], 0);
}

- (void)testThatBlockRetainingVectorOfStructsDoNotCrash
{
  struct HelperStruct {};
  std::vector<HelperStruct> vector = {};
  
  void (^block)() = ^{
    __unused std::vector<HelperStruct> someVector = vector;
  };
  
  NSArray *retainedObjects = FBGetBlockStrongReferences((__bridge void *)(block));
  
  XCTAssertEqual([retainedObjects count], 0);
}

- (void)testThatBlockUsingCppButRetainingOnlyObjectsWillReturnTheObjectAndNotCrash
{
  NSObject *object = [NSObject new];
  
  void (^block)() = ^{
    std::vector<id> vector;
    vector.push_back(object);
  };
  
  NSArray *retainedObjects = FBGetBlockStrongReferences((__bridge void *)(block));
  
  XCTAssertEqual([retainedObjects count], 1);
  XCTAssertEqualObjects(retainedObjects[0], object);
}

- (void)testThatBlockRetainingMapWillNotCrash
{
  struct HelperStruct{};
  std::unordered_map<int, HelperStruct> map;
  
  void (^block)() = ^{
    __unused std::unordered_map<int, HelperStruct> someMap = map;
  };
  
  NSArray *retainedObjects = FBGetBlockStrongReferences((__bridge void *)(block));
  
  XCTAssertEqual([retainedObjects count], 0);
}

#define newObject(A) NSObject *object##A = [NSObject new]
#define __blockNewObject(A) __block NSObject *object##A = [NSObject new]
#define useObject(A) __unused NSObject *someObject##A = object##A
#define assertObject(A) XCTAssertEqualObjects(retainedObjects[A], object##A);

- (void)testBlockRetains15StrongReferences
{

    newObject(0); newObject(1); newObject(2); newObject(3);
    newObject(4); newObject(5); newObject(6); newObject(7);
    
    __blockNewObject(8); __blockNewObject(9); __blockNewObject(10); __blockNewObject(11);
    __blockNewObject(12); __blockNewObject(13); __blockNewObject(14);


    void (^block)() = ^{
        useObject(0); useObject(1); useObject(2); useObject(3);
        useObject(4); useObject(5); useObject(6); useObject(7);
        useObject(8); useObject(9); useObject(10); useObject(11);
        useObject(12); useObject(13); useObject(14);
    };

    NSArray *retainedObjects = FBGetBlockStrongReferences((__bridge void *)(block));
    XCTAssertEqual([retainedObjects count], 15);

    assertObject(0); assertObject(1); assertObject(2); assertObject(3);
    assertObject(4); assertObject(5); assertObject(6); assertObject(7);
    assertObject(8); assertObject(9); assertObject(10); assertObject(11);
    assertObject(12); assertObject(13); assertObject(14);
}

- (void)testBlockRetainsMoreThan15StrongReferences
{
    newObject(0); newObject(1); newObject(2); newObject(3);
    newObject(4); newObject(5); newObject(6); newObject(7);
    
    __blockNewObject(8); __blockNewObject(9); __blockNewObject(10); __blockNewObject(11);
    __blockNewObject(12); __blockNewObject(13); __blockNewObject(14); __blockNewObject(15);

    void (^block)() = ^{
        useObject(0); useObject(1); useObject(2); useObject(3);
        useObject(4); useObject(5); useObject(6); useObject(7);
        useObject(8); useObject(9); useObject(10); useObject(11);
        useObject(12); useObject(13); useObject(14); useObject(15);
    };

    NSArray *retainedObjects = FBGetBlockStrongReferences((__bridge void *)(block));
    XCTAssertEqual([retainedObjects count], 16);

    assertObject(0); assertObject(1); assertObject(2); assertObject(3);
    assertObject(4); assertObject(5); assertObject(6); assertObject(7);
    assertObject(8); assertObject(9); assertObject(10); assertObject(11);
    assertObject(12); assertObject(13); assertObject(14); assertObject(15);
}

@end
