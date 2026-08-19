// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

// Conditional compilation settings based on Swift version
// The -O flag enables optimizations which allows @inline(__always) to work correctly.
// We use @inline(__always) to ensure fatalError() calls for unstubbed values are surfaced
// in the client code stack traces, not in SwiftMocking's internal code.
// This improves debugging by showing errors at the call site in user tests.
// Applies to unstubbed non-throwing spies (Async and None effects).
// Only enabled for Swift 6.2+ to avoid compiler issues in earlier versions.
var swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6)
]
#if swift(>=6.2)
swiftSettings.append(.unsafeFlags(["-O"]))
#endif

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
        .library(
            name: "SwiftMockingTestSupport",
            targets: ["SwiftMockingTestSupport"]
        ),
        .executable(
            name: "mockable",
            targets: ["MockableCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "509.0.0"..<"602.0.0"),
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
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SwiftMockingTestSupport",
            dependencies: [
                "SwiftMocking"
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(name: "SwiftMockingOptions"),
        .target(
            name: "MockableGenerator",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftParserDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                "SwiftMockingOptions",
            ]
        ),
        .executableTarget(
            name: "MockableCLI",
            dependencies: [
                "MockableGenerator",
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
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
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(name: "SwiftMockingMacrosTests", dependencies: [
            "SwiftMocking",
            "SwiftMockingMacros",
            "MockableGenerator",
            .product(name: "MacroTesting", package: "swift-macro-testing"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
        ], swiftSettings: [.swiftLanguageMode(.v6)])
        ,
        .testTarget(
            name: "Swift5CompatTests",
            dependencies: ["SwiftMocking"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
