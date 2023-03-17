import Foundation
import Combine

public extension NSDictionary {
    convenience init(XML data: Data) throws {
        self.init(dictionary: try XMLParser(data: data).parseDictionary())
    }
}

public extension XMLParser {
    func parseDictionary() throws -> NSMutableDictionary {
        let delegate = Delegate(parser: self)
        try delegate.parse()
        return delegate.node
    }

    enum DictionaryErrorCode: Int {
        case notSupportedSemiStructuredXML = 1000
    }

    var publisher: Publisher {
        .init(parser: self)
    }
}

extension XMLParser {
    public class Publisher: Combine.Publisher {
        public typealias Output = (path: String, element: XMLNode, mutableDocument: NSMutableDictionary)
        public typealias Failure = Error

        let delegate: Delegate

        init(parser: XMLParser) {
            self.delegate = .init(parser: parser)
        }

        public func receive(subscriber: some Subscriber<Output, Failure>) {

            delegate.subject
                .handleEvents(receiveCancel: delegate.parser.abortParsing)
                .receive(subscriber: subscriber)

            DispatchQueue.global().async(execute: delegate.complete)
        }
    }

    var stream: InputStream? {
        value(forKey: "xmlParserStream") as? InputStream
    }
}

extension NSMutableDictionary {
    var normalized: Any {
        if count == 0 {
            return ""
        } else if count == 1, let text = self["#text"] {
            return text
        } else {
            return self
        }
    }

    func normalize() throws {
        let texts = (self["#text"] as! [String]? ?? [])
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        self["#text"] = texts.isEmpty ? nil : texts.joined()

        let cdatas = self["#cdata"] as! [String]? ?? []
        switch (cdatas.count, texts.count) {
        case (0, _):
            break
        case (1, 0):
            self["#cdata"] = cdatas[0]
        default:
            throw NSError(dictionaryError: .notSupportedSemiStructuredXML)
        }

        for (key, value) in self where value is NSArray {
            if !texts.isEmpty {
                throw NSError(dictionaryError: .notSupportedSemiStructuredXML)
            }
            let children = (value as! [NSMutableDictionary]).map(\.normalized)
            self[key] = children.count == 1 ? children[0] : children
        }
    }

    func append(value: Any, forKey key: String) {
        if let existing = self[key] {
            (existing as! NSMutableArray).add(value)
        } else {
            self[key] = NSMutableArray(object: value)
        }
    }
}

class Delegate: NSObject {

    var stack: [NSMutableDictionary] = [[:]]
    var path: String = "/"

    var abortError: Error?

    let subject = PassthroughSubject<XMLParser.Publisher.Output, Error>()

    let parser: XMLParser

    init(parser: XMLParser) {
        self.parser = parser
        super.init()
        precondition(parser.delegate == nil)
        parser.delegate = self
    }

    var node: NSMutableDictionary {
        stack.last!
    }

    func parse() throws {
        guard parser.parse() else {
            let error = abortError ?? parser.parserError!
            throw (error as NSError).merging(userInfo: ["path": path])
        }
        precondition(stack.count == 1)
        precondition(path == "/")
    }

    func complete() {
        do {
            try parse()
            subject.send(completion: .finished)
        } catch {
            subject.send(completion: .failure(error))
        }
    }
}

extension Delegate: XMLParserDelegate {
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {

        let newNode = NSMutableDictionary(
            dictionary: Dictionary(
                uniqueKeysWithValues: attributeDict.map { ("@" + $0, $1) }
            )
        )

        node.append(value: newNode, forKey: elementName)

        stack.append(newNode)
        path = (path as NSString).appendingPathComponent(elementName)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        node.append(value: string, forKey: "#text")
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        parserDidEndDocument(parser)
        if abortError == nil {
            stack.removeLast()
            path = (path as NSString).deletingLastPathComponent
        }
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        do {
            try node.normalize()
            subject.send((path, XMLNode.dictionary(node), stack.first!))
        } catch {
            abortError = error
            parser.abortParsing()
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        if let stream = parser.stream, stream.streamStatus == .open {
            stream.close()
            assert(stream.streamStatus == .closed)
        }
    }
}

extension NSError {
    convenience init(dictionaryError code: XMLParser.DictionaryErrorCode) {
        self.init(
            domain: XMLParser.errorDomain,
            code: code.rawValue,
            userInfo: [NSLocalizedDescriptionKey: String(describing: code)]
        )
    }

    public func merging(userInfo: [String: Any]) -> NSError {
        .init(
            domain: domain,
            code: code,
            userInfo: self.userInfo.merging(userInfo) { $1 }
        )
    }
}

extension Error {
    public var identity: NSError {
        let error = self as NSError
        return .init(domain: error.domain, code: error.code)
    }
}
