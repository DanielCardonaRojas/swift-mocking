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
        .library(
            name: "MockableTypes",
            targets: ["MockableTypes"]
        ),
        .library(
            name: "SwiftMockingTestSupport",
            targets: ["SwiftMockingTestSupport"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.1"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.6.3"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.5"),

    ],
    targets: [
        .target(
            name: "SwiftMocking",
            dependencies: [
                "MockableMacro",
                "MockableTypes"
            ]),
        .target(name: "MockableTypes"),
        .target(
            name: "SwiftMockingTestSupport",
            dependencies: [
                "SwiftMocking",
                "MockableTypes",
            ]),
        .target(
            name: "MockableGenerator",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                "MockableTypes"
            ]
        ),
        .macro(
            name: "MockableMacro",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "MockableGenerator",
            ]
        ),
        .testTarget(
            name: "MockableTests",
            dependencies: [
                "SwiftMocking",
                "SwiftMockingTestSupport",
                "MockableGenerator",
                "MockableTypes"
            ]
        ),
        .testTarget(name: "MockableMacroTests", dependencies: [
            "MockableGenerator",
            "SwiftMocking",
            "MockableMacro",
            "MockableTypes",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            .product(name: "MacroTesting", package: "swift-macro-testing")
        ])
    ]
)
