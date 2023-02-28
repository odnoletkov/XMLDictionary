import Foundation

public extension NSDictionary {
    convenience init(XML data: Data) throws {
        self.init(dictionary: try XMLParser(data: data).parseDictionary())
    }
}

public extension XMLParser {
    func parseDictionary() throws -> NSMutableDictionary {
        precondition(delegate == nil)
        let delegate = Delegate()
        self.delegate = delegate
        guard parse() else {
            let error = delegate.abortError ?? parserError!
            throw (error as NSError).merging(userInfo: ["path": delegate.currentPath])
        }
        precondition(delegate.stack.count == 1)
        return delegate.node
    }

    enum DictionaryErrorCode: Int {
        case notSupportedSemiStructuredXML = 1000
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

class Delegate: NSObject, XMLParserDelegate {
    var stack: [(name: String, node: NSMutableDictionary)] = [("", [:])]

    var node: NSMutableDictionary { stack.last!.node }

    var abortError: Error?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {

        let newNode = NSMutableDictionary(
            dictionary: Dictionary(
                uniqueKeysWithValues: attributeDict.map { ("@" + $0, $1) }
            )
        )

        node.append(value: newNode, forKey: elementName)

        stack.append((elementName, newNode))
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        node.append(value: string, forKey: "#text")
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        parserDidEndDocument(parser)
        if abortError == nil {
            stack.removeLast()
        }
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        do {
            try node.normalize()
        } catch {
            abortError = error
            parser.abortParsing()
        }
    }

    var currentPath: [String] {
        stack[1...].map(\.name)
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

    func merging(userInfo: [String: Any]) -> NSError {
        .init(
            domain: domain,
            code: code,
            userInfo: self.userInfo.merging(userInfo) { $1 }
        )
    }

    var identity: NSError {
        .init(domain: domain, code: code)
    }
}
