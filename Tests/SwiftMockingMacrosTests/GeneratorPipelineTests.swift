import SwiftParser
import SwiftSyntax
import XCTest

import MockableGenerator
import SwiftMockingOptions

/// Tests that `MockableGenerator.generateMocks(source:)` — the pipeline behind the
/// `mockable` CLI — produces output byte-identical to the fixtures pinned by the
/// `@Mockable` macro expansion tests.
final class GeneratorPipelineTests: XCTestCase {
    func testGenerateMocksForSingleMethodMatchesMacroExpansion() throws {
        let mocks = try MockableGenerator.generateMocks(
            source: """
            @Mockable()
            protocol PricingService {
                func price(_ item: String) -> Int
            }
            """
        )

        XCTAssertEqual(mocks.map(\.protocolName), ["PricingService"])
        XCTAssertEqual(mocks.map(\.source), [
            """
            #if DEBUG
            class MockPricingService: Mock, @unchecked Sendable, PricingService {
                func price(_ item: ArgMatcher<String>) -> Interaction<String, None, Int> {
                    Interaction(item, spy: super.price)
                }

                func price(_ item: String) -> Int {
                    return adapt(super.price, item)
                }
            }
            #endif
            """
        ])
    }

    func testGenerateMocksForPropertyMatchesMacroExpansion() throws {
        let mocks = try MockableGenerator.generateMocks(
            source: """
            @Mockable()
            protocol MyService {
                var value: Int { get }
            }
            """
        )

        XCTAssertEqual(mocks.map(\.source), [
            """
            #if DEBUG
            class MockMyService: Mock, @unchecked Sendable, MyService {
                func value(_ void: Void = ()) -> Interaction<Void, None, Int > {
                    Interaction(.any, spy: super.value)
                }

                var value: Int {
                    get {
                        adapt(super.value, ())
                    }
                }
            }
            #endif
            """
        ])
    }

    func testGenerateMocksHonorsOptionsFromAttribute() throws {
        let mocks = try MockableGenerator.generateMocks(
            source: """
            @Mockable([.suffixMock])
            protocol MyService {
                func doSomething()
            }
            """
        )

        XCTAssertEqual(mocks.map(\.source), [
            """
            #if DEBUG
            class MyServiceMock: Mock, @unchecked Sendable, MyService {
                func doSomething() -> Interaction<Void, None, Void> {
                    Interaction(.any, spy: super.doSomething)
                }

                func doSomething() {
                    return adapt(super.doSomething, ())
                }
            }
            #endif
            """
        ])
    }

    func testGenerateMocksForProtocolWithoutAttributeUsesDefaultPrefix() throws {
        let mocks = try MockableGenerator.generateMocks(
            source: """
            protocol MyService {
                func doSomething()
            }
            """
        )

        XCTAssertEqual(mocks.map(\.protocolName), ["MyService"])
        XCTAssertTrue(mocks[0].source.contains("class MockMyService:"))
    }

    func testGenerateMocksForMultipleProtocolsPreservesDeclarationOrder() throws {
        let mocks = try MockableGenerator.generateMocks(
            source: """
            struct NotAProtocol {}

            protocol First {
                func first()
            }

            enum AlsoNotAProtocol {}

            protocol Second {
                func second()
            }
            """
        )

        XCTAssertEqual(mocks.map(\.protocolName), ["First", "Second"])
        XCTAssertEqual(mocks.map(\.inheritedTypeNames), [[], []])
    }

    func testGenerateMocksReportsInheritedTypeNamesWithoutMemberlessBases() throws {
        let mocks = try MockableGenerator.generateMocks(
            source: """
            protocol Second: First, Sendable, AnyObject {
                func second()
            }
            """
        )

        XCTAssertEqual(mocks[0].inheritedTypeNames, ["First"])
    }

    func testGenerateMocksThrowsWhenNoProtocolDeclarationPresent() {
        XCTAssertThrowsError(
            try MockableGenerator.generateMocks(source: "struct Foo {}")
        ) { error in
            XCTAssertEqual(
                error as? MockableGeneratorError,
                .noProtocolsFound
            )
        }
    }

