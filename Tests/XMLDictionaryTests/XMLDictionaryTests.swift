import XCTest
@testable import XMLDictionary

final class XMLDictionaryTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(XMLDictionary().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
