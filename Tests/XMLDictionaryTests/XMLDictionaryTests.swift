import XCTest
import Foundation
@testable import XMLDictionary

final class XMLDictionaryTests: XCTestCase {

    func testExample() throws {
        XCTAssertEqual(
            try NSDictionary(XML: "<xml/>".data(using: .utf8)!),
            ["xml": NSNull()]
        )
    }

    func testError() throws {
        XCTAssertThrowsError(try NSDictionary(XML: "xml".data(using: .utf8)!), "") {
            XCTAssertEqual($0 as NSError, NSError(domain: XMLParser.errorDomain, code: XMLParser.ErrorCode.internalError.rawValue))
        }
    }

    func testErrorPath() throws {
        XCTAssertThrowsError(try NSDictionary(XML: "<a><b/><b>text<c/>text</b></a>".data(using: .utf8)!), "") {
            XCTAssertEqual(
                $0 as NSError,
                NSError(dictionaryError: .notSupportedSemiStructuredXML)
                    .merging(userInfo: ["path": ["a", "b"]])
            )
        }
    }

    func testDash() throws {
        XCTAssertNoThrow(try NSDictionary(XML: "<a>1–</a>".data(using: .utf8)!))
    }

    /// Source: https://goessner.net/download/prj/jsonxml/xmljson_test.html
    func testOriginalFixtures() throws {
        struct Sample: Decodable {
            let semistructured: Bool?
            let xml: String
            let json: String

            var xmlData: Data { xml.data(using: .utf8)! }
        }
        let samples = try JSONDecoder().decode(
            [Sample].self,
            from: Data(contentsOf: Bundle.module.url(forResource: "xml2json.samples", withExtension: "json")!)
        )

        for sample in samples {

            guard sample.semistructured != true else {
                XCTAssertThrowsError(try NSDictionary(XML: sample.xmlData), "") {
                    XCTAssertEqual(
                        $0 as NSError,
                        NSError(dictionaryError: .notSupportedSemiStructuredXML)
                            .merging(userInfo: ($0 as NSError).userInfo)
                    )
                }
                continue
            }

            XCTAssertEqual(
                try NSDictionary(XML: sample.xmlData),
                try JSONSerialization.jsonObject(with: sample.json.data(using: .utf8)!) as! NSDictionary,
                sample.xml
            )
        }
    }

}
