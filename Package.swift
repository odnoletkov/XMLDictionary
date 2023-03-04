// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "XMLDictionary",
    platforms: [
        .iOS(.v13), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v6),
    ],
    products: [
        .library(
            name: "XMLDictionary",
            targets: ["XMLDictionary"]),
        .executable(
            name: "xmltodict",
            targets: ["xmltodict"])
    ],
    targets: [
        .target(
            name: "XMLDictionary"),
        .target(
            name: "xmltodict",
            dependencies: ["XMLDictionary"]),
        .testTarget(
            name: "XMLDictionaryTests",
            dependencies: ["XMLDictionary"],
            resources: [.copy("xml2json.samples.json")]),
    ]
)
