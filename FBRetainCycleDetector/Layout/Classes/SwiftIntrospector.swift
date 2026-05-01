// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.
/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

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
        // Class instances are always safe to bridge to id.
        if Swift.type(of: value) is AnyClass {
            return value as AnyObject
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
        // Check _ObjectiveCBridgeable conformance via the bridged result's identity:
        // if bridging produces an object whose type is a class, it's safe.
        // We use a two-step check to avoid crashing on non-bridgeable types.
        if value is NSObject {
            return value as AnyObject
        }
        return nil
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
