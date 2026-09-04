
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import MacroTesting

final class FunctionSignatureTests: MacroTestCase {
    func testSingleMethodNoEffects() {
        assertMacro {
           """
            @Mockable()
            protocol PricingService {
                func price(_ item: String) -> Int
            }
            """
        } expansion: {
            """
            protocol PricingService {
                func price(_ item: String) -> Int
            }

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
        }
    }

    func testVariadicParameters() {
        assertMacro {
            """
            @Mockable
            protocol Printer {
                func print(_ values: String...)
            }
            """
        } expansion: {
            """
            protocol Printer {
                func print(_ values: String...)
            }

            #if DEBUG
            class MockPrinter: Mock, @unchecked Sendable, Printer {
                func print(_ values: ArgMatcher<String>...) -> Interaction<[String], None, Void> {
                    Interaction(.variadic(values), spy: super.print)
                }

                func print(_ values: String...) {
                    return adapt(super.print, values)
                }
            }
            #endif
            """
        }
    }

    func testSingleMethodThrows() {
        assertMacro {
           """
            @Mockable()
            protocol PricingService {
                func price(_ item: String) throws -> Int
            }
            """
        } expansion: {
            """
            protocol PricingService {
                func price(_ item: String) throws -> Int
            }

            #if DEBUG
            class MockPricingService: Mock, @unchecked Sendable, PricingService {
                func price(_ item: ArgMatcher<String>) -> Interaction<String, Throws, Int> {
                    Interaction(item, spy: super.price)
                }

                func price(_ item: String) throws -> Int {
                    return try adaptThrowing(super.price, item)
                }
            }
            #endif
            """
        }
    }

    func testSingleMethodTypedThrows() {
        assertMacro {
           """
            @Mockable()
            protocol PricingService {
                func price(_ item: String) throws(PricingError) -> Int
            }
            """
        } expansion: {
            """
            protocol PricingService {
                func price(_ item: String) throws(PricingError) -> Int
            }

            #if DEBUG
            class MockPricingService: Mock, @unchecked Sendable, PricingService {
                func price(_ item: ArgMatcher<String>) -> Interaction<String, TypedThrows<PricingError>, Int> {
                    Interaction(item, spy: super.price)
                }

                func price(_ item: String) throws(PricingError) -> Int {
                    let typedSpy: Spy<String, TypedThrows<PricingError>, Int> = super.price
                    return try adaptTypedThrowing(typedSpy, item)
                }
            }
            #endif
            """
        }
    }

    func testSingleMethodAsyncTypedThrows() {
        assertMacro {
           """
            @Mockable()
            protocol PricingService {
                func price(_ item: String) async throws(PricingError) -> Int
            }
            """
        } expansion: {
            """
            protocol PricingService {
                func price(_ item: String) async throws(PricingError) -> Int
            }

            #if DEBUG
            class MockPricingService: Mock, @unchecked Sendable, PricingService {
                func price(_ item: ArgMatcher<String>) -> Interaction<String, AsyncTypedThrows<PricingError>, Int> {
                    Interaction(item, spy: super.price)
                }

                func price(_ item: String) async throws(PricingError) -> Int {
                    let typedSpy: Spy<String, AsyncTypedThrows<PricingError>, Int> = super.price
                    return try await adaptAsyncTypedThrowing(typedSpy, item)
                }
            }
            #endif
            """
        }
    }

    /// `throws(any Error)` is the canonical desugaring of an untyped `throws`, so it
    /// must produce the untyped `Throws` effect rather than `TypedThrows<any Error>`.
    func testSingleMethodThrowsAnyErrorStaysUntyped() {
        assertMacro {
           """
            @Mockable()
            protocol PricingService {
                func price(_ item: String) throws(any Error) -> Int
            }
            """
        } expansion: {
            """
            protocol PricingService {
                func price(_ item: String) throws(any Error) -> Int
            }

            #if DEBUG
            class MockPricingService: Mock, @unchecked Sendable, PricingService {
                func price(_ item: ArgMatcher<String>) -> Interaction<String, Throws, Int> {
                    Interaction(item, spy: super.price)
                }

                func price(_ item: String) throws(any Error) -> Int {
                    return try adaptThrowing(super.price, item)
                }
            }
            #endif
            """
        }
    }

    /// `throws(Never)` cannot throw, so callers invoke it without `try` and the
    /// generated conformance must not emit one.
    func testSingleMethodThrowsNeverIsNonThrowing() {
        assertMacro {
           """
            @Mockable()
            protocol PricingService {
                func price(_ item: String) throws(Never) -> Int
            }
            """
        } expansion: {
            """
            protocol PricingService {
                func price(_ item: String) throws(Never) -> Int
            }

            #if DEBUG
            class MockPricingService: Mock, @unchecked Sendable, PricingService {
                func price(_ item: ArgMatcher<String>) -> Interaction<String, None, Int> {
                    Interaction(item, spy: super.price)
                }

                func price(_ item: String) throws(Never) -> Int {
                    return adapt(super.price, item)
                }
            }
            #endif
            """
        }
    }

    func testSingleMethodAsync() {
        assertMacro {
           """
            @Mockable()
            protocol PricingService {
                func price(_ item: String) async -> Int
            }
            """
        } expansion: {
            """
            protocol PricingService {
                func price(_ item: String) async -> Int
            }

            #if DEBUG
            class MockPricingService: Mock, @unchecked Sendable, PricingService {
                func price(_ item: ArgMatcher<String>) -> Interaction<String, Async, Int> {
                    Interaction(item, spy: super.price)
                }

                func price(_ item: String) async -> Int {
                    return await adapt(super.price, item)
                }
            }
            #endif
            """
        }
    }

    func testSingleMethodAsyncThrows() {
        assertMacro {
           """
            @Mockable()
            protocol PricingService {
                func price(_ item: String) async throws -> Int
            }
            """
        } expansion: {
            """
            protocol PricingService {
                func price(_ item: String) async throws -> Int
            }

            #if DEBUG
            class MockPricingService: Mock, @unchecked Sendable, PricingService {
                func price(_ item: ArgMatcher<String>) -> Interaction<String, AsyncThrows, Int> {
                    Interaction(item, spy: super.price)
                }

                func price(_ item: String) async throws -> Int {
                    return try await adaptThrowing(super.price, item)
                }
            }
            #endif
            """
        }
    }

    func testMultipleMethods() {
        assertMacro {
           """
            @Mockable()
            protocol FeedService {
                func fetch(from url: URL) async throws -> Data
                func post(to url: URL, data: Data) async throws
            }
            """
        } expansion: {
            """
            protocol FeedService {
                func fetch(from url: URL) async throws -> Data
                func post(to url: URL, data: Data) async throws
            }

            #if DEBUG
            class MockFeedService: Mock, @unchecked Sendable, FeedService {
                func fetch(from url: ArgMatcher<URL>) -> Interaction<URL, AsyncThrows, Data> {
                    Interaction(url, spy: super.fetch)
                }

                func post(to url: ArgMatcher<URL>, data: ArgMatcher<Data>) -> Interaction<URL, Data, AsyncThrows, Void> {
                    Interaction(url, data, spy: super.post)
                }

                func fetch(from url: URL) async throws -> Data {
                    return try await adaptThrowing(super.fetch, url)
                }

                func post(to url: URL, data: Data) async throws {
                    return try await adaptThrowing(super.post, url, data)
                }
            }
            #endif
            """
        }
    }

    func testNoParameters() {
        assertMacro {
           """
            @Mockable()
            protocol Service {
                func doSomething() -> String
            }
            """
        } expansion: {
            """
            protocol Service {
                func doSomething() -> String
            }

            #if DEBUG
            class MockService: Mock, @unchecked Sendable, Service {
                func doSomething() -> Interaction<Void, None, String> {
                    Interaction(.any, spy: super.doSomething)
                }

                func doSomething() -> String {
                    return adapt(super.doSomething, ())
                }
            }
            #endif
            """
        }
    }

    func testNoReturn() {
        assertMacro {
           """
            @Mockable()
            protocol Service {
                func doSomething(with value: Int)
            }
            """
        } expansion: {
            """
            protocol Service {
                func doSomething(with value: Int)
            }

            #if DEBUG
            class MockService: Mock, @unchecked Sendable, Service {
                func doSomething(with value: ArgMatcher<Int>) -> Interaction<Int, None, Void> {
                    Interaction(value, spy: super.doSomething)
                }

                func doSomething(with value: Int) {
                    return adapt(super.doSomething, value)
                }
            }
            #endif
            """
        }
    }

    func testNoParametersAndNoReturn() {
        assertMacro {
           """
            @Mockable()
            protocol Service {
                func doSomething()
            }
            """
        } expansion: {
            """
            protocol Service {
                func doSomething()
            }

            #if DEBUG
            class MockService: Mock, @unchecked Sendable, Service {
                func doSomething() -> Interaction<Void, None, Void> {
                    Interaction(.any, spy: super.doSomething)
                }

                func doSomething() {
                    return adapt(super.doSomething, ())
                }
            }
            #endif
            """
        }
    }

    func testStaticFunctionRequirement() {

        assertMacro {
            """
            @Mockable
            protocol Logger {
                static func log(_ message: String)
            }
            """
        } expansion: {
            """
            protocol Logger {
                static func log(_ message: String)
            }

            #if DEBUG
            class MockLogger: Mock, @unchecked Sendable, Logger {
                static func log(_ message: ArgMatcher<String>) -> Interaction<String, None, Void> {
                    Interaction(message, spy: super.log)
                }

                static func log(_ message: String) {
                    return adapt(super.log, message)
                }
            }
            #endif
            """
        }

    }

    func testGenericParameter() {
        assertMacro {
            """
            @Mockable
            public protocol AnalyticsProtocol: Sendable {
                func logEvent<E: Identifiable>(_ event: E) -> Bool
            }
            """
        } expansion: {
            """
            public protocol AnalyticsProtocol: Sendable {
                func logEvent<E: Identifiable>(_ event: E) -> Bool
            }

            #if DEBUG
            class MockAnalyticsProtocol: Mock, @unchecked Sendable, AnalyticsProtocol {
                func logEvent<E: Identifiable>(_ event: ArgMatcher<E>) -> Interaction<E, None, Bool> {
                    Interaction(event, spy: super.logEvent)
                }

                func logEvent<E: Identifiable>(_ event: E) -> Bool {
                    return adapt(super.logEvent, event)
                }
            }
            #endif
            """
        }
    }

    func testEscaping() {
        assertMacro {
            """
            @Mockable
            protocol CallbackService {
                func execute(completion: @escaping (String) -> Void)
            }
            """
        } expansion: {
            """
            protocol CallbackService {
                func execute(completion: @escaping (String) -> Void)
            }

            #if DEBUG
            class MockCallbackService: Mock, @unchecked Sendable, CallbackService {
                func execute(completion: ArgMatcher<(String) -> Void>) -> Interaction<(String) -> Void, None, Void> {
                    Interaction(completion, spy: super.execute)
                }

                func execute(completion: @escaping (String) -> Void) {
                    return adapt(super.execute, completion)
                }
            }
            #endif
            """
        }

    }
}
