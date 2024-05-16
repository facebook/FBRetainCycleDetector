// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import XCTest
@testable import FBRetainCycleDetector

@objc class ObjcBackedSwiftObjectWrapperTestClass: NSObject {
 var someObject: NSObject?
 var someAny: Any?
 var someString: String?
 weak var irrelevantObject: NSObject?
}

class PureSwift {
 var someObject: Any?
}

class FBRetainCycleSwiftDetectorTests: XCTestCase {

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

 func testThatDetectorWillFindCycleWithSwiftObjInTheMiddle() {
      let testObject = ObjcBackedSwiftObjectWrapperTestClass()
      let swiftObj = ObjcBackedSwiftObjectWrapperTestClass()
      swiftObj.someObject = testObject
      testObject.someObject = swiftObj
      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true)

      let detector = FBRetainCycleDetector(configuration: configuration);
      detector.addCandidate(testObject);
      let retainCycles = detector.findRetainCycles();
      XCTAssertEqual(retainCycles.count, 1)
    }

    func testThatConfigurationCacheSuportSwiftObj() {
        let configuration = FBObjectGraphConfiguration(
          filterBlocks: [],
          shouldInspectTimers: false,
          transformerBlock: nil,
          shouldIncludeBlockAddress: true,
          shouldIncludeSwiftObjects: true)
        let pureSwifObject = PureSwift()
        let references = FBGetObjectStrongReferences(pureSwifObject, configuration.layoutCache, true);
        XCTAssertEqual(references.count, 1)
      }

    func testThatDetectorWillFindCycleWithPureSwiftObjs() {
      let objA = PureSwift()
      let objB = PureSwift()
      objA.someObject = objB
      objB.someObject = objA
      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true)

      let detector = FBRetainCycleDetector(configuration: configuration);
      detector.addCandidate(objA);
      let retainCycles = detector.findRetainCycles();
      XCTAssertEqual(retainCycles.count, 1)
    }

    func testThatDetectorWillFindCycleWithCombineTypes() {
      // OBJ class
      // swift baked by OBJ
      // pure swift class
      
      let objcObj = RCDObjectWrapperTestClass()
      let objcBackedSwiftObjec = ObjcBackedSwiftObjectWrapperTestClass()
      let pureSwiftObj = PureSwift()
      

      objcObj.someObject = objcBackedSwiftObjec
      objcBackedSwiftObjec.someAny = pureSwiftObj
      pureSwiftObj.someObject = objcObj
        
      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true)

      let detector = FBRetainCycleDetector(configuration: configuration);
      detector.addCandidate(pureSwiftObj);
      let retainCycles = detector.findRetainCycles();
      XCTAssertEqual(retainCycles.count, 1)
    }

}
