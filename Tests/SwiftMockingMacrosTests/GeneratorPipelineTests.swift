import XCTest

import MockableGenerator

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
