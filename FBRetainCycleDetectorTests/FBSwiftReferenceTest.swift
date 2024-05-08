// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import XCTest
@testable import FBRetainCycleDetector

@objc class RCDSwiftObjectWrapperTestClass: NSObject {
  var someObject: NSObject?
  var someString: String?
  weak var irrelevantObject: NSObject?
}

class FBSwiftReferenceTest: XCTestCase {
  func testObjcObjectsRetainedBySomeObjectWillBeFetched() throws {
    let someObject: NSObject = NSObject()
    let someString = "someString"
    let irrelevant: NSObject = NSObject()
    let verifyObject:RCDObjectWrapperTestClass = RCDObjectWrapperTestClass()
    let testObject:RCDObjectWrapperTestClass = RCDObjectWrapperTestClass(otherObject:verifyObject)
    testObject.someObject = someObject
    testObject.someString = someString
    testObject.irrelevantObject = irrelevant

    let configuration = FBObjectGraphConfiguration()
    let object:FBObjectiveCObject = FBObjectiveCObject(object: testObject, configuration: configuration)
    let retainedObjects: Set<AnyHashable>? = object.allRetainedObjects()
    XCTAssertFalse(retainedObjects!.contains(FBObjectiveCObject(object: irrelevant, configuration: configuration)))
    XCTAssertTrue(retainedObjects!.contains(FBObjectiveCObject(object: someObject, configuration: configuration)))
    XCTAssertTrue(retainedObjects!.contains(FBObjectiveCObject(object: someString, configuration: configuration)))
    XCTAssertTrue(retainedObjects!.contains(FBObjectiveCObject(object: verifyObject, configuration: configuration)))
  }

  func testSwiftObjectsRetainedBySomeObjectWillBeFetched() throws {
    let someObject: NSObject = NSObject()
    let someString = "someString"
    let irrelevant: NSObject = NSObject()

    let testSwiftObj = RCDSwiftObjectWrapperTestClass()
    testSwiftObj.someObject = someObject
    testSwiftObj.someString = someString
    testSwiftObj.irrelevantObject = irrelevant
    testSwiftObj.irrelevantObject = irrelevant


    
      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true)
    let object:FBObjectiveCObject = FBObjectiveCObject(object: testSwiftObj, configuration: configuration)
    let retainedObjects: Set<AnyHashable>? = object.allRetainedObjects()

    XCTAssertFalse(retainedObjects!.contains(FBObjectiveCObject(object: irrelevant, configuration: configuration)))
    XCTAssertTrue(retainedObjects!.contains(FBObjectiveCObject(object: someObject, configuration: configuration)))
    XCTAssertTrue(retainedObjects!.contains(FBObjectiveCObject(object: someString, configuration: configuration)))
  }
}
