import XCTest
import Foundation
import libxml2
@testable import XMLDictionary

final class XMLDictionaryTests: XCTestCase {

    func testExample() {
        XCTAssertEqual(
            try NSDictionary(XML: "<xml/>".data(using: .utf8)!),
            ["xml": ""]
        )
    }

    func testError() {
        XCTAssertThrowsError(try NSDictionary(XML: "xml".data(using: .utf8)!), "") {
            XCTAssertEqual(
                ($0 as NSError).identity,
                NSError(domain: XMLParser.errorDomain, code: XMLParser.ErrorCode.internalError.rawValue)
            )
        }
    }

    func testErrorPath() {
        XCTAssertThrowsError(try NSDictionary(XML: "<a><b a=\"1\"><c/><d></b></a>".data(using: .utf8)!), "") {
            XCTAssertEqual(
                $0 as NSError,
                NSError(domain: XMLParser.errorDomain, code: Int(XML_ERR_USER_STOP.rawValue))
                    .merging(userInfo: ["path": ["a", "b", "d"]])
            )
        }

        XCTAssertThrowsError(try NSDictionary(XML: "<a><b/><b>text<c/>text</b></a>".data(using: .utf8)!), "") {
            XCTAssertEqual(
                $0 as NSError,
                NSError(dictionaryError: .notSupportedSemiStructuredXML)
                    .merging(userInfo: ["path": ["a", "b"]])
            )
        }

        XCTAssertThrowsError(try NSDictionary(XML: "a".data(using: .utf8)!), "") {
            XCTAssertEqual(
                $0 as NSError,
                NSError(domain: XMLParser.errorDomain, code: Int(XML_ERR_INTERNAL_ERROR.rawValue))
                    .merging(userInfo: ["path": []])
            )
        }

        XCTAssertThrowsError(try NSDictionary(XML: "<a>3".data(using: .utf8)!), "") {
            XCTAssertEqual(
                $0 as NSError,
                NSError(domain: XMLParser.errorDomain, code: Int(XML_ERR_USER_STOP.rawValue))
                    .merging(userInfo: ["path": ["a"]])
            )
        }
    }

    func testDash() {
        XCTAssertNoThrow(try NSDictionary(XML: "<a>1–</a>".data(using: .utf8)!))
    }

    /// Source: https://goessner.net/download/prj/jsonxml/xmljson_test.html
    func testOriginalFixtures() throws {
        struct Sample: Decodable {
            let includesCDATA: Bool?
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

            guard sample.includesCDATA != true else {
                continue
            }

            guard sample.semistructured != true else {
                XCTAssertThrowsError(try NSDictionary(XML: sample.xmlData), sample.xml) {
                    XCTAssertEqual(
                        ($0 as NSError).identity,
                        NSError(dictionaryError: .notSupportedSemiStructuredXML).identity
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
