// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Mil",
    platforms: [
        .iOS("27.0.0")
    ],
    products: [
        .executable(name: "Mil", targets: ["Mil"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Mil",
            dependencies: [
                "ConnectIQ"
            ],
            path: "Sources",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-ObjC"])
            ]
        ),
        .binaryTarget(
            name: "ConnectIQ",
            path: "Packages/ConnectIQ/ConnectIQ.xcframework"
        )
    ]
)
