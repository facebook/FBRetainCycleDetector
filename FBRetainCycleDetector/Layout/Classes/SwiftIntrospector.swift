// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.
/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Darwin
import Foundation

@objc public class SwiftIntrospector: NSObject {

    /// Get list of properties, which incluses all Swift superclasses (recurive until we get to a Objective-c superclass)
    /// The Mirror framework doesn't tell us if a property is strong or weak, so we have to use something like `PropertyIntrospection`
    /// Maybe there is a way to use `@_silgen_name` to get non-recursive properties, so we don't need to do this.
    @objc public class func getPropertiesRecursive(object:Any) -> [PropertyIntrospection] {
        let typeObj = type(of: object)
        let introspection = TypeIntrospection(rawValue: typeObj)
        var properties:[PropertyIntrospection] = []
        for property in introspection.properties {
            properties.append(property)
        }
        return properties
    }

    /// Get the value of the property.
    /// Filters out pure value types that cannot form retain cycles and
    /// may crash when bridged to ObjC id (EXC_BREAKPOINT in swift_dynamicCast).
    @objc public class func getPropertyValue(object:Any, name:String) -> AnyObject? {
        let mirror = Mirror(reflecting: object)
        var currentMirror: Mirror? = mirror
        while currentMirror != nil {
            let (value, found) = getChild(mirror: currentMirror!, name: name)
            if found {
                guard let value else { return nil }
                return asRetainableObject(value)
            } else {
                currentMirror = currentMirror?.superclassMirror
            }
        }
        return nil
     }

    private class func asRetainableObject(_ value: Any) -> AnyObject? {
        // Class instances are safe to bridge to id, but we must verify the
        // pointer is still live. Mirror can return stale pointers for
        // unowned references whose target was deallocated. Bridging a
        // dangling pointer back to ObjC id triggers swift_unknownObjectRetain
        // crashes during the @objc return-value retain.
        if Swift.type(of: value) is AnyClass {
            let obj = value as AnyObject
            return isLikelyLiveObject(obj) ? obj : nil
        }
        // Optional wrapping a class instance — unwrap and check.
        let valueMirror = Mirror(reflecting: value)
        if valueMirror.displayStyle == .optional {
            if let child = valueMirror.children.first {
                return asRetainableObject(child.value)
            }
            return nil
        }
        // Foundation-bridgeable value types (String→NSString, Array→NSArray, etc.)
        // are safe. Non-bridgeable Swift structs/enums will crash on `as AnyObject`.
        if value is NSObject {
            let obj = value as AnyObject
            return isLikelyLiveObject(obj) ? obj : nil
        }
        return nil
    }

    /// Verify the object's pointer is still in a live heap allocation.
    /// Tagged pointers (small NSNumber, short NSString) are not heap-allocated
    /// and pass through unchanged.
    private class func isLikelyLiveObject(_ obj: AnyObject) -> Bool {
        let raw = Unmanaged.passUnretained(obj).toOpaque()
        let intPtr = Int(bitPattern: raw)
        // Tagged pointers: high bit set on arm64, low bit on x86_64.
        // These are not heap allocations — accept them.
        #if arch(arm64) || arch(arm64_32)
        if intPtr < 0 { return true }
        #else
        if (intPtr & 1) != 0 { return true }
        #endif
        // Heap-allocated pointers must have a non-zero malloc size.
        return malloc_size(raw) > 0
    }

    private class func getChild(mirror: Mirror, name: String) -> (Any?, Bool) {
        guard let array = AnyBidirectionalCollection(mirror.children) else {
            return (nil, false)
        }

        for child in array {
            if let label = child.label, label == name {
                return (child.value, true)
            }
        }
        return (nil, false)
    }
}
