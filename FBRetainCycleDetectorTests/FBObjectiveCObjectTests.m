/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import <objc/runtime.h>

#import <FBRetainCycleDetector/FBObjectiveCGraphElement+Internal.h>
#import <FBRetainCycleDetector/FBObjectiveCObject.h>
#import <FBRetainCycleDetector/FBObjectGraphConfiguration.h>
#import <FBRetainCycleDetector/FBRetainCycleDetector.h>

#import <FBRetainCycleDetectorTests/FBRetainCycleDetectorTests-Swift.h>

@interface _RCDObjectWrapperTestClass : NSObject
- (instancetype)initWithOtherObject:(_RCDObjectWrapperTestClass *)object;
@property (nonatomic, strong) NSObject *someObject;
@property (nonatomic, copy) NSString *someString;
@property (nonatomic, weak) NSObject *irrelevantObject;
@property (nonatomic, strong) id aCls;
@end
@implementation _RCDObjectWrapperTestClass
{
  _RCDObjectWrapperTestClass *_someTestClassInstance;
}

- (instancetype)initWithOtherObject:(_RCDObjectWrapperTestClass *)object
{
  if (self = [super init]) {
    _someTestClassInstance = object;
  }

  return self;
}

@end

@interface _RCDObjectWrapperTestClassSubclass : _RCDObjectWrapperTestClass
@end
@implementation _RCDObjectWrapperTestClassSubclass
@end

@interface FBObjectiveCObjectTests : XCTestCase
@end
@implementation FBObjectiveCObjectTests

#if _INTERNAL_RCD_ENABLED

- (void)testObjectsRetainedBySomeObjectWillBeFetched
{
  NSObject *someObject = [NSObject new];
  NSString *someString = @"someString";
  NSObject *irrelevant = [NSObject new];
  _RCDObjectWrapperTestClass *verifyObject = [_RCDObjectWrapperTestClass new];
  _RCDObjectWrapperTestClass *testObject = [[_RCDObjectWrapperTestClass alloc] initWithOtherObject:verifyObject];
  testObject.someObject = someObject;
  testObject.someString = someString;
  testObject.irrelevantObject = irrelevant;

  FBObjectiveCObject *object = [[FBObjectiveCObject alloc] initWithObject:testObject];
  NSSet *retainedObjects = [object allRetainedObjects];

  XCTAssertFalse([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:irrelevant]]);
  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:someObject]]);
  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:someString]]);
  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:verifyObject]]);

}

- (void)testObjectsRetainedByArrayWillBeFetched
{
  NSString *someString = @"someString";
  NSObject *someObject = [NSObject new];
  NSDictionary *someDictionary = [NSDictionary new];
  NSArray *testedArray = @[someString, someObject, someDictionary];

  FBObjectiveCObject *abstractedObject = [[FBObjectiveCObject alloc] initWithObject:testedArray];

  NSSet *retainedObjects = [abstractedObject allRetainedObjects];

  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:someString]]);
  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:someObject]]);
  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:someDictionary]]);
}

- (void)testObjectsRetainedByDictionaryWillBeFetched
{
  NSString *someString = @"someString";
  NSObject *someObject = [NSObject new];

  NSDictionary *someDictionary = @{someString:someObject};

  FBObjectiveCObject *abstractedObject = [[FBObjectiveCObject alloc] initWithObject:someDictionary];

  NSSet *retainedObjects = [abstractedObject allRetainedObjects];

  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:someString]]);
  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:someObject]]);
}

- (void)testObjectsRetainedBySetWillBeFetched
{
  NSString *someString = @"someString";
  NSObject *someObject = [NSObject new];

  NSSet *someSet = [NSSet setWithObjects:someString, someObject, nil];

  FBObjectiveCObject *abstractedObject = [[FBObjectiveCObject alloc] initWithObject:someSet];

  NSSet *retainedObjects = [abstractedObject allRetainedObjects];

  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:someString]]);
  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:someObject]]);
}

- (void)testThatIfObjectHasStrongPropertyWithNilThenItWontFetchIt
{
  _RCDObjectWrapperTestClass *someObject = [_RCDObjectWrapperTestClass new];

  FBObjectiveCObject *abstractedObject = [[FBObjectiveCObject alloc] initWithObject:someObject];

  NSSet *retainedObjects = [abstractedObject allRetainedObjects];

  XCTAssertEqual([retainedObjects count], 0);
}

