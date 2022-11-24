import XCTest
import XMLDictionary

final class XMLNodeTests: XCTestCase {
    func test() throws {
        let root = try XMLNode(data:"""
        <root>
            <childWithText>foo</childWithText>
            <childWithoutText attr="value" />
            <child/>
            <child attr="value" />
            <child>text</child>
            <null/>
        </root>
        """.data(using: .utf8)!).root

        let nullNode = try root.null
        XCTAssertEqual(try nullNode.text, "")
        XCTAssertNil(try nullNode["attr"])
        XCTAssertEqual(try nullNode.children("child").count, 0)
        XCTAssertThrowsError(try nullNode.child) {
            XCTAssertEqual($0 as? XMLDictionary.XMLNode.Error, XMLDictionary.XMLNode.Error.missingChild("child"))
        }

        let textNode = try root.childWithText
        XCTAssertEqual(try textNode.text, "foo")
        XCTAssertNil(try textNode["attr"])
        XCTAssertEqual(try textNode.children("child").count, 0)
        XCTAssertThrowsError(try textNode.child) {
            XCTAssertEqual($0 as? XMLDictionary.XMLNode.Error, XMLDictionary.XMLNode.Error.missingChild("child"))
        }

        let dictionaryNode = try root.childWithoutText
        XCTAssertEqual(try dictionaryNode.text, "")
        XCTAssertEqual(try dictionaryNode["attr"], "value"); XCTAssertNil(try dictionaryNode["non-existent"])
        XCTAssertEqual(try dictionaryNode.children("child").count, 0)
        XCTAssertThrowsError(try dictionaryNode.child) {
            XCTAssertEqual($0 as? XMLDictionary.XMLNode.Error, XMLDictionary.XMLNode.Error.missingChild("child"))
        }

        XCTAssertEqual(try root.children("null").count, 1)
        XCTAssertEqual(try root.children("childWithText").count, 1)
        XCTAssertEqual(try root.children("childWithoutText").count, 1)
        XCTAssertEqual(try root.children("child").count, 3)
        XCTAssertEqual(try root.children("nonExistent").count, 0)

        XCTAssertThrowsError(try root.child) {
            XCTAssertEqual($0 as? XMLDictionary.XMLNode.Error, XMLDictionary.XMLNode.Error.multipleChildren("child"))
        }

        XCTAssertThrowsError(try XMLNode.dictionary(["root": 1]).root) {
            XCTAssertEqual($0 as? XMLDictionary.XMLNode.Error, XMLDictionary.XMLNode.Error.unsupportedType("__NSCFNumber"))
        }
        XCTAssertThrowsError(try XMLNode.dictionary(["#text": 1]).text) {
            XCTAssertEqual($0 as? XMLDictionary.XMLNode.Error, XMLDictionary.XMLNode.Error.unsupportedType("__NSCFNumber"))
        }
        XCTAssertThrowsError(try XMLNode.dictionary(["@attr": 1])["attr"]) {
            XCTAssertEqual($0 as? XMLDictionary.XMLNode.Error, XMLDictionary.XMLNode.Error.unsupportedType("__NSCFNumber"))
        }
    }
}