    func testGenerateMocksThrowsAnnotatedDiagnosticsForMalformedInput() {
        XCTAssertThrowsError(
            try MockableGenerator.generateMocks(source: "protocol {")
        ) { error in
            guard case let .parseFailed(diagnostics) = error as? MockableGeneratorError else {
                return XCTFail("expected parseFailed, got \(error)")
            }
            XCTAssertTrue(diagnostics.contains("error:"), "diagnostics should annotate errors: \(diagnostics)")
        }
    }

    func testGenerateMocksAppliesDefaultOptionsToProtocolWithoutAttribute() throws {
        // The CLI's `--options` case: mocking a protocol you cannot annotate,
        // such as one vended by a third-party library.
        let mocks = try MockableGenerator.generateMocks(
            source: """
            protocol Service: SomeBase {
                func load()
            }
            """,
            includeDebugWrapper: false,
            defaultOptions: [.composition]
        )

        let source = try XCTUnwrap(mocks.first?.source)
        XCTAssertTrue(
            source.contains("class MockService: SomeBase, Service, MockProviding, @unchecked Sendable {"),
            "composition should compose rather than inherit Mock: \(source)"
        )
        XCTAssertTrue(source.contains("let mock = Mock()"), source)
    }

    func testGenerateMocksPrefersAttributeOptionsOverDefaultOptions() throws {
        // An explicit attribute wins; the fallback only fills in for protocols
        // that declare nothing of their own.
        let mocks = try MockableGenerator.generateMocks(
            source: """
            @Mockable([.suffixMock])
            protocol Annotated {
                func a()
            }

            protocol Bare {
                func b()
            }
            """,
            includeDebugWrapper: false,
            defaultOptions: [.composition]
        )

        XCTAssertEqual(mocks.map(\.protocolName), ["Annotated", "Bare"])
        XCTAssertTrue(
            mocks[0].source.contains("class AnnotatedMock: Mock, @unchecked Sendable, Annotated {"),
            "attribute options should survive a conflicting fallback: \(mocks[0].source)"
        )
        // `Bare` has no inheritance clause, so the composed mock has no
        // superclass and conforms to plain `Sendable` as a `final` class.
        XCTAssertTrue(
            mocks[1].source.contains("final class MockBare: Bare , MockProviding, Sendable {"),
            "unannotated protocol should take the fallback: \(mocks[1].source)"
        )
    }

    func testGenerateMocksWithNonNamingDefaultOptionsKeepsDefaultPrefixName() throws {
        // `.composition` names no naming strategy, so the name must still come
        // from `.default` (prefix) rather than falling through to a suffix.
        let mocks = try MockableGenerator.generateMocks(
            source: "protocol Service { func load() }",
            includeDebugWrapper: false,
            defaultOptions: [.composition]
        )

        XCTAssertTrue(mocks[0].source.contains("class MockService:"), mocks[0].source)
    }

    func testDeclaredCodeGenOptionsIsNilWhenProtocolDeclaresNoOptions() throws {
        func declaredOptions(_ source: String) throws -> MockableOptions? {
            let protocolDecl = try XCTUnwrap(
                Parser.parse(source: source).statements.first?.item.as(ProtocolDeclSyntax.self)
            )
            return MockableGenerator.declaredCodeGenOptions(protocolDecl: protocolDecl)
        }

        XCTAssertNil(try declaredOptions("protocol Bare { func a() }"))
        XCTAssertNil(try declaredOptions("@Mockable\nprotocol NoArguments { func a() }"))
        XCTAssertEqual(
            try declaredOptions("@Mockable([.composition])\nprotocol Annotated { func a() }"),
            [.composition]
        )
    }

    func testGenerateMocksWithoutDebugWrapperOmitsIfConfigAndKeepsMembers() throws {
        let mocks = try MockableGenerator.generateMocks(
            source: """
            @Mockable()
            protocol PricingService {
                func price(_ item: String) -> Int
            }
            """,
            includeDebugWrapper: false
        )

        XCTAssertEqual(mocks.map(\.source), [
            """
            class MockPricingService: Mock, @unchecked Sendable, PricingService {
                func price(_ item: ArgMatcher<String>) -> Interaction<String, None, Int> {
                    Interaction(item, spy: super.price)
                }

                func price(_ item: String) -> Int {
                    return adapt(super.price, item)
                }
            }
            """
        ])
    }

}
