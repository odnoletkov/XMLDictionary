import Foundation
import XMLDictionary

precondition(ProcessInfo.processInfo.arguments.count == 2)

var options = JSONSerialization.WritingOptions.prettyPrinted
if #available(OSX 10.13, *) {
    options.insert(.prettyPrinted)
}
if #available(OSX 10.15, *) {
    options.insert(.withoutEscapingSlashes)
}

print(
    String(
        data: try JSONSerialization.data(
            withJSONObject: NSDictionary(
                XML: Data(
                    contentsOf: URL(
                        fileURLWithPath: (ProcessInfo.processInfo.arguments[1] as NSString).expandingTildeInPath
                    )
                )
            ),
            options: options
        ),
        encoding: .utf8
    )!
)
