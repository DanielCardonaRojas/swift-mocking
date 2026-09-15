// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

// Nothing here may use `.unsafeFlags`. SwiftPM rejects any package graph in which a
// *version-pinned* dependency declares unsafe flags on a target reachable from a
// product, so a single such flag makes the library unusable through a normal
// `from:`/`exact:` requirement — resolution still succeeds, and only the eventual
// build fails, which makes it slow to diagnose. See issue #124.
//
// This previously carried `.unsafeFlags(["-O"])` under `#if swift(>=6.2)`, on the
// theory that optimization was needed for the `@inline(__always)` adapters to surface
// unstubbed-value `fatalError`s in client stack traces rather than in SwiftMocking's
// own code. Measured directly, it did not do that: with and without `-O`, the trap is
// reported identically at `SwiftMocking/Mock+Adapters.swift:53`. That is expected —
// `fatalError` captures `#file`/`#line` at its definition site, and no optimization
// level changes which literal the compiler bakes in. Attributing the trap to the call
// site requires threading `#file`/`#line` through the adapters as default arguments,
// which is a source change and needs no build flags.
var swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6)
]

// Opt-in emission of `.swiftinterface` files for the library targets, used by
// Scripts/generate-interface.sh to refresh the agent skill's API reference.
// Off by default: library evolution cannot be applied package-wide because the
// swift-syntax dependency does not build under it.
//
// This does use `.unsafeFlags`, but only when SWIFTMOCKING_EMIT_INTERFACE is set,
// which happens solely in that script. Consumers never set it, so the flags are
// absent from the manifest they resolve and the restriction described above does
// not apply. Keep it that way: any unconditional unsafe flag breaks #124 again.
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
        // Widened past 602 so swift-mocking can share a package graph with other macro
        // packages that have moved to 602+ (e.g. SafeDI 2.x). SwiftPM resolves a single
        // swift-syntax for the whole graph, so a narrow ceiling here makes those graphs
        // unresolvable rather than merely untested.
        //
        // 509 and 510 are supported through the version shims in
        // MockableGenerator/SwiftSyntax+Extensions.swift. Note that typed throws cannot be
        // detected on those versions — `ThrowsClauseSyntax` only exists from 600 — but that
        // costs nothing in practice, since a toolchain of that vintage cannot parse
        // `throws(MyError)` to begin with.
        //
        // Known bad: exactly 602.0.0 and 603.0.0, where building a *client* of SwiftMocking
        // fails with "no such module 'SwiftMockingOptions'". This is an upstream SwiftPM
        // defect, not an API break: when a package containing a `.macro` target is consumed
        // as a dependency, plain targets reachable from that macro are misclassified as
        // tool-only and emitted solely into `Modules-tool/`, so the library target cannot
        // import them. Reproduced on a minimal package with none of our code, and no
        // manifest-level workaround exists (declaring the dependency explicitly, reordering
        // it, and vending it as a product were all tried). Every other release in this range
        // builds clients cleanly: 509.0.2, 509.1.1, 510.0.0, 510.0.3, 600.0.0, 600.0.1,
        // 601.0.0, 601.0.1, 603.0.1 and 603.0.2. SwiftPM ranges cannot exclude individual
        // versions, but resolution prefers the newest match, so the two bad releases are
        // only reachable via an explicit pin — for which the fix is to move to 603.0.1+.
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            "509.0.0"..<"605.0.0"
        ),
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
                .product(name: "IssueReportingTestSupport", package: "xctest-dynamic-overlay"),
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
