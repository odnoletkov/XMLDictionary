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
        XCTAssertEqual(nullNode.children("child").count, 0)
        XCTAssertThrowsError(try nullNode.child) {
            XCTAssertEqual($0 as? XMLNode.Error, XMLNode.Error.missingChild("child"))
        }

        let textNode = try root.childWithText
        XCTAssertTrue(textNode.value is String)
        XCTAssertEqual(textNode.text, "foo")
        XCTAssertNil(textNode["attr"])
        XCTAssertEqual(textNode.children("child").count, 0)
        XCTAssertThrowsError(try textNode.child) {
            XCTAssertEqual($0 as? XMLNode.Error, XMLNode.Error.missingChild("child"))
        }

        let dictionaryNode = try root.childWithoutText
        XCTAssertTrue(dictionaryNode.value is NSDictionary)
        XCTAssertEqual(dictionaryNode.text, "")
        XCTAssertEqual(dictionaryNode["attr"], "value"); XCTAssertNil(dictionaryNode["non-existent"])
        XCTAssertEqual(dictionaryNode.children("child").count, 0)
        XCTAssertThrowsError(try dictionaryNode.child) {
            XCTAssertEqual($0 as? XMLNode.Error, XMLNode.Error.missingChild("child"))
        }

        XCTAssertEqual(root.children("null").count, 1)
        XCTAssertEqual(root.children("childWithText").count, 1)
        XCTAssertEqual(root.children("childWithoutText").count, 1)
        XCTAssertEqual(root.children("child").count, 3)
        XCTAssertEqual(root.children("nonExistent").count, 0)

        XCTAssertThrowsError(try root.child) {
            XCTAssertEqual($0 as? XMLNode.Error, XMLNode.Error.multipleChildren("child"))
        }
    }
}

//@dynamicMemberLookup
//protocol Test: Equatable {
//    subscript(dynamicMember singleChildName: StaticString) -> any Test { get }
//}

@dynamicMemberLookup
struct XMLNode {

    /// String or NSDictionary
    let value: Any

    init(_ string: String) {
        self.value = string
    }

    init(_ dictionary: NSDictionary) {
        self.value = dictionary
    }

    private init(_ value: Any) {
        precondition(value is String || value is NSDictionary)
        self.value = value
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

    func children(_ name: StaticString) -> [XMLNode] {
        switch denormalizedValue[name.description] {
        case let array as NSArray:
            return array.map(XMLNode.init)
        case nil:
            return []
        case let value?:
            return [XMLNode(value)]
        }
    }

    subscript(dynamicMember singleChildName: StaticString) -> XMLNode {
        get throws {
            let children = children(singleChildName)
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
        case missingChild(_ name: String)
        case multipleChildren(_ name: String)
    }
}
