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
            throw delegate.abortError ?? parserError!
        }
        precondition(delegate.stack.count == 1)
        return delegate.stack.last!
    }

    enum DictionaryError: Error {
        case notSupportedSemiStructuredXML
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
            throw XMLParser.DictionaryError.notSupportedSemiStructuredXML
        }

        let cdatas = self["#cdata"] as! [String]? ?? []
        switch cdatas.count {
        case 0:
            break
        case 1:
            self["#cdata"] = cdatas[0]
        default:
            throw XMLParser.DictionaryError.notSupportedSemiStructuredXML
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

    var abortError: Error?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {

        let node = NSMutableDictionary(
            dictionary: Dictionary(
                uniqueKeysWithValues: attributeDict.map { ("@" + $0, $1) }
            )
        )

        stack.last!.append(value: node, forKey: elementName)

        stack.append(node)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last!.append(value: string, forKey: "#text")
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        stack.last!.append(value: String(data: CDATABlock, encoding: .utf8)!, forKey: "#cdata")
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        do {
            try stack.last!.normalize()
        } catch {
            abortError = error
            parser.abortParsing()
        }
        stack.removeLast()
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        do {
            try stack.last!.normalize()
        } catch {
            abortError = error
            parser.abortParsing()
        }
    }
}
