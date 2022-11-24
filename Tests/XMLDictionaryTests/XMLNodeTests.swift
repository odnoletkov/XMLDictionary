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

        let root = try XMLNode(dict).root

        let nullNode = try root.null
        XCTAssertEqual(nullNode.text, "")
        XCTAssertNil(nullNode["attr"])
        XCTAssertEqual(try nullNode.children("child").count, 0)
        XCTAssertThrowsError(try nullNode.child) {
            XCTAssertEqual($0 as? XMLNode.Error, XMLNode.Error.missingChild("child"))
        }

        let textNode = try root.childWithText
        XCTAssertTrue(textNode.value is String)
        XCTAssertEqual(textNode.text, "foo")
        XCTAssertNil(textNode["attr"])
        XCTAssertEqual(try textNode.children("child").count, 0)
        XCTAssertThrowsError(try textNode.child) {
            XCTAssertEqual($0 as? XMLNode.Error, XMLNode.Error.missingChild("child"))
        }

        let dictionaryNode = try root.childWithoutText
        XCTAssertTrue(dictionaryNode.value is NSDictionary)
        XCTAssertEqual(dictionaryNode.text, "")
        XCTAssertEqual(dictionaryNode["attr"], "value"); XCTAssertNil(dictionaryNode["non-existent"])
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

        XCTAssertThrowsError(try XMLNode(["root": 1]).root) {
            XCTAssertEqual($0 as? XMLNode.Error, XMLNode.Error.unsupportedType("__NSCFNumber"))
        }
    }
}

@dynamicMemberLookup
struct XMLNode {

    /// String or NSDictionary
    let value: Any

    init(_ dictionary: NSDictionary) {
        self.value = dictionary
    }

    private init(_ value: Any) throws {
        switch value {
        case is String, is NSDictionary:
            self.value = value
        default:
            throw Error.unsupportedType(String(describing: type(of: value)))
        }
    }

    var denormalizedValue: NSDictionary {
        switch value {
        case let string as String:
            return ["#text": string]
        case let dictionary as NSDictionary:
            return dictionary
        default:
            preconditionFailure()
        }
    }

    var text: String {
        denormalizedValue["#text"] as! String? ?? ""
    }

    subscript(_ attribute: StaticString) -> String? {
        denormalizedValue["@" + attribute.description] as! String?
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
