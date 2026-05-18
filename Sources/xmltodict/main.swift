import Foundation
import XMLDictionary

let data: Data
var args = ProcessInfo.processInfo.arguments.makeIterator()
switch (args.next(), args.next(), args.next()) {
case (.some, nil, nil), (.some, "-", nil):
    data = FileHandle.standardInput.readDataToEndOfFile()
case (.some, let path?, nil):
    data = try Data(contentsOf: URL(fileURLWithPath: (path as NSString).expandingTildeInPath))
default:
    fatalError("usage: xmltodict [path|-]")
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
