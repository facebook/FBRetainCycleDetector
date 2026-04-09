// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.
/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

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

class PureSwiftTarget {}

class PureSwiftWithWeak {
  weak var weakRef: PureSwiftTarget?
}

class PureSwiftWithUnowned {
  unowned var unownedRef: PureSwiftTarget

  init(target: PureSwiftTarget) {
    self.unownedRef = target
  }
}

class PureSwiftWithMixedRefs {
  var strongRef: PureSwiftTarget?
  weak var weakRef: PureSwiftTarget?
  unowned var unownedRef: PureSwiftTarget

  init(target: PureSwiftTarget) {
    self.unownedRef = target
  }
}

class PureSwiftWithStrongAndWeak {
  var strongRef: AnyObject?
  weak var weakRef: AnyObject?
}

class PureSwiftWithMultipleStrong {
  var strong1: PureSwiftTarget?
  var strong2: PureSwiftTarget?
  var strong3: PureSwiftTarget?
}

class PureSwiftWithClosure {
  var closure: (() -> Void)?
}

class PureSwiftWithOptionalClosure {
  var strongRef: AnyObject?
  var closure: (() -> Void)?
}

@objc class ObjcBackedWithClosure: NSObject {
  var closure: (() -> Void)?
  var strongRef: AnyObject?
}

class PureSwiftSubclassOfObjcBacked: ObjcBackedSwiftObjectWrapperTestClass {
  var pureSwiftRef: AnyObject?
}

protocol PureSwiftProtocol: AnyObject {
  var ref: AnyObject? { get set }
}

class PureSwiftProtocolImpl: PureSwiftProtocol {
  var ref: AnyObject?
}

class PureSwiftWithProtocolRef {
  var delegate: PureSwiftProtocol?
}

class PureSwiftWithLazyVar {
  var strongRef: AnyObject?
  lazy var lazyRef: AnyObject? = nil
}

class PureSwiftDeepA {
  var ref: AnyObject?
}

class PureSwiftDeepB {
  var ref: AnyObject?
}

class PureSwiftDeepC {
  var ref: AnyObject?
}

class PureSwiftDeepD {
  var ref: AnyObject?
}

class PureSwiftWithSwiftArray {
  var items: [AnyObject] = []
}

class PureSwiftWithSwiftDict {
  var map: [String: AnyObject] = [:]
}

// Pure Swift inheritance chain — no NSObject
class PureSwiftBase {
  var baseRef: AnyObject?
}

class PureSwiftChild: PureSwiftBase {
  var childRef: AnyObject?
}

class PureSwiftGrandchild: PureSwiftChild {
  var grandchildRef: AnyObject?
}

struct StructWithStrongRef {
  var ref: AnyObject?
}

struct StructWithMixedFields {
  var intValue: Int = 0
  var ref: AnyObject?
  var doubleValue: Double = 0.0
}

struct StructWithMultipleRefs {
  var ref1: AnyObject?
  var ref2: AnyObject?
}

struct InnerStruct {
  var ref: AnyObject?
}

struct OuterStruct {
  var inner: InnerStruct
  var value: Int = 0
}

struct StructWithWeakRef {
  weak var ref: AnyObject?
}

class PureSwiftWithStructField {
  var myStruct = StructWithStrongRef()
}

class PureSwiftWithMixedStruct {
  var myStruct = StructWithMixedFields()
}

class PureSwiftWithMultiRefStruct {
  var myStruct = StructWithMultipleRefs()
}

class PureSwiftWithNestedStruct {
  var myStruct: OuterStruct = OuterStruct(inner: InnerStruct())
}

class PureSwiftWithWeakStruct {
  var myStruct = StructWithWeakRef()
}

