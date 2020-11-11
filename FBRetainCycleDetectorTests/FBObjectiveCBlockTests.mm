/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import <FBRetainCycleDetector/FBObjectiveCBlock.h>
#import <FBRetainCycleDetector/FBObjectiveCGraphElement+Internal.h>
#import <FBRetainCycleDetector/FBObjectiveCObject.h>
#import <FBRetainCycleDetector/FBRetainCycleDetector.h>

#include <vector>

typedef void (^_RCDTestBlockType)();

@interface FBObjectiveCBlockTests : XCTestCase
@end

@implementation FBObjectiveCBlockTests

#if _INTERNAL_RCD_ENABLED

- (void)testLayoutForBlockRetainingObjectWillFetchTheObject
{
  NSObject *someObject = [NSObject new];
  __block NSObject *unretainedObject;

  _RCDTestBlockType block = ^{
    // Keep strong reference to someObject
    unretainedObject = someObject;
  };

  FBObjectiveCObject *wrappedObject = [[FBObjectiveCObject alloc] initWithObject:someObject];
  FBObjectiveCBlock *wrappedBlock = [[FBObjectiveCBlock alloc] initWithObject:block];

  NSSet *retainedObjects = [wrappedBlock allRetainedObjects];
  XCTAssertTrue([retainedObjects containsObject:wrappedObject]);
}

- (void)testLayoutForBlockRetainingOtherBlockWillFetchTheBlock
{
  _RCDTestBlockType block1 = ^{};
  _RCDTestBlockType block2 = ^{
    block1();
  };

  FBObjectiveCBlock *wrappedBlock1 = [[FBObjectiveCBlock alloc] initWithObject:block1];
  FBObjectiveCBlock *wrappedBlock2 = [[FBObjectiveCBlock alloc] initWithObject:block2];

  NSSet *retainedObjects = [wrappedBlock2 allRetainedObjects];
  XCTAssertTrue([retainedObjects containsObject:wrappedBlock1]);
}

- (void)testLayoutForBlockRetainingFewObjectsWillFetchAllOfThem
{
  NSObject *someObject1 = [NSObject new];
  NSObject *someObject2 = [NSObject new];
  NSObject *someObject3 = [NSObject new];
  __block NSObject *unretainedObject;

  _RCDTestBlockType block = ^{
    // Keep strong reference to someObject
    unretainedObject = someObject1;
    unretainedObject = someObject2;
    unretainedObject = someObject3;
  };

  FBObjectiveCObject *wrappedObject1 = [[FBObjectiveCObject alloc] initWithObject:someObject1];
  FBObjectiveCObject *wrappedObject2 = [[FBObjectiveCObject alloc] initWithObject:someObject2];
  FBObjectiveCObject *wrappedObject3 = [[FBObjectiveCObject alloc] initWithObject:someObject3];
  FBObjectiveCBlock *wrappedBlock = [[FBObjectiveCBlock alloc] initWithObject:block];

  NSSet *retainedObjects = [wrappedBlock allRetainedObjects];

  XCTAssertTrue([retainedObjects containsObject:wrappedObject1]);
  XCTAssertTrue([retainedObjects containsObject:wrappedObject2]);
  XCTAssertTrue([retainedObjects containsObject:wrappedObject3]);
}

- (void)testLayoutForBlockKeepingObjectBlockMixin
{
  NSObject *someObject1 = [NSObject new];
  NSObject *someObject2 = [NSObject new];
  NSObject *someObject3 = [NSObject new];
  _RCDTestBlockType someBlock1 = ^{};
  _RCDTestBlockType someBlock2 = ^{};
  _RCDTestBlockType someBlock3 = ^{};
  __block NSObject *unretainedObject;

  _RCDTestBlockType block = ^{
    // Keep strong reference to someObject
    someBlock1();
    unretainedObject = someObject1;
    unretainedObject = someObject2;
    someBlock2();
    someBlock3();
    unretainedObject = someObject3;
  };

  FBObjectiveCObject *wrappedObject1 = [[FBObjectiveCObject alloc] initWithObject:someObject1];
  FBObjectiveCObject *wrappedObject2 = [[FBObjectiveCObject alloc] initWithObject:someObject2];
  FBObjectiveCObject *wrappedObject3 = [[FBObjectiveCObject alloc] initWithObject:someObject3];
  FBObjectiveCBlock *wrappedBlock1 = [[FBObjectiveCBlock alloc] initWithObject:someBlock1];
  FBObjectiveCBlock *wrappedBlock2 = [[FBObjectiveCBlock alloc] initWithObject:someBlock2];
  FBObjectiveCBlock *wrappedBlock3 = [[FBObjectiveCBlock alloc] initWithObject:someBlock3];
  FBObjectiveCBlock *wrappedBlock = [[FBObjectiveCBlock alloc] initWithObject:block];

  NSSet *retainedObjects = [wrappedBlock allRetainedObjects];
  XCTAssertTrue([retainedObjects containsObject:wrappedObject1]);
  XCTAssertTrue([retainedObjects containsObject:wrappedObject2]);
  XCTAssertTrue([retainedObjects containsObject:wrappedObject3]);
  XCTAssertTrue([retainedObjects containsObject:wrappedBlock1]);
  XCTAssertTrue([retainedObjects containsObject:wrappedBlock2]);
  XCTAssertTrue([retainedObjects containsObject:wrappedBlock3]);
}

