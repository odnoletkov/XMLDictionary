import Foundation
import XMLDictionary

let data: Data
var args = ProcessInfo.processInfo.arguments.makeIterator()
switch (args.next(), args.next()) {
case (.some, nil), (.some, "-"):
    data = FileHandle.standardInput.readDataToEndOfFile()
case (.some, let path?):
    data = try Data(contentsOf: URL(fileURLWithPath: (path as NSString).expandingTildeInPath))
default:
    fatalError()
}

var options = JSONSerialization.WritingOptions.prettyPrinted
if #available(OSX 10.15, *) {
    options.insert(.withoutEscapingSlashes)
}

print(
    String(
        data: try JSONSerialization.data(
            withJSONObject: NSDictionary(XML: data),
            options: options
        ),
        encoding: .utf8
    )!
)