class PureSwiftWithStructAndRef {
  var myStruct = StructWithStrongRef()
  var directRef: AnyObject?
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
          shouldIncludeSwiftObjects: true,
          shouldUseSwiftABITraversal: true)
        let pureSwifObject = PureSwift()
        let references = FBGetObjectStrongReferences(pureSwifObject, configuration.layoutCache, true, false);
        XCTAssertEqual(references.count, 1)
      }

      func testThatGotReferenceWithNilCache() {
        let pureSwifObject = PureSwift()
        let references = FBGetObjectStrongReferences(pureSwifObject, nil, true, false);
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
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

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
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration);
      detector.addCandidate(pureSwiftObj);
      let retainCycles = detector.findRetainCycles();
      XCTAssertEqual(retainCycles.count, 1)
    }

    // MARK: - Swift ABI Traversal — weak/unowned/strong reference tests

    func testABITraversal_weakOnlyClass_returnsNoStrongRefs() {
      let target = PureSwiftTarget()
      let holder = PureSwiftWithWeak()
      holder.weakRef = target
      let references = FBGetObjectStrongReferences(holder, nil, true, true)
      XCTAssertEqual(references.count, 0, "Weak-only class should have no strong references")
    }

    func testABITraversal_unownedOnlyClass_returnsNoStrongRefs() {
      let target = PureSwiftTarget()
      let holder = PureSwiftWithUnowned(target: target)
      let references = FBGetObjectStrongReferences(holder, nil, true, true)
      XCTAssertEqual(references.count, 0, "Unowned-only class should have no strong references")
    }

    func testABITraversal_mixedRefs_returnsOnlyStrongRefs() {
      let target = PureSwiftTarget()
      let holder = PureSwiftWithMixedRefs(target: target)
      holder.strongRef = target
      holder.weakRef = target
      let references = FBGetObjectStrongReferences(holder, nil, true, true)
      XCTAssertEqual(references.count, 1, "Mixed class should return only the strong reference")
    }

    func testABITraversal_strongAndWeak_returnsOnlyStrongRef() {
      let target = PureSwiftTarget()
      let holder = PureSwiftWithStrongAndWeak()
      holder.strongRef = target
      holder.weakRef = target
      let references = FBGetObjectStrongReferences(holder, nil, true, true)
      XCTAssertEqual(references.count, 1, "Should return only the strong reference, not the weak one")
    }

    func testABITraversal_multipleStrongRefs_returnsAll() {
      let holder = PureSwiftWithMultipleStrong()
      holder.strong1 = PureSwiftTarget()
      holder.strong2 = PureSwiftTarget()
      holder.strong3 = PureSwiftTarget()
      let references = FBGetObjectStrongReferences(holder, nil, true, true)
      XCTAssertEqual(references.count, 3, "Should return all 3 strong references")
    }

    func testABITraversal_singleStrongRef_returnsOne() {
      let pureSwiftObject = PureSwift()
      pureSwiftObject.someObject = PureSwiftTarget()
      let references = FBGetObjectStrongReferences(pureSwiftObject, nil, true, true)
      XCTAssertEqual(references.count, 1, "Should return the single strong reference")
    }

    func testABITraversal_cycleWithWeakBreak_noCycleDetected() {
      // A -> B (strong), B -> A (weak) — no cycle
      let objA = PureSwiftWithStrongAndWeak()
      let objB = PureSwiftWithStrongAndWeak()
      objA.strongRef = objB
      objB.weakRef = objA
      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(objA)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 0, "Weak back-reference should not form a cycle")
    }

    func testABITraversal_cycleWithStrongRefs_cycleDetected() {
      // A -> B (strong), B -> A (strong) — cycle
      let objA = PureSwiftWithStrongAndWeak()
      let objB = PureSwiftWithStrongAndWeak()
      objA.strongRef = objB
      objB.strongRef = objA
      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(objA)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Two strong references should form a cycle")
    }

    // MARK: - Swift ABI Traversal — closure capture tests

    func testABITraversal_closureCapturingSelfStrongly_cycleDetected() {
      let obj = PureSwiftWithClosure()
      obj.closure = { [obj] in
        _ = obj
      }
      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(obj)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Closure strongly capturing self should form a cycle")
    }

    func testABITraversal_closureCapturingSelfWeakly_noCycle() {
      let obj = PureSwiftWithClosure()
      obj.closure = { [weak obj] in
        _ = obj
      }
      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(obj)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 0, "Closure weakly capturing self should not form a cycle")
    }

    func testABITraversal_closureCapturingAnotherObjectStrongly() {
      let obj = PureSwiftWithClosure()
      let target = PureSwiftTarget()
      obj.closure = {
        _ = target
      }
      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(obj)
      let retainedObjects = detector.findRetainCycles()
      // obj -> closure -> target, no cycle since target doesn't point back
      XCTAssertEqual(retainedObjects.count, 0, "No cycle when closure captures a different object without back-reference")
    }

    func testABITraversal_closureCapturingUnowned_noCycle() {
      let obj = PureSwiftWithClosure()
      obj.closure = { [unowned obj] in
        _ = obj
      }
      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(obj)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 0, "Closure with unowned capture should not form a cycle")
    }

    func testABITraversal_closureCycleViaIntermediateObject() {
      // obj.strongRef = target, target.closure captures obj strongly → cycle
      let obj = PureSwiftWithOptionalClosure()
      let target = PureSwiftWithOptionalClosure()
      obj.strongRef = target
      target.closure = {
        _ = obj
      }
      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(obj)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Cycle via strong ref + closure capture should be detected")
    }

    func testABITraversal_nilClosure_noReferences() {
      let obj = PureSwiftWithClosure()
      // closure is nil
      let references = FBGetObjectStrongReferences(obj, nil, true, true)
      XCTAssertEqual(references.count, 0, "Nil closure should not produce any references")
    }

    // MARK: - Mixed type cycles with closures

    func testABITraversal_pureSwiftClosureCapturingObjC_cycle() {
      // Pure Swift → closure → captures ObjC object → ObjC points back to Pure Swift
      let pureSwift = PureSwiftWithClosure()
      let objcObj = RCDObjectWrapperTestClass()
      pureSwift.closure = {
        _ = objcObj
      }
      objcObj.aCls = pureSwift

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(pureSwift)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Cycle: pureSwift → closure → objcObj → pureSwift")
    }

    func testABITraversal_pureSwiftClosureCapturingObjcBacked_cycle() {
      // Pure Swift → closure → captures ObjC-backed Swift → points back
      let pureSwift = PureSwiftWithClosure()
      let objcBacked = ObjcBackedSwiftObjectWrapperTestClass()
      pureSwift.closure = {
        _ = objcBacked
      }
      objcBacked.someAny = pureSwift

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(pureSwift)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Cycle: pureSwift → closure → objcBacked → pureSwift")
    }

    func testABITraversal_objcBlockCapturingObjcBacked_cycle() {
      // ObjC object with native ObjC block → block captures ObjC-backed Swift → points back
      let objcObj = RCDObjectWrapperWithBlock()
      let objcBacked = ObjcBackedSwiftObjectWrapperTestClass()
      objcObj.setBlockCapturing(objcBacked)
      objcBacked.someObject = objcObj

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(objcObj)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Cycle: objcObj → native ObjC block → objcBacked → objcObj")
    }

    func testABITraversal_objcBackedWithClosureCapturingSelf_cycle() {
      // ObjC-backed Swift object with closure capturing self
      let objcBacked = ObjcBackedWithClosure()
      objcBacked.closure = { [objcBacked] in
        _ = objcBacked
      }

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(objcBacked)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "ObjC-backed Swift with closure capturing self should form a cycle")
    }

    // MARK: - Multi-capture closures

    func testABITraversal_closureWithTwoStrongCaptures() {
      let obj = PureSwiftWithClosure()
      let target1 = PureSwiftTarget()
      let target2 = PureSwiftTarget()
      obj.closure = {
        _ = target1
        _ = target2
      }
      // target1 points back to obj → cycle through closure
      // (target1 is PureSwiftTarget which has no fields, so no cycle possible)
      // Instead, test reference counting: obj should have the closure field
      // which captures two objects. No cycle since neither target points back.
      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(obj)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 0, "No cycle when captures don't point back")
    }

    func testABITraversal_closureWithMixedStrongAndWeakCaptures_noCycle() {
      // Closure captures obj weakly and target strongly
      // target does NOT point back → no cycle
      let obj = PureSwiftWithOptionalClosure()
      let target = PureSwiftTarget()
      obj.closure = { [weak obj] in
        _ = obj
        _ = target
      }

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(obj)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 0, "No cycle: obj → closure → [weak obj (skip), strong target (no back-ref)]")
    }

    func testABITraversal_closureWithMixedStrongAndWeakCaptures_cycle() {
      // Closure captures obj weakly and target strongly
      // target points back to obj via strong ref → cycle through strong capture
      let obj = PureSwiftWithOptionalClosure()
      let target = PureSwiftWithOptionalClosure()
      obj.closure = { [weak obj] in
        _ = obj
        _ = target
      }
      target.strongRef = obj

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(obj)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Cycle via strong capture: obj → closure → target → obj")
    }

    // MARK: - Cross-boundary closure chains

    func testABITraversal_longMixedChainWithClosure_cycle() {
      // ObjC → Pure Swift → closure → ObjC-backed Swift → back to ObjC
      let objcObj = RCDObjectWrapperTestClass()
      let pureSwift = PureSwiftWithClosure()
      let objcBacked = ObjcBackedSwiftObjectWrapperTestClass()

      objcObj.aCls = pureSwift
      pureSwift.closure = {
        _ = objcBacked
      }
      objcBacked.someObject = objcObj

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(objcObj)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "4-step mixed cycle: ObjC → pureSwift → closure → objcBacked → ObjC")
    }

    func testABITraversal_threeWayCycleThroughClosure() {
      // pureSwift.closure captures objcBacked, objcBacked holds pureSwift2, pureSwift2 holds pureSwift
      let pureSwift = PureSwiftWithOptionalClosure()
      let objcBacked = ObjcBackedSwiftObjectWrapperTestClass()
      let pureSwift2 = PureSwift()

      pureSwift.closure = {
        _ = objcBacked
      }
      objcBacked.someAny = pureSwift2
      pureSwift2.someObject = pureSwift

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(pureSwift)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "3-way cycle: pureSwift → closure → objcBacked → pureSwift2 → pureSwift")
    }

    // MARK: - Edge cases

    func testABITraversal_pureSwiftSelfReference_cycle() {
      let obj = PureSwift()
      obj.someObject = obj

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(obj)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Object referencing itself should form a cycle")
    }

    func testABITraversal_pureSwiftSubclassOfObjcBacked_cycle() {
      // Subclass adds pure Swift field; superclass has ObjC-backed fields
      // Both levels should be traversed
      let sub = PureSwiftSubclassOfObjcBacked()
      let target = PureSwiftSubclassOfObjcBacked()
      sub.pureSwiftRef = target      // pure Swift field (subclass)
      target.someObject = sub         // ObjC-backed field (superclass)

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(sub)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Cycle across pure Swift subclass and ObjC-backed superclass fields")
    }

    func testABITraversal_pureSwiftHoldingNSObject() {
      // Pure Swift object stores an NSObject — verifies ABI traversal
      // correctly handles ObjC objects stored in pure Swift fields
      let pureSwift = PureSwift()
      let nsObj = NSObject()
      pureSwift.someObject = nsObj

      let references = FBGetObjectStrongReferences(pureSwift, nil, true, true)
      XCTAssertEqual(references.count, 1, "Pure Swift holding NSObject should detect 1 strong reference")
    }

    // MARK: - Protocol-typed properties

    func testABITraversal_protocolTypedProperty_cycle() {
      let holder = PureSwiftWithProtocolRef()
      let impl = PureSwiftProtocolImpl()
      holder.delegate = impl
      impl.ref = holder

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(holder)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Protocol-typed property holding class should form cycle")
    }

    // MARK: - Lazy var properties

    func testABITraversal_lazyVar_cycle() {
      let obj = PureSwiftWithLazyVar()
      let target = PureSwiftWithLazyVar()
      obj.lazyRef = target
      target.strongRef = obj

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(obj)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Lazy var holding object should form cycle")
    }

    // MARK: - Swift collections in pure Swift classes

    func testABITraversal_swiftArrayContainingCyclicRef() {
      let holder = PureSwiftWithSwiftArray()
      let target = PureSwift()
      holder.items.append(target)
      target.someObject = holder

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(holder)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Swift Array in pure Swift class should detect cycle")
    }

    func testABITraversal_swiftDictContainingCyclicRef() {
      let holder = PureSwiftWithSwiftDict()
      let target = PureSwift()
      holder.map["key"] = target
      target.someObject = holder

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(holder)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Swift Dictionary in pure Swift class should detect cycle")
    }

    // MARK: - Deep inheritance chain

    func testABITraversal_deepInheritanceChain_cycle() {
      // 4-level chain: A → B → C → D → A
      let a = PureSwiftDeepA()
      let b = PureSwiftDeepB()
      let c = PureSwiftDeepC()
      let d = PureSwiftDeepD()
      a.ref = b
      b.ref = c
      c.ref = d
      d.ref = a

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(a)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "4-node deep cycle should be detected")
    }

    // MARK: - Pure Swift superclass chain

    func testABITraversal_pureSwiftChild_cycleViaSuperclassField() {
      // Child holds target via inherited baseRef, target points back
      let child = PureSwiftChild()
      let target = PureSwift()
      child.baseRef = target  // field from superclass
      target.someObject = child

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(child)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Cycle through superclass field should be detected")
    }

    func testABITraversal_pureSwiftChild_cycleViaChildField() {
      // Child holds target via its own childRef, target points back
      let child = PureSwiftChild()
      let target = PureSwift()
      child.childRef = target  // field from subclass
      target.someObject = child

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(child)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Cycle through child's own field should be detected")
    }

    func testABITraversal_pureSwiftChild_bothLevelsHaveRefs() {
      // Both baseRef and childRef are set — should find both references
      let child = PureSwiftChild()
      child.baseRef = PureSwiftTarget()
      child.childRef = PureSwiftTarget()

      let references = FBGetObjectStrongReferences(child, nil, true, true)
      XCTAssertEqual(references.count, 2, "Should find refs from both superclass and subclass levels")
    }

    func testABITraversal_pureSwiftGrandchild_allLevelsHaveRefs() {
      // 3-level chain: grandchildRef + childRef + baseRef
      let gc = PureSwiftGrandchild()
      gc.baseRef = PureSwiftTarget()
      gc.childRef = PureSwiftTarget()
      gc.grandchildRef = PureSwiftTarget()

      let references = FBGetObjectStrongReferences(gc, nil, true, true)
      XCTAssertEqual(references.count, 3, "Should find refs from all 3 levels of inheritance")
    }

    func testABITraversal_pureSwiftGrandchild_cycleViaBaseField() {
      // Cycle through the grandparent's field
      let gc = PureSwiftGrandchild()
      let target = PureSwift()
      gc.baseRef = target  // field from grandparent
      target.someObject = gc

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(gc)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Cycle through grandparent's field should be detected")
    }

    // MARK: - Struct fields containing references

    func testABITraversal_structWithSingleRef_cycle() {
      let obj = PureSwiftWithStructField()
      let target = PureSwift()
      obj.myStruct.ref = target
      target.someObject = obj

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(obj)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Struct field containing class ref should form cycle")
    }

    func testABITraversal_structWithMixedFields_cycle() {
      let obj = PureSwiftWithMixedStruct()
      let target = PureSwift()
      obj.myStruct.ref = target
      target.someObject = obj

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(obj)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Struct with mixed value+ref fields should detect cycle through ref")
    }

    func testABITraversal_structWithMultipleRefs_returnsAll() {
      let obj = PureSwiftWithMultiRefStruct()
      obj.myStruct.ref1 = PureSwiftTarget()
      obj.myStruct.ref2 = PureSwiftTarget()

      let references = FBGetObjectStrongReferences(obj, nil, true, true)
      XCTAssertEqual(references.count, 2, "Struct with 2 class refs should return both")
    }

    func testABITraversal_nestedStruct_cycle() {
      let obj = PureSwiftWithNestedStruct()
      let target = PureSwift()
      obj.myStruct.inner.ref = target
      target.someObject = obj

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(obj)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 1, "Nested struct containing class ref should form cycle")
    }

    func testABITraversal_structWithWeakRef_noCycle() {
      let obj = PureSwiftWithWeakStruct()
      let target = PureSwift()
      obj.myStruct.ref = target
      target.someObject = obj

      let configuration = FBObjectGraphConfiguration(
        filterBlocks: [],
        shouldInspectTimers: false,
        transformerBlock: nil,
        shouldIncludeBlockAddress: true,
        shouldIncludeSwiftObjects: true,
        shouldUseSwiftABITraversal: true)

      let detector = FBRetainCycleDetector(configuration: configuration)
      detector.addCandidate(obj)
      let retainCycles = detector.findRetainCycles()
      XCTAssertEqual(retainCycles.count, 0, "Struct with only weak ref should not form cycle")
    }

    func testABITraversal_structAndDirectRef_bothDetected() {
      let obj = PureSwiftWithStructAndRef()
      let target1 = PureSwiftTarget()
      let target2 = PureSwiftTarget()
      obj.myStruct.ref = target1
      obj.directRef = target2

      let references = FBGetObjectStrongReferences(obj, nil, true, true)
      XCTAssertEqual(references.count, 2, "Both struct ref and direct ref should be detected")
    }

    // MARK: - TODO: Tests that need implementation work before they can pass
    //
    // Generic Swift types:
    //   class Box<T: AnyObject> { var value: T? }
    //   swift_getTypeByMangledNameInEnvironment returns NULL for generic type
    //   params without context. Need to pass generic arguments from the metadata.
    //
    // Nested closures (closure capturing closure capturing self):
    //   Capture scanning classifies inner closure as Function (kind 0x302) and
    //   skips it. Need to recursively traverse closure captures as graph elements.
    //
    // Swift closures bridged to ObjC blocks:
    //   Bridge wraps Swift context in ObjC block shell. FBRCD's block ABI parser
    //   sees the context pointer, not actual captures. Need to detect Swift
    //   contexts inside ObjC block captures and delegate to ABI traversal.
    //
    // Block-based NSTimer API:
    //   Timer.scheduledTimer(withTimeInterval:repeats:block:) uses different
    //   internals than the target/selector API. FBObjectiveCNSCFTimer doesn't
    //   handle it.
    //
    // Swift enum with associated reference values:
    //   fbClassifyTypeMetadata returns -1 for enums (kind 0x201). References
    //   inside associated values are not traversed. Need enum layout parsing.
    //
    //
    // Closures stored in Swift collections:
    //   Array enumerates via NSFastEnumeration, finds closure values, but they
    //   are thick functions — not ObjC blocks and not class instances. Need
    //   closure-as-graph-element support.

}
