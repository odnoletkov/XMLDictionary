import XCTest
import Foundation
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

    /// Source: https://goessner.net/download/prj/jsonxml/xmljson_test.html
    func testOriginalFixtures() throws {
        struct Sample: Decodable {
            let fails: Bool?
            let xml: String
            let json: String
        }
        let samples = try JSONDecoder().decode(
            [Sample].self,
            from: Data(contentsOf: Bundle.module.url(forResource: "xml2json.samples", withExtension: "json")!)
        )
        for sample in samples where sample.fails != true {
            XCTAssertEqual(
                try NSMutableDictionary(XML: sample.xml.data(using: .utf8)!),
                try JSONSerialization.jsonObject(with: sample.json.data(using: .utf8)!) as! NSDictionary,
                sample.xml
            )
        }
    }

}
