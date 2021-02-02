import XCTest
@testable import XMLDictionary

final class XMLDictionaryTests: XCTestCase {

    func testExample() throws {
        XCTAssertEqual(
            try NSMutableDictionary(XML: "<xml/>".data(using: .utf8)!),
            ["xml": NSNull()]
        )
    }

    func testError() throws {
        XCTAssertThrowsError(try NSMutableDictionary(XML: "xml".data(using: .utf8)!), "") {
            XCTAssertEqual($0 as NSError, NSError(domain: XMLParser.errorDomain, code: XMLParser.ErrorCode.internalError.rawValue))
        }
    }

}
