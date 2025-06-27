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

typedef struct {
  id object;
  int identifier;
} FBRetainCycleDetectorTestStruct;

#define newObject(A) NSObject *object##A = [NSObject new]
#define __blockNewObject(A) __block NSObject *object##A = [NSObject new]
#define newStruct(A) FBRetainCycleDetectorTestStruct struct##A { .object = object##A, .identifier = A }
#define useObject(A) __unused NSObject *someObject##A = object##A
#define useStruct(A) __unused FBRetainCycleDetectorTestStruct someStruct##A = { .object = struct##A.object, .identifier = struct##A.identifier }
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

- (void)testBlockRetainsMoreThan15StrongReferencesInterspersedWithBlockReferences
{
    newObject(0); newObject(1); newObject(2); newObject(3);
    newObject(4); newObject(5); newObject(6); newObject(7);
    newObject(8); newObject(9); newObject(10); newObject(11);
    newObject(12); newObject(13); newObject(14); newObject(15);

    __blockNewObject(16); __blockNewObject(17); __blockNewObject(18); __blockNewObject(19);
    __blockNewObject(20); __blockNewObject(21); __blockNewObject(22); __blockNewObject(23);
    __blockNewObject(24); __blockNewObject(25); __blockNewObject(26); __blockNewObject(27);

    void (^block)() = ^{
        useObject(0); useObject(27); useObject(1); useObject(26);
        useObject(2); useObject(25); useObject(3); useObject(24);
        useObject(4); useObject(23); useObject(5); useObject(22);
        useObject(6); useObject(21); useObject(7); useObject(20);
        useObject(8); useObject(19); useObject(9); useObject(18);
        useObject(10); useObject(17); useObject(11); useObject(16);
        useObject(12); useObject(15); useObject(13); useObject(14);
    };

    NSArray *retainedObjects = FBGetBlockStrongReferences((__bridge void *)(block));
    XCTAssertEqual([retainedObjects count], 28);
    NSArray *expected = @[
        object0, object1, object2, object3,
        object4, object5, object6, object7,
        object8, object9, object10, object11,
        object12, object15, object13, object14,
        object27, object26, object25, object24,
        object23, object22, object21, object20,
        object19, object18, object17, object16
    ];
    [expected enumerateObjectsUsingBlock:^(NSObject *obj, NSUInteger idx, BOOL * _Nonnull stop) {
      XCTAssertEqual(obj, retainedObjects[idx], @"Object %@ at index %lu is not equal to %@", obj, idx, retainedObjects[idx]);
    }];
}

- (void)testBlockRetainsObjectsStoredInsideStructs
{
    newObject(0); newObject(1); newObject(2); newObject(3);
    newObject(4); newObject(5); newObject(6); newObject(7);
    newObject(8); newObject(9); newObject(10); newObject(11);
    newObject(12); newObject(13); newObject(14); newObject(15);
    newStruct(0); newStruct(1); newStruct(2); newStruct(3);
    newStruct(4); newStruct(5); newStruct(6); newStruct(7);
    newStruct(8); newStruct(9); newStruct(10); newStruct(11);
    newStruct(12); newStruct(13); newStruct(14); newStruct(15);

    void (^block)() = ^{
      useStruct(0); useStruct(1); useStruct(2); useStruct(3);
      useStruct(4); useStruct(5); useStruct(6); useStruct(7);
      useStruct(8); useStruct(9); useStruct(10); useStruct(11);
      useStruct(12); useStruct(13); useStruct(14); useStruct(15);
    };

    NSArray *retainedObjects = FBGetBlockStrongReferences((__bridge void *)(block));
    XCTAssertEqual([retainedObjects count], 16);

    assertObject(0); assertObject(1); assertObject(2); assertObject(3);
    assertObject(4); assertObject(5); assertObject(6); assertObject(7);
    assertObject(8); assertObject(9); assertObject(10); assertObject(11);
    assertObject(12); assertObject(13); assertObject(14); assertObject(15);
}

@end
