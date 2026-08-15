// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

var swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("StrictConcurrency")
]

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
        .library(
            name: "SwiftMocking",
            targets: ["SwiftMocking"]
        ),
        .library(
            name: "SwiftMockingTestSupport",
            targets: ["SwiftMockingTestSupport"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "509.0.0"..<"600.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", "0.6.3"..<"0.7.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", "1.3.0"..<"1.4.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay.git", "1.3.0"..<"1.6.0")
    ],
    targets: [
        .target(
            name: "SwiftMocking",
            dependencies: [
                "SwiftMockingMacros",
                "SwiftMockingOptions",
                "MockableGenerator",
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SwiftMockingTestSupport",
            dependencies: [
                "SwiftMocking"
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
                "SwiftMockingTestSupport",
            ]
        ),
        .testTarget(name: "SwiftMockingMacrosTests", dependencies: [
            "SwiftMocking",
            "SwiftMockingMacros",
            .product(name: "MacroTesting", package: "swift-macro-testing"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
        ]),
        .testTarget(
            name: "Swift5CompatTests",
            dependencies: ["SwiftMocking"]
        )
    ]
)
