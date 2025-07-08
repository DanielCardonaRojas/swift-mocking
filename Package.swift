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
        .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.6.3"),
        .package(url: "https://github.com/DanielCardonaRojas/ProtocolWitnessMacro", branch: "main")
//        .package(path: "/Users/danielcardona/development/ProtocolWitnessMacro")
    ],
    targets: [
        .target(
            name: "Mockable",
            dependencies: [
                "MockableMacro",
            ]),
        .target(name: "Shared"),
        .target(
            name: "MockableGenerator",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                "Shared"
            ]
        ),
        .macro(
            name: "MockableMacro",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "MockableGenerator"
            ]
        ),
        .testTarget(
            name: "MockableTests",
            dependencies: [
                "MockableGenerator",
                "Mockable",
                "Shared"
            ]
        ),
        .testTarget(name: "MockableMacroTests", dependencies: [
            "MockableGenerator",
            "Mockable",
            "Shared",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            .product(name: "MacroTesting", package: "swift-macro-testing")
        ])
    ]
)
