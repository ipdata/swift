// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "IPData",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(name: "IPData", targets: ["IPData"])
    ],
    targets: [
        .target(name: "IPData", path: "Sources/IPData"),
        .testTarget(name: "IPDataTests", dependencies: ["IPData"], path: "Tests/IPDataTests")
    ]
)