- (void)testLayoutForEmptyBlockWillBeEmpty
{
  _RCDTestBlockType block = ^{};
  FBObjectiveCBlock *wrappedBlock = [[FBObjectiveCBlock alloc] initWithObject:block];
  NSSet *retainedObjects = [wrappedBlock allRetainedObjects];
  XCTAssertEqual([retainedObjects count], 0);
}

- (void)testLayoutForBlockWithCppClass __attribute__((optnone))
{
  using namespace std;
  vector<NSObject *> array;
  NSObject *item = [NSObject new];
  array.push_back(item);
  
  __weak id w1 = self;
  id s1 = self;
  
  __attribute__((objc_precise_lifetime)) _RCDTestBlockType block = ^{
    array.size();
    [w1 description];
    [s1 description];
  };
  
  FBObjectiveCBlock *wrappedBlock = [[FBObjectiveCBlock alloc] initWithObject:block];
  NSSet *retainedObjects = [wrappedBlock allRetainedObjects];
  // we can't examine cpp class now, so there is only one detected strong reference.
  XCTAssertEqual([retainedObjects count], 1);
  
  FBObjectiveCObject *wrappedObject = [[FBObjectiveCObject alloc] initWithObject:self];
  XCTAssertTrue([retainedObjects containsObject:wrappedObject]);
}

- (void)testLayoutForBlockWithByrefObject __attribute__((optnone))
{
  __attribute__((objc_precise_lifetime)) NSObject *object1 = [NSObject new];
  __attribute__((objc_precise_lifetime)) NSObject *object2 = [NSObject new];
  __attribute__((objc_precise_lifetime)) NSObject *object3 = [NSObject new];

  __block id byref1 = object1;
  __block __weak id byref2 = object2;
  __block __unsafe_unretained id byref3 = object3;
  
  __attribute__((objc_precise_lifetime)) _RCDTestBlockType block = ^{
    [byref1 description];
    [byref2 description];
    [byref3 description];
  };
  
  FBObjectiveCBlock *wrappedBlock = [[FBObjectiveCBlock alloc] initWithObject:block];
  NSSet *retainedObjects = [wrappedBlock allRetainedObjects];
  XCTAssertEqual([retainedObjects count], 1);

  FBObjectiveCObject *wrappedObject = [[FBObjectiveCObject alloc] initWithObject:object1];
  XCTAssertTrue([retainedObjects containsObject:wrappedObject]);
}

- (void)testLayoutForBlockWithManyStrongObject __attribute__((optnone))
{
#define OBJ(index) __attribute__((objc_precise_lifetime)) NSObject *o ## index = [NSObject new]
  OBJ(1); OBJ(2); OBJ(3); OBJ(4); OBJ(5); OBJ(6); OBJ(7); OBJ(8);
  OBJ(9); OBJ(a); OBJ(b); OBJ(c); OBJ(d); OBJ(e); OBJ(f); OBJ(10);
  
#define W(index) __weak id w ## index = o ## index
  OBJ(21); OBJ(22); OBJ(23); OBJ(24); OBJ(25); OBJ(26); OBJ(27); OBJ(28);
  W(21); W(22); W(23); W(24); W(25); W(26); W(27); W(28);

  OBJ(31); OBJ(32); OBJ(33); OBJ(34);
  __block id b1 = o31;
  __block __weak id b2 = o32;
  __block __unsafe_unretained id b3 = o33;
  __block __unsafe_unretained id b4 = o34;
  
  struct Test {
    char b1;
    NSObject *obj;
    char b2;
  };
  OBJ(52);
  Test test;
  test.b1 = 1;
  test.obj = o52;
  test.b2 = 2;
  
  std::vector<NSObject *> v;

  __attribute__((objc_precise_lifetime)) _RCDTestBlockType block = ^{
    [o1 description]; [o2 description]; [o3 description]; [o4 description];
    [o5 description]; [o6 description]; [o7 description]; [o8 description];
    [o9 description]; [oa description]; [ob description]; [oc description];
    [od description]; [oe description]; [of description]; [o10 description];

    [w21 description]; [w22 description]; [w23 description]; [w24 description];
    [w25 description]; [w26 description]; [w27 description]; [w28 description];

    [b1 description]; [b2 description]; [b3 description]; [b4 description];

    v.size();
    [test.obj description];
  };
  
  FBObjectiveCBlock *wrappedBlock = [[FBObjectiveCBlock alloc] initWithObject:block];
  NSSet *retainedObjects = [wrappedBlock allRetainedObjects];
  XCTAssertEqual([retainedObjects count], 18);
}

#endif //_INTERNAL_RCD_ENABLED

@end