- (void)testObjectThatSubclassesFromObjectWithStrongPropertiesWillFetchPropertiesFromParentClass
{
  _RCDObjectWrapperTestClassSubclass *testObject = [_RCDObjectWrapperTestClassSubclass new];
  NSObject *someObject = [NSObject new];
  NSObject *irrelevantObject = [NSObject new];
  NSString *someString = @"someString";
  testObject.someObject = someObject;
  testObject.irrelevantObject = irrelevantObject;
  testObject.someString = someString;

  FBObjectiveCObject *abstractedObject = [[FBObjectiveCObject alloc] initWithObject:testObject];

  NSSet *retainedObjects = [abstractedObject allRetainedObjects];

  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:someString]]);
  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:someObject]]);
  XCTAssertFalse([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:irrelevantObject]]);
}

- (void)testObjectRetainingClassConformingToFastEnumerationWillNotCrash
{
  _RCDObjectWrapperTestClass *someObject = [_RCDObjectWrapperTestClass new];
  someObject.aCls = [NSArray class];

  FBObjectiveCObject *abstractedObject = [[FBObjectiveCObject alloc] initWithObject:someObject];

  NSSet *retainedObjects = [abstractedObject allRetainedObjects];

  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:[NSArray class]]]);
}

- (void)testHashTableWithWeakObjectsWillNotFetchThoseObjects
{
  NSHashTable *hashTable = [NSHashTable weakObjectsHashTable];

  _RCDObjectWrapperTestClass *someObject1 = [_RCDObjectWrapperTestClass new];
  _RCDObjectWrapperTestClass *someObject2 = [_RCDObjectWrapperTestClass new];
  _RCDObjectWrapperTestClass *someObject3 = [_RCDObjectWrapperTestClass new];

  [hashTable addObject:someObject1];
  [hashTable addObject:someObject2];
  [hashTable addObject:someObject3];

  FBObjectiveCObject *abstractedObject = [[FBObjectiveCObject alloc] initWithObject:hashTable];

  NSSet *retainedObjects = [abstractedObject allRetainedObjects];

  XCTAssertEqual([retainedObjects count], 0);
}

- (void)testHashTableWithStrongObjectsWillFetchThoseObjects
{
  NSHashTable *hashTable = [NSHashTable new];

  _RCDObjectWrapperTestClass *someObject1 = [_RCDObjectWrapperTestClass new];
  _RCDObjectWrapperTestClass *someObject2 = [_RCDObjectWrapperTestClass new];
  _RCDObjectWrapperTestClass *someObject3 = [_RCDObjectWrapperTestClass new];

  [hashTable addObject:someObject1];
  [hashTable addObject:someObject2];
  [hashTable addObject:someObject3];

  FBObjectiveCObject *abstractedObject = [[FBObjectiveCObject alloc] initWithObject:hashTable];

  NSSet *retainedObjects = [abstractedObject allRetainedObjects];

  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:someObject1]]);
  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:someObject2]]);
  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:someObject3]]);
}

- (void)testMapTableWithWeakKeysAndValueWillNotFetchAnything
{
  NSMapTable *mapTable = [NSMapTable weakToWeakObjectsMapTable];

  _RCDObjectWrapperTestClass *keyObject = [_RCDObjectWrapperTestClass new];
  _RCDObjectWrapperTestClass *valueObject = [_RCDObjectWrapperTestClass new];

  [mapTable setObject:valueObject forKey:keyObject];

  FBObjectiveCObject *abstractedObject = [[FBObjectiveCObject alloc] initWithObject:mapTable];

  NSSet *retainedObjects = [abstractedObject allRetainedObjects];

  XCTAssertEqual([retainedObjects count], 0);
}

- (void)testMapTableWithWeakKeysAndStrongValuesWillFetchOnlyValues
{
  NSMapTable *mapTable = [NSMapTable weakToStrongObjectsMapTable];

  _RCDObjectWrapperTestClass *keyObject = [_RCDObjectWrapperTestClass new];
  _RCDObjectWrapperTestClass *valueObject = [_RCDObjectWrapperTestClass new];

  [mapTable setObject:valueObject forKey:keyObject];

  FBObjectiveCObject *abstractedObject = [[FBObjectiveCObject alloc] initWithObject:mapTable];

  NSSet *retainedObjects = [abstractedObject allRetainedObjects];

  XCTAssertEqual([retainedObjects count], 1);
  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:valueObject]]);
}

- (void)testMapTableWithStrongKeysAndWeakValuesWillFetchOnlyKeys
{
  NSMapTable *mapTable = [NSMapTable strongToWeakObjectsMapTable];

  _RCDObjectWrapperTestClass *keyObject = [_RCDObjectWrapperTestClass new];
  _RCDObjectWrapperTestClass *valueObject = [_RCDObjectWrapperTestClass new];

  [mapTable setObject:valueObject forKey:keyObject];

  FBObjectiveCObject *abstractedObject = [[FBObjectiveCObject alloc] initWithObject:mapTable];

  NSSet *retainedObjects = [abstractedObject allRetainedObjects];

  XCTAssertEqual([retainedObjects count], 1);
  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:keyObject]]);
}

