// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Mockable",
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
            name: "Mockable",
            targets: ["Mockable"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.1"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.6.3")
    ],
    targets: [
        .target(name: "Mockable", dependencies: ["MockableMacro"]),
        .macro(
            name: "MockableMacro",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .testTarget(
            name: "MockableTests",
            dependencies: [
                "Mockable",
            ]
        ),
        .testTarget(name: "MockableMacroTests", dependencies: [
            "MockableMacro",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            .product(name: "MacroTesting", package: "swift-macro-testing")
        ])
    ]
)
