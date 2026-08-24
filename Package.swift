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

// Opt-in emission of `.swiftinterface` files for the library targets, used by
// Scripts/generate-interface.sh to refresh the agent skill's API reference.
// Off by default: library evolution cannot be applied package-wide because the
// swift-syntax dependency does not build under it.
let emitInterface = Context.environment["SWIFTMOCKING_EMIT_INTERFACE"] != nil
let interfaceSettings: [SwiftSetting] = emitInterface
    ? [.unsafeFlags(["-enable-library-evolution", "-emit-module-interface"])]
    : []

let package = Package(
    name: "swift-mocking",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .macCatalyst(.v17)
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
        .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.7.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.5"),
        // NOTE: This is the pre-2.0 name of swift-issue-reporting. Migrating to
        // `https://github.com/pointfreeco/swift-issue-reporting` (2.x) currently fails
        // the package graph: swift-custom-dump — reached via swift-macro-testing ->
        // swift-snapshot-testing, and still on the old name as of custom-dump 1.7.0 and
        // its main branch — makes SwiftPM see two distinct packages vending an
        // `IssueReporting` target. The two URLs are separate live repos, not a redirect,
        // so SwiftPM cannot unify them. Revisit once custom-dump adopts the new name.
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.11.0")

    ],
    targets: [
        .target(
            name: "SwiftMocking",
            dependencies: [
                "SwiftMockingMacros",
                "SwiftMockingOptions",
                // Not imported by any source file here, but `@Mockable` expansions in
                // client targets reference MockableGenerator symbols, which xcodebuild
                // only resolves if the dependency is declared on this target.
                "MockableGenerator",
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            swiftSettings: swiftSettings + interfaceSettings
        ),
        .target(
            name: "SwiftMockingTestSupport",
            dependencies: [
                "SwiftMocking"
            ],
            swiftSettings: [.swiftLanguageMode(.v6)] + interfaceSettings
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