- (void)testMapTableWithStrongKeysAndStrongValuesWillFetchBothKeysAndValues
{
  NSMapTable *mapTable = [NSMapTable strongToStrongObjectsMapTable];

  _RCDObjectWrapperTestClass *keyObject = [_RCDObjectWrapperTestClass new];
  _RCDObjectWrapperTestClass *valueObject = [_RCDObjectWrapperTestClass new];

  [mapTable setObject:valueObject forKey:keyObject];

  FBObjectiveCObject *abstractedObject = [[FBObjectiveCObject alloc] initWithObject:mapTable];

  NSSet *retainedObjects = [abstractedObject allRetainedObjects];

  XCTAssertEqual([retainedObjects count], 2);
  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:keyObject]]);
  XCTAssertTrue([retainedObjects containsObject:[[FBObjectiveCObject alloc] initWithObject:valueObject]]);
}

- (void)testTollFreeBridgedDictionaryWillNotCrash
{
  CFDictionaryValueCallBacks cb = kCFTypeDictionaryValueCallBacks;
  cb.retain = NULL;
  cb.release = NULL;
  NSMutableDictionary *dictionary = (__bridge_transfer id)CFDictionaryCreateMutable(NULL, 0, NULL, &cb);
  NSInteger intV = 5;
  CFDictionarySetValue((CFMutableDictionaryRef)dictionary, (__bridge const void *)@"key", (const void *)intV);

  FBObjectiveCObject *abstractedObject = [[FBObjectiveCObject alloc] initWithObject:dictionary];

  NSSet *retainedObjects = [abstractedObject allRetainedObjects];

  XCTAssertEqual([retainedObjects count], 0);
}

- (void)testAllRetainedObjectsReturnsNilForDeallocatedObject
{
  FBObjectiveCObject *graphElement;
  @autoreleasepool {
    NSObject *obj = [NSObject new];
    graphElement = [[FBObjectiveCObject alloc] initWithObject:obj
                                               configuration:[FBObjectGraphConfiguration new]
                                                    namePath:nil];
    // Verify it works while the object is alive
    XCTAssertNotNil([graphElement allRetainedObjects]);
  }
  // obj is now deallocated, weak reference zeroed
  NSSet *result = [graphElement allRetainedObjects];
  XCTAssertNil(result);
}

- (void)testAllRetainedObjectsReturnsNilForInvalidUnsafeSwiftPointer
{
  // Create a graph element with no object set
  FBObjectiveCObject *graphElement = [[FBObjectiveCObject alloc] initWithObject:nil
                                                                 configuration:[FBObjectGraphConfiguration new]
                                                                      namePath:nil];

  // Use the ObjC runtime to plant a non-malloc pointer into _unsafeSwiftObject.
  // This simulates a Swift object whose memory is no longer in a valid malloc zone.
  int stackVar = 0;
  Ivar ivar = class_getInstanceVariable([FBObjectiveCGraphElement class], "_unsafeSwiftObject");
  XCTAssertTrue(ivar != NULL, @"_unsafeSwiftObject ivar must exist");
  if (!ivar) {
    return;
  }
  void **ivarPtr = (void **)((uint8_t *)(__bridge void *)graphElement + ivar_getOffset(ivar));
  *ivarPtr = &stackVar;

  // The element now owns a swift_retain on _unsafeSwiftObject and releases it in
  // -dealloc. We planted a raw stack pointer (bypassing the retaining
  // initializer), so the ivar MUST be cleared before the element deallocs —
  // otherwise -dealloc would swift_release a stack address. Use @finally so the
  // reset runs even if an XCTAssert raises an NSException (which XCTest does
  // when continueAfterFailure == NO): the @finally block executes during stack
  // unwinding, before the exception propagates to XCTest's exception handler
  // for result recording, so cleanup happens before the test method returns.
  @try {
    // objectPtr should now return the planted pointer
    XCTAssertNotEqual([graphElement objectPtr], NULL);

    // allRetainedObjects must return nil (not crash) because
    // malloc_zone_from_ptr returns NULL for stack addresses
    XCTAssertNil([graphElement allRetainedObjects]);
  } @finally {
    *ivarPtr = NULL;
  }
}

