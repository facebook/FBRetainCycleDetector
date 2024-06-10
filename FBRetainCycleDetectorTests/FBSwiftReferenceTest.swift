// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import XCTest
@testable import FBRetainCycleDetector

@objc class RCDSwiftObjectWrapperTestClass: NSObject {
  var someObject: NSObject?
  var someString: String?
  weak var irrelevantObject: NSObject?
}

@objc class SwiftAndKVOTestClass: NSObject {
 @objc public dynamic var someObject: NSObject?
 var someAny: Any?
 @objc public dynamic var observer: NSKeyValueObservation?

    init(someObject: NSObject? = nil, someAny: Any? = nil) {
        self.someObject = someObject
        self.someAny = someAny
        super.init()
        
        observer = observe(\.someObject, options: [.old, .new], changeHandler: { badgeController, change in
            print("called after change")
        })
        
    }
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
    
    func testSwiftKVOReferences() throws {
      let someObject: NSObject = NSObject()
      // KVO need expecial treadment
        //https://forums.swift.org/t/type-of-vs-object-getclass-difference/59404
        //https://github.com/apple/swift/pull/16923
        
      let testSwiftObj = SwiftAndKVOTestClass(someObject: someObject)
        
        let configuration = FBObjectGraphConfiguration(
          filterBlocks: [],
          shouldInspectTimers: false,
          transformerBlock: nil,
          shouldIncludeBlockAddress: true,
          shouldIncludeSwiftObjects: true)
      let object:FBObjectiveCObject = FBObjectiveCObject(object: testSwiftObj, configuration: configuration)
      let retainedObjects: Set<AnyHashable>? = object.allRetainedObjects()

      XCTAssertTrue(retainedObjects!.contains(FBObjectiveCObject(object: someObject, configuration: configuration)))
 
    }
}
