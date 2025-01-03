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

    /// Get the value of the property
    @objc public class func getPropertyValue(object:Any, name:String) -> Any? {
        let mirror = Mirror(reflecting: object)
        var currentMirror: Mirror? = mirror
        while currentMirror != nil {
            let (value, found) = getChild(mirror: currentMirror!, name: name)
            if found {
                return value
            } else {
                // Check parent mirror if present
                currentMirror = currentMirror?.superclassMirror
            }
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