- (void)testInitWithUnsafeSwiftObjectIgnoresNonHeapPointer
{
  // A non-heap (stack) address is rejected by the malloc_zone_from_ptr guard in
  // initWithUnsafeSwiftObject:, so the pointer is neither stored nor retained.
  // This pins down that the owning swift_retain is gated on a valid malloc zone
  // — and therefore that -dealloc is a no-op for such elements (no unbalanced
  // swift_release on memory we never retained).
  //
  // The complementary "stored pointer is in an invalid zone at traversal time →
  // allRetainedObjects returns nil, no crash" path is covered by
  // testAllRetainedObjectsReturnsNilForInvalidUnsafeSwiftPointer above. The old
  // "free real heap memory out from under the element" scenario no longer
  // applies: the element now owns a swift_retain for its whole lifetime, so the
  // object cannot be freed while the element is alive.
  int stackVar = 0;
  FBObjectiveCObject *graphElement =
      [[FBObjectiveCObject alloc] initWithUnsafeSwiftObject:&stackVar
                                             configuration:[FBObjectGraphConfiguration new]
                                                  namePath:nil];

  XCTAssertEqual([graphElement objectPtr], NULL);
  XCTAssertNil([graphElement allRetainedObjects]);
}

- (void)testInitWithUnsafeSwiftObjectStoresAndRetainsHeapPointer
{
  // Positive complement to testInitWithUnsafeSwiftObjectIgnoresNonHeapPointer:
  // a heap pointer with a valid malloc zone IS accepted, stored, and retained
  // by the initializer. We use an ObjC NSObject so that swift_retain (which
  // falls through to objc_retain for objects with an ObjC isa) is safe to
  // call; malloc_zone_from_ptr returns a valid zone for ObjC-allocated heap
  // objects, satisfying the init guard. The store-after-retain coupling means
  // a non-NULL objectPtr here implies the swift_retain succeeded.
  NSObject *heapObj = [NSObject new];
  void *heapPtr = (__bridge void *)heapObj;

  FBObjectiveCObject *graphElement =
      [[FBObjectiveCObject alloc] initWithUnsafeSwiftObject:heapPtr
                                             configuration:[FBObjectGraphConfiguration new]
                                                  namePath:nil];

  XCTAssertEqual([graphElement objectPtr], heapPtr);
  // heapObj outlives graphElement in this scope, so the swift_release issued
  // by -dealloc when graphElement goes out of scope is balanced against one
  // of heapObj's still-live retains and does not free it prematurely.
}

- (void)testOwningRetainBalanceForPureSwiftObject
{
  // End-to-end balance check for the owning swift_retain/swift_release pair on a
  // *pure-Swift* object (the production crash population), driven via
  // RCDDeinitProbeHarness. This is the one test that fails on ALL THREE
  // regressions the new ownership contract could introduce:
  //   - forgot-to-retain in -initWithUnsafeSwiftObject: -> the probe deinits as
  //     soon as the external ref is dropped (deinitCount == 1 too early).
  //   - leak / missing swift_release in -dealloc -> the probe never deinits
  //     (deinitCount stays 0 after the element is gone).
  //   - double-release -> over-release crash / early deinit.
  // The existing init tests only assert the guard+store halves; nothing else
  // observes that the retain is actually balanced by exactly one release.
  [RCDDeinitProbeHarness resetDeinitCount];

  // +1 external strong ref, simulating the single FBSwiftStrongRef the RCD
  // manager holds on a candidate at the moment the graph element is built.
  void *probePtr = [RCDDeinitProbeHarness makeRetainedProbe];

  FBObjectiveCObject *graphElement =
      [[FBObjectiveCObject alloc] initWithUnsafeSwiftObject:probePtr
                                             configuration:[FBObjectGraphConfiguration new]
                                                  namePath:nil];
  XCTAssertEqual([graphElement objectPtr], probePtr, @"valid heap Swift pointer must be stored");

  // Drop the external ref. Only the element's owning swift_retain remains, so
  // the object must stay alive (this is exactly what was broken before the fix).
  [RCDDeinitProbeHarness releaseProbe:probePtr];
  XCTAssertEqual(
      [RCDDeinitProbeHarness deinitCount],
      0,
      @"owning swift_retain must keep the pure-Swift object alive after the only external ref is dropped");

  // A detection pass over the pinned object must not use-after-free.
  XCTAssertNoThrow([graphElement allRetainedObjects]);
  XCTAssertEqual(
      [RCDDeinitProbeHarness deinitCount], 0, @"object must stay alive for the element's whole lifetime");

  // Releasing the element runs -dealloc, which must swift_release exactly once.
  graphElement = nil;
  XCTAssertEqual(
      [RCDDeinitProbeHarness deinitCount],
      1,
      @"-dealloc must swift_release exactly once: no leak (would stay 0) and no double-release (would over-release)");
}

#endif //_INTERNAL_RCD_ENABLED

@end
