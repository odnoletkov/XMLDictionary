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

        let root = try XML(dict).root

        let nullNode = try root.null
        XCTAssertEqual(nullNode.text, "")
        XCTAssertNil(nullNode["attr"])
        XCTAssertEqual(nullNode.children("child").count, 0)
        XCTAssertThrowsError(try nullNode.child) {
            XCTAssertEqual($0 as? Error, Error.missingChild("child"))
        }

        let textNode = try root.childWithText
        XCTAssertTrue(textNode is XMLStringNode)
        XCTAssertEqual(textNode.text, "foo")
        XCTAssertNil(textNode["attr"])
        XCTAssertEqual(textNode.children("child").count, 0)
        XCTAssertThrowsError(try textNode.child) {
            XCTAssertEqual($0 as? Error, Error.missingChild("child"))
        }

        let dictionaryNode = try root.childWithoutText
        XCTAssertTrue(dictionaryNode is XMLDictionaryNode)
        XCTAssertEqual(dictionaryNode.text, "")
        XCTAssertEqual(dictionaryNode["attr"], "value"); XCTAssertNil(dictionaryNode["non-existent"])
        XCTAssertEqual(dictionaryNode.children("child").count, 0)
        XCTAssertThrowsError(try dictionaryNode.child) {
            XCTAssertEqual($0 as? Error, Error.missingChild("child"))
        }

        XCTAssertEqual(root.children("null").count, 1)
        XCTAssertEqual(root.children("childWithText").count, 1)
        XCTAssertEqual(root.children("childWithoutText").count, 1)
        XCTAssertEqual(root.children("child").count, 3)
        XCTAssertEqual(root.children("nonExistent").count, 0)

        XCTAssertThrowsError(try root.child) {
            XCTAssertEqual($0 as? Error, Error.multipleChildren("child"))
        }
    }
}

@dynamicMemberLookup
protocol XMLNode {
    var denormalizedValue: NSDictionary { get }
}

extension XMLNode {
    var text: String {
        denormalizedValue["#text"] as! String? ?? ""
    }

    subscript(_ attribute: StaticString) -> String? {
        denormalizedValue["@" + attribute.description] as! String?
    }

    func children(_ name: StaticString) -> [XMLNode] {
        switch denormalizedValue[name.description] {
        case let array as NSArray:
            return array.map(XML)
        case nil:
            return []
        case let value?:
            return [XML(value)]
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
}

enum Error: Swift.Error, Equatable {
    case missingChild(_ name: String)
    case multipleChildren(_ name: String)
}

struct XMLStringNode: XMLNode {
    let value: String
    var denormalizedValue: NSDictionary {
        ["#text": value]
    }
}

struct XMLDictionaryNode: XMLNode {
    let value: NSDictionary
    var denormalizedValue: NSDictionary {
        value
    }
}

func XML(_ value: Any) -> XMLNode {
    switch value {
    case let string as String:
        return XMLStringNode(value: string)
    case let dictionary as NSDictionary:
        return XMLDictionaryNode(value: dictionary)
    default:
        preconditionFailure()
    }
}
