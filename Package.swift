// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "XMLDictionary",
    products: [
        .library(
            name: "XMLDictionary",
            targets: ["XMLDictionary"]),
    ],
    targets: [
        .target(
            name: "XMLDictionary",
            dependencies: []),
        .testTarget(
            name: "XMLDictionaryTests",
            dependencies: ["XMLDictionary"]),
    ]
)
