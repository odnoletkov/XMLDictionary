import Foundation

@dynamicMemberLookup
public enum XMLNode {
    case string(_: String)
    case dictionary(_: NSDictionary)

    init(_ value: Any) throws {
        switch value {
        case let string as String:
            self = .string(string)
        case let dictionary as NSDictionary:
            self = .dictionary(dictionary)
        default:
            throw Error.unsupportedType(String(describing: type(of: value)))
        }
    }

    var denormalizedValue: NSDictionary {
        switch self {
        case .string(let string):
            return ["#text": string]
        case .dictionary(let dictionary):
            return dictionary
        }
    }
}

public extension XMLNode {
    init(data: Data) throws {
        self = .dictionary(try NSDictionary(XML: data))
    }

    var text: String {
        get throws {
            switch denormalizedValue["#text"] {
            case nil:
                return ""
            case let string as String:
                return string
            case let value?:
                throw Error.unsupportedType(String(describing: type(of: value)))
            }
        }
    }

    subscript(_ attribute: StaticString) -> String? {
        get throws {
            switch denormalizedValue["@" + attribute.description] {
            case nil:
                return nil
            case let string as String:
                return string
            case let value?:
                throw Error.unsupportedType(String(describing: type(of: value)))
            }
        }
    }

    func children(_ name: StaticString) throws -> [XMLNode] {
        switch denormalizedValue[name.description] {
        case let array as NSArray:
            return try array.map(XMLNode.init)
        case nil:
            return []
        case let value?:
            return [try XMLNode(value)]
        }
    }

    subscript(dynamicMember singleChildName: StaticString) -> XMLNode {
        get throws {
            let children = try children(singleChildName)
            switch children.count {
            case 0:
                throw Error.missingChild(singleChildName.description)
            case 1:
                return children[0]
            default:
                throw Error.multipleChildren(singleChildName.description)
            }
        }
    }

    enum Error: Swift.Error, Equatable {
        case missingChild(_: String)
        case multipleChildren(_: String)
        case unsupportedType(_: String)
    }
}

