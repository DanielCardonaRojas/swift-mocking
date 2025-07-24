// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swift-mocking",
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
            name: "SwiftMocking",
            targets: ["SwiftMocking"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.1"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.6.3"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.5"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.6.0")

    ],
    targets: [
        .target(
            name: "SwiftMocking",
            dependencies: [
                "SwiftMockingMacros",
                "SwiftMockingOptions",
                "MockableGenerator",
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ]
        ),
        .target(name: "SwiftMockingOptions"),
        .target(
            name: "MockableGenerator",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                "SwiftMockingOptions",
            ]
        ),
        .macro(
            name: "SwiftMockingMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "MockableGenerator",
            ]
        ),
        .testTarget(
            name: "SwiftMockingTests",
            dependencies: [
                "SwiftMocking",
            ]
        ),
        .testTarget(name: "SwiftMockingMacrosTests", dependencies: [
            "SwiftMocking",
            .product(name: "MacroTesting", package: "swift-macro-testing")
        ])
    ]
)
