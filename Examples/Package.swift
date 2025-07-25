// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Examples",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v13),
        .watchOS(.v10),
        .macCatalyst(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Examples",
            targets: ["Examples"]),
    ],
    dependencies: [
        .package(path: "../")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Examples",
            dependencies: [
                .product(name: "SwiftMocking", package: "swift-mocking")
            ]
        ),
        .testTarget(
            name: "ExamplesTests",
            dependencies: ["Examples"]
        ),
    ]
)
