// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import Foundation

@objc public class SwiftIntrospector: NSObject {

    /// Get list of properties, which incluses all Swift superclasses (recurive until we get to a Objective-c superclass)
    /// The Mirror framework doesn't tell us if a property is strong or weak, so we have to use something like `PropertyIntrospection`
    /// Maybe there is a way to use `@_silgen_name` to get non-recursive properties, so we don't need to do this.
    @objc public class func getPropertiesRecursive(objectClass:AnyClass) -> [PropertyIntrospection] {
        let introspection = TypeIntrospection(rawValue: objectClass)
        var properties:[PropertyIntrospection] = []
        for property in introspection.properties {
            properties.append(property)
        }
        return properties
    }

    /// Get the value of the property
    @objc public class func getPropertyValue(object:Any, name:String) -> Any? {
            let mirror = Mirror(reflecting: object)
            guard let array = AnyBidirectionalCollection(mirror.children) else {
                return nil
            }

            for child in array  {
                if let label = child.label, label == name {
                    return child.value
                }
            }
        return nil
     }

}
