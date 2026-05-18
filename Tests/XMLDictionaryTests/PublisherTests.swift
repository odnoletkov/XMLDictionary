import XCTest
import Foundation
import Combine
@testable import XMLDictionary

final class XMLParserPublisherTests: XCTestCase {
    func testPublisher() throws {
        let expectation = self.expectation(description: "publisher completes")
        let parser = XMLParser(data: "<root><a>1</a><b>2</b></root>".data(using: .utf8)!)
        var outputs: [XMLParser.Publisher.Output] = []

        let cancellable = parser.publisher.sink(
            receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    XCTFail(String(describing: error))
                }
                expectation.fulfill()
            },
            receiveValue: {
                outputs.append($0)
            }
        )

        waitForExpectations(timeout: 1)
        cancellable.cancel()

        XCTAssertEqual(outputs.map(\.path), ["/root/a", "/root/b", "/root", "/"])
        XCTAssertEqual(try outputs[0].element.text, "1")
        XCTAssertEqual(try outputs[1].element.text, "2")
        XCTAssertEqual(try outputs[2].element.a.text, "1")
        XCTAssertEqual(try outputs[2].element.b.text, "2")
        XCTAssertEqual(try outputs[3].element.root.a.text, "1")
        XCTAssertEqual(try outputs[3].element.root.b.text, "2")
    }

    func testPublisherError() {
        let expectation = self.expectation(description: "publisher fails")
        let parser = XMLParser(data: "<a><b/><b>text<c/>text</b></a>".data(using: .utf8)!)
        var values = 0

        let cancellable = parser.publisher.sink(
            receiveCompletion: { completion in
                guard case let .failure(error) = completion else {
                    XCTFail(String(describing: completion))
                    expectation.fulfill()
                    return
                }

                XCTAssertEqual(
                    error as NSError,
                    NSError(dictionaryError: .notSupportedSemiStructuredXML)
                        .merging(userInfo: ["path": "/a/b"])
                )
                expectation.fulfill()
            },
            receiveValue: { _ in
                values += 1
            }
        )

        waitForExpectations(timeout: 1)
        cancellable.cancel()

        XCTAssertEqual(values, 2)
    }
}
