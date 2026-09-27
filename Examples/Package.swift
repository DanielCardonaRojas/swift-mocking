// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

// Typed throws (`throws(MyError)`) cannot be *parsed* by swift-syntax 509 and 510, which
// predate the feature: `thrownErrorTypeSyntax` documents that a `throws` clause of that
// vintage is a bare token with no room for an error type. A `@Mockable` protocol using it
// therefore expands to malformed code on those pins, regardless of how new the compiler is.
//
// The compatibility script sets this for the pins that cannot handle it, so the one example
// protocol that needs typed throws is compiled out there and everywhere else keeps its
// coverage. See `Scripts/test-swift-syntax-compat.sh`.
let typedThrowsUnsupported =
    ProcessInfo.processInfo.environment["SWIFTMOCKING_NO_TYPED_THROWS"] != nil

let typedThrowsSettings: [SwiftSetting] =
    typedThrowsUnsupported ? [] : [.define("SWIFTMOCKING_TYPED_THROWS")]

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
        .package(path: "../"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.11.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Examples",
            dependencies: [
                .product(name: "SwiftMocking", package: "swift-mocking")
            ],
            swiftSettings: typedThrowsSettings
        ),
        // Trips SwiftMocking's unrecoverable path in a process that is allowed to die, so a
        // test can run it under lldb and assert on which stack frame the trap is attributed
        // to. That cannot be observed in-process, since `fatalError` takes the process down.
        // See `ErrorReportingTests`.
        .executableTarget(
            name: "TrapProbe",
            dependencies: ["Examples"],
            swiftSettings: typedThrowsSettings
        ),
        .testTarget(
            name: "ExamplesTests",
            dependencies: [
                "Examples",
                .product(name: "IssueReportingTestSupport", package: "xctest-dynamic-overlay"),
            ],
            swiftSettings: typedThrowsSettings
        ),
    ]
)
