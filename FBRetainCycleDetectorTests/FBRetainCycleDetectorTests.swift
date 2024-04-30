// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import XCTest
@testable import FBRetainCycleDetector

@objc class ObjcBackedSwiftObjectWrapperTestClass: NSObject {
 var someObject: NSObject?
 var someString: String?
 weak var irrelevantObject: NSObject?
}


class FBRetainCycleDetectorTests: XCTestCase {

 func testThatDetectorWillFindNoCyclesInEmptyObject() {
  let verifyObject = RCDObjectWrapperTestClass()
  let testObject = RCDObjectWrapperTestClass(otherObject:verifyObject)
  let detector = FBRetainCycleDetector();
  detector.addCandidate(testObject);
  let retainCycles = detector.findRetainCycles();
  XCTAssertEqual(retainCycles.count, 0)
}

func testThatDetectorWillFindCycleCreatedByOneObjectWithItself() {
  let testObject:RCDObjectWrapperTestClass = RCDObjectWrapperTestClass()
  testObject.someObject = testObject

  let detector = FBRetainCycleDetector();
  detector.addCandidate(testObject);
  let retainCycles = detector.findRetainCycles();
  XCTAssertEqual(retainCycles.count, 1)

  let arr: [AnyHashable] = [FBObjectiveCObject(object: testObject, configuration: FBObjectGraphConfiguration(), namePath: ["_someObject"])]
  let setContainer: Set<AnyHashable> = [arr]
  XCTAssertEqual(retainCycles, setContainer);
}

 // confirm it does not detect swift objects.
 func testThatDetectorWillFindCycleWithSwiftObjInTheMiddle() {
      let testObject = ObjcBackedSwiftObjectWrapperTestClass()
      let swiftObj = ObjcBackedSwiftObjectWrapperTestClass()
      swiftObj.someObject = testObject
      testObject.someObject = swiftObj

      let detector = FBRetainCycleDetector();
      detector.addCandidate(testObject);
      let retainCycles = detector.findRetainCycles();
      XCTAssertEqual(retainCycles.count, 0)
    }

}
