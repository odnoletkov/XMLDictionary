import Foundation

extension NSMutableDictionary {
    public convenience init(XML data: Data) throws {
        self.init()
        let parser = XMLParser(data: data)
        let delegate = Delegate(root: self)
        parser.delegate = delegate
        guard parser.parse() else {
            throw delegate.abortError ?? parser.parserError!
        }
        precondition(delegate.stack.count == 1)
    }
}

extension NSDictionary {
    var normalized: Any {
        if count == 0 {
            return NSNull()
        } else if count == 1, let text = self["#text"] {
            return text
        } else {
            return self
        }
    }
}

extension XMLParser {
    enum DictionaryError: Error {
        case notSupportedSemiStructuredXML
    }
}

extension NSMutableDictionary {
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

        for (key, value) in self where value is NSArray {
            let children = (value as! [NSDictionary]).map(\.normalized)
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
    var stack: [NSMutableDictionary]

    var abortError: Error?

    init(root: NSMutableDictionary) {
        stack = [root]
    }

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
