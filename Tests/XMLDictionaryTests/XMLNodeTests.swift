import XCTest

final class XMLNodeTests: XCTestCase {

    func test() throws {
        let dict = try NSDictionary(XML: """
            <root>
                <childWithText>foo</childWithText>
                <childWithoutText attr="value" />
                <child/>
                <child attr="value" />
                <child>text</child>
                <null/>
            </root>
            """.data(using: .utf8)!
        )

        let root = try XMLNode.dictionary(dict).root

        let nullNode = try root.null
        XCTAssertEqual(try nullNode.text, "")
        XCTAssertNil(try nullNode["attr"])
        XCTAssertEqual(try nullNode.children("child").count, 0)
        XCTAssertThrowsError(try nullNode.child) {
            XCTAssertEqual($0 as? XMLNode.Error, XMLNode.Error.missingChild("child"))
        }

        let textNode = try root.childWithText
        XCTAssertEqual(try textNode.text, "foo")
        XCTAssertNil(try textNode["attr"])
        XCTAssertEqual(try textNode.children("child").count, 0)
        XCTAssertThrowsError(try textNode.child) {
            XCTAssertEqual($0 as? XMLNode.Error, XMLNode.Error.missingChild("child"))
        }

        let dictionaryNode = try root.childWithoutText
        XCTAssertEqual(try dictionaryNode.text, "")
        XCTAssertEqual(try dictionaryNode["attr"], "value"); XCTAssertNil(try dictionaryNode["non-existent"])
        XCTAssertEqual(try dictionaryNode.children("child").count, 0)
        XCTAssertThrowsError(try dictionaryNode.child) {
            XCTAssertEqual($0 as? XMLNode.Error, XMLNode.Error.missingChild("child"))
        }

        XCTAssertEqual(try root.children("null").count, 1)
        XCTAssertEqual(try root.children("childWithText").count, 1)
        XCTAssertEqual(try root.children("childWithoutText").count, 1)
        XCTAssertEqual(try root.children("child").count, 3)
        XCTAssertEqual(try root.children("nonExistent").count, 0)

        XCTAssertThrowsError(try root.child) {
            XCTAssertEqual($0 as? XMLNode.Error, XMLNode.Error.multipleChildren("child"))
        }

        XCTAssertThrowsError(try XMLNode.dictionary(["root": 1]).root) {
            XCTAssertEqual($0 as? XMLNode.Error, XMLNode.Error.unsupportedType("__NSCFNumber"))
        }
        XCTAssertThrowsError(try XMLNode.dictionary(["#text": 1]).text) {
            XCTAssertEqual($0 as? XMLNode.Error, XMLNode.Error.unsupportedType("__NSCFNumber"))
        }
        XCTAssertThrowsError(try XMLNode.dictionary(["@attr": 1])["attr"]) {
            XCTAssertEqual($0 as? XMLNode.Error, XMLNode.Error.unsupportedType("__NSCFNumber"))
        }
    }
}

@dynamicMemberLookup
enum XMLNode {
    case string(_: String)
    case dictionary(_: NSDictionary)

    private init(_ value: Any) throws {
        switch value {
        case let string as String:
            self = .string(string)
        case let dictionary as NSDictionary:
            self = .dictionary(dictionary)
        default:
            throw Error.unsupportedType(String(describing: type(of: value)))
        }
    }

    private var denormalizedValue: NSDictionary {
        switch self {
        case .string(let string):
            return ["#text": string]
        case .dictionary(let dictionary):
            return dictionary
        }
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
