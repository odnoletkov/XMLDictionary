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
            return NSNull()
        } else if count == 1, let text = self["#text"] {
            return text
        } else {
            return self
        }
    }

    func normalize() throws {
        let texts = (self["#text"] as! [String]? ?? [])
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        switch texts.count {
        case 0:
            self["#text"] = nil
        case 1:
            self["#text"] = texts[0]
        default:
            throw NSError(dictionaryError: .notSupportedSemiStructuredXML)
        }

        let cdatas = self["#cdata"] as! [String]? ?? []
        switch cdatas.count {
        case 0:
            break
        case 1:
            self["#cdata"] = cdatas[0]
        default:
            throw NSError(dictionaryError: .notSupportedSemiStructuredXML)
        }

        for (key, value) in self where value is NSArray {
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
    var stack = [NSMutableDictionary()]

    var node: NSMutableDictionary { stack.last! }

    var abortError: Error?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {

        let newNode = NSMutableDictionary(
            dictionary: Dictionary(
                uniqueKeysWithValues: attributeDict.map { ("@" + $0, $1) }
            )
        )

        node.append(value: newNode, forKey: elementName)

        stack.append(newNode)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        node.append(value: string, forKey: "#text")
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        node.append(value: String(data: CDATABlock, encoding: .utf8)!, forKey: "#cdata")
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
        zip(stack.reversed(), stack.reversed().dropFirst())
            .map { child, parent in
                parent
                    .first { ($1 as? [AnyObject])?.contains { $0 === child } == true }!
                    .key as! String
            }
            .reversed()
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
