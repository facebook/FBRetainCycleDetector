// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

// From https://github.com/gor-gyolchanyan-swift/introspection-kit

@objc public class PropertyIntrospection: NSObject {

    // MARK: PropertyIntrospection

    init(id: ID) {
        self.id = id
        var rawConfiguration: _RawConfiguration = (
            _rawName: nil,
            _rawNameRelease: nil,
            _isStrong: false
        )
        let maybeType = Self._rawType(
            _in: id.instanceType.rawValue,
            _at: id.index,
            _configuration: &rawConfiguration
        )
        guard let type = maybeType else {
            preconditionFailure("execution has reached a routine that is not supposed to be reachable")
        }
        self.valueType = TypeIntrospection(rawValue: type)
        let maybeName = rawConfiguration._rawName.map(String.init(cString:))
        guard let name = maybeName else {
            preconditionFailure("execution has reached a routine that is not supposed to be reachable")
        }
        self.name = name
        rawConfiguration._rawNameRelease?(rawConfiguration._rawName)
        self.offset = Self._rawOffset(_in: id.instanceType.rawValue, _at: id.index)
        self.isStrong = rawConfiguration._isStrong
        super.init()
    }

    @objc public let name: String

    let valueType: TypeIntrospection

    @objc public let offset: Int

    @objc public let isStrong: Bool

    // MARK: Identifiable

    let id: ID
}

extension PropertyIntrospection {

    // MARK: PropertyIntrospection - Raw

    private typealias _RawName = UnsafePointer<CChar>

    private typealias _RawNameRelease = @convention(c) (_RawName?) -> Void

    private typealias _RawConfiguration = (_rawName: _RawName?, _rawNameRelease: _RawNameRelease?, _isStrong: Bool)

    @_silgen_name("swift_reflectionMirror_recursiveChildMetadata")
    private static func _rawType(_in enclosingType: Any.Type, _at index: Int, _configuration: UnsafeMutablePointer<_RawConfiguration>) -> Any.Type?

    @_silgen_name("swift_reflectionMirror_recursiveChildOffset")
    private static func _rawOffset(_in enclosingType: Any.Type, _at index: Int) -> Int
}

extension PropertyIntrospection {

    // MARK: PropertyIntrospection - ID

    struct ID: Hashable {

        // MARK: PropertyIntrospection.ID

        init?(
            in instanceType: TypeIntrospection,
            at index: Int
        ) {
            guard instanceType.properties.indices.contains(index) else {
                return nil
            }
            self.instanceType = instanceType
            self.index = index
        }

        let instanceType: TypeIntrospection

        let index: Int
    }
}


struct TypeIntrospection: RawRepresentable {

    // MARK: RawRepresentable

    typealias RawValue = Any.Type

    init(rawValue: RawValue) {
        self.rawValue = rawValue
    }

    let rawValue: RawValue
}


extension TypeIntrospection: Hashable {

    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(rawValue))
    }
}


extension TypeIntrospection.Properties: Collection {

    // MARK: Collection

    var count: Int {
        Self._rawPropertyCount(_in: instanceType.rawValue)
    }

    // MARK: Collection - Index

    typealias Index = Int

    var startIndex: Index {
        return .zero
    }

    var endIndex: Index {
        return count
    }

    func index(after anotherIndex: Index) -> Index {
        return anotherIndex + 1
    }

    func index(_ anotherIndex: Index, offsetBy distance: Int) -> Index {
        return anotherIndex + distance
    }

    func index(_ anotherIndex: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        let resultingIndex = index(anotherIndex, offsetBy: distance)
        guard resultingIndex < limit else {
            return nil
        }
        return resultingIndex
    }

    // MARK: Collection - Element

    subscript(_ index: Index) -> Element {
        guard let propertyID = PropertyIntrospection.ID(in: instanceType, at: index) else {
            preconditionFailure("property index is out of range")
        }
        return PropertyIntrospection(id: propertyID)
    }
}

extension TypeIntrospection.Properties {

    // MARK: TypeIntrospection.Properties - Raw

    @_silgen_name("swift_reflectionMirror_recursiveCount")
    private static func _rawPropertyCount(_in type: Any.Type) -> Int

}

extension TypeIntrospection.Properties: RandomAccessCollection {

    // MARK: RandomAccessCollection

    // This scope is intentionally left blank.
}


extension TypeIntrospection {

    // MARK: TypeIntrospection - Properties

    struct Properties {

        // MARK: TypeIntrospection.Properties

        internal init(in instanceType: TypeIntrospection) {
            self.instanceType = instanceType
        }

        internal let instanceType: TypeIntrospection
    }
}



extension TypeIntrospection.Properties: BidirectionalCollection {

    // MARK: BidirectionalCollection - Index

    func index(before anotherIndex: Index) -> Index {
        return anotherIndex - 1
    }
}

extension TypeIntrospection.Properties: Equatable {

    // MARK: Equatable

    static func == (_ some: Self, _ other: Self) -> Bool {
        return some.lazy.map(\.id) == other.lazy.map(\.id)
    }
}

extension TypeIntrospection.Properties: Sequence {

    // MARK: Sequence - Element

    typealias Element = PropertyIntrospection
}

extension TypeIntrospection: Equatable {

    // MARK: Equatable

    static func == (_ some: Self, _ other: Self) -> Bool {
        ObjectIdentifier(some.rawValue) == ObjectIdentifier(other.rawValue)
    }
}

extension TypeIntrospection {

    // MARK: TypeIntrospection - Properties

    var properties: Properties {
        Properties(in: self)
    }
}
