/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <objc/runtime.h>

#import <XCTest/XCTest.h>

#import <FBRetainCycleDetector/FBAssociationManager+Internal.h>
#import <FBRetainCycleDetector/FBObjectiveCGraphElement+Internal.h>
#import <FBRetainCycleDetector/FBObjectiveCObject.h>
#import <FBRetainCycleDetector/FBRetainCycleDetector+Internal.h>

@interface FBAssociationManagerTests : XCTestCase
@end

@implementation FBAssociationManagerTests

#if _INTERNAL_RCD_ENABLED

static const char *strongAssocKey1 = "strong_assoc1";
static const char *strongAssocKey2 = "strong_assoc2";

- (void)testIfRetainCycleWithAssociatedObjectStrongIsFound
{
  NSObject *object = [NSObject new];
  NSArray *array = @[object];

  objc_setAssociatedObject(object, strongAssocKey1, array, OBJC_ASSOCIATION_RETAIN);

  // We are not interposing in tests, sounds too flaky, let's add it manually
  FB::AssociationManager::_threadUnsafeSetStrongAssociation(object, (void *)strongAssocKey1, array);
  
  XCTAssertEqual([FB::AssociationManager::associations(object) count], 1);

  FBRetainCycleDetector *detector = [FBRetainCycleDetector new];
  [detector addCandidate:array];
  NSSet *retainCycles = [detector findRetainCycles];

  NSSet *expectedCycles = [NSSet setWithObject:[detector _shiftToUnifiedCycle:
                                                @[[[FBObjectiveCObject alloc] initWithObject:object],
                                                  [[FBObjectiveCObject alloc] initWithObject:array]]]];

  XCTAssertEqualObjects(retainCycles, expectedCycles);
}

- (void)testIfRetainCycleWithAssociatedObjectStrongIsAddedAndThenRemoved
{
  NSObject *object = [NSObject new];
  NSArray *array = @[object];

  objc_setAssociatedObject(object, strongAssocKey2, array, OBJC_ASSOCIATION_RETAIN);
  FB::AssociationManager::_threadUnsafeSetStrongAssociation(object, (void *)strongAssocKey2, array);

  objc_setAssociatedObject(object, strongAssocKey2, nil, OBJC_ASSOCIATION_RETAIN);
  FB::AssociationManager::_threadUnsafeSetStrongAssociation(object, (void *)strongAssocKey2, nil);

  FBRetainCycleDetector *detector = [FBRetainCycleDetector new];
  [detector addCandidate:array];
  NSSet *retainCycles = [detector findRetainCycles];

  XCTAssertEqual([retainCycles count], 0);
}

- (void)testThatChainedAssociatedObjectsCycleIsDetected
{
  static const char *key1 = "chain_assoc1";
  static const char *key2 = "chain_assoc2";

  NSObject *objA = [NSObject new];
  NSObject *objB = [NSObject new];

  objc_setAssociatedObject(objA, key1, objB, OBJC_ASSOCIATION_RETAIN);
  FB::AssociationManager::_threadUnsafeSetStrongAssociation(objA, (void *)key1, objB);

  objc_setAssociatedObject(objB, key2, objA, OBJC_ASSOCIATION_RETAIN);
  FB::AssociationManager::_threadUnsafeSetStrongAssociation(objB, (void *)key2, objA);

  FBRetainCycleDetector *detector = [FBRetainCycleDetector new];
  [detector addCandidate:objA];
  NSSet *retainCycles = [detector findRetainCycles];
  XCTAssertEqual([retainCycles count], 1, @"Chained associations A→B→A should form cycle");
}

- (void)testThatAssociatedBlockCapturingHostCycleIsDetected
{
  static const char *key = "block_assoc";
  typedef void (^_TestBlockType)(void);

  NSObject *host = [NSObject new];
  _TestBlockType block = [^{
    (void)host;
  } copy];

  objc_setAssociatedObject(host, key, block, OBJC_ASSOCIATION_RETAIN);
  FB::AssociationManager::_threadUnsafeSetStrongAssociation(host, (void *)key, block);

  FBRetainCycleDetector *detector = [FBRetainCycleDetector new];
  [detector addCandidate:host];
  NSSet *retainCycles = [detector findRetainCycles];
  XCTAssertGreaterThan([retainCycles count], 0, @"Associated block capturing host should form cycle");
}

#endif

@end
