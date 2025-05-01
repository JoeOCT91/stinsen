// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "Stinsen",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "Stinsen", targets: ["Stinsen"])
    ],
    targets: [
        .target(name: "Stinsen")
    ]
)
