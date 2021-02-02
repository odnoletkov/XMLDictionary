import Foundation

extension NSMutableDictionary {
    public convenience init(XML data: Data) throws {
        self.init()
        let parser = XMLParser(data: data)
        let delegate = Delegate(root: self)
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError!
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

extension NSMutableDictionary {
    func normalize() {
        let text = (self["#text"] as! NSArray? ?? [])
            .componentsJoined(by: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self["#text"] = text.isEmpty ? nil : text

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
        stack.last!.normalize()
        stack.removeLast()
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        stack.last!.normalize()
    }
}
