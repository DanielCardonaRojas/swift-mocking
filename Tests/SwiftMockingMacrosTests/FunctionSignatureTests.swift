
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
            class MockPricingService: @unchecked Sendable, PricingService, MockBacked {
                func price(_ item: ArgMatcher<String>) -> Interaction<String, None, Int> {
                    Interaction(item, spy: mock.price)
                }
                func price(_ item: String) -> Int {
                    return mock.adapt(mock.price, item)
                }
                let mock = Mock()
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
            class MockPrinter: @unchecked Sendable, Printer, MockBacked {
                func print(_ values: ArgMatcher<String>...) -> Interaction<[String], None, Void> {
                    Interaction(.variadic(values), spy: mock.print)
                }
                func print(_ values: String...) {
                    return mock.adapt(mock.print, values)
                }
                let mock = Mock()
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
            class MockPricingService: @unchecked Sendable, PricingService, MockBacked {
                func price(_ item: ArgMatcher<String>) -> Interaction<String, Throws, Int> {
                    Interaction(item, spy: mock.price)
                }
                func price(_ item: String) throws -> Int {
                    return try mock.adaptThrowing(mock.price, item)
                }
                let mock = Mock()
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
            class MockPricingService: @unchecked Sendable, PricingService, MockBacked {
                func price(_ item: ArgMatcher<String>) -> Interaction<String, Async, Int> {
                    Interaction(item, spy: mock.price)
                }
                func price(_ item: String) async -> Int {
                    return await mock.adapt(mock.price, item)
                }
                let mock = Mock()
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
            class MockPricingService: @unchecked Sendable, PricingService, MockBacked {
                func price(_ item: ArgMatcher<String>) -> Interaction<String, AsyncThrows, Int> {
                    Interaction(item, spy: mock.price)
                }
                func price(_ item: String) async throws -> Int {
                    return try await mock.adaptThrowing(mock.price, item)
                }
                let mock = Mock()
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
            class MockFeedService: @unchecked Sendable, FeedService, MockBacked {
                func fetch(from url: ArgMatcher<URL>) -> Interaction<URL, AsyncThrows, Data> {
                    Interaction(url, spy: mock.fetch)
                }
                func post(to url: ArgMatcher<URL>, data: ArgMatcher<Data>) -> Interaction<URL, Data, AsyncThrows, Void> {
                    Interaction(url, data, spy: mock.post)
                }
                func fetch(from url: URL) async throws -> Data {
                    return try await mock.adaptThrowing(mock.fetch, url)
                }
                func post(to url: URL, data: Data) async throws {
                    return try await mock.adaptThrowing(mock.post, url, data)
                }
                let mock = Mock()
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
            class MockService: @unchecked Sendable, Service, MockBacked {
                func doSomething() -> Interaction<Void, None, String> {
                    Interaction(.any, spy: mock.doSomething)
                }
                func doSomething() -> String {
                    return mock.adapt(mock.doSomething)
                }
                let mock = Mock()
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
            class MockService: @unchecked Sendable, Service, MockBacked {
                func doSomething(with value: ArgMatcher<Int>) -> Interaction<Int, None, Void> {
                    Interaction(value, spy: mock.doSomething)
                }
                func doSomething(with value: Int) {
                    return mock.adapt(mock.doSomething, value)
                }
                let mock = Mock()
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
            class MockService: @unchecked Sendable, Service, MockBacked {
                func doSomething() -> Interaction<Void, None, Void> {
                    Interaction(.any, spy: mock.doSomething)
                }
                func doSomething() {
                    return mock.adapt(mock.doSomething)
                }
                let mock = Mock()
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
            class MockLogger: @unchecked Sendable, Logger, MockBacked {
                static func log(_ message: ArgMatcher<String>) -> Interaction<String, None, Void> {
                    Interaction(message, spy: Mock.staticSpy(typeName: "MockLogger", member: "log"))
                }
                    static func log(_ message: String) {
                    return Mock.adapt(Mock.staticSpy(typeName: "MockLogger", member: "log"), message)
                }
                let mock = Mock()
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
            class MockAnalyticsProtocol: @unchecked Sendable, AnalyticsProtocol, MockBacked {
                func logEvent<E: Identifiable>(_ event: ArgMatcher<E>) -> Interaction<E, None, Bool> {
                    Interaction(event, spy: mock.logEvent)
                }
                func logEvent<E: Identifiable>(_ event: E) -> Bool {
                    return mock.adapt(mock.logEvent, event)
                }
                let mock = Mock()
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
            class MockCallbackService: @unchecked Sendable, CallbackService, MockBacked {
                func execute(completion: ArgMatcher<(String) -> Void>) -> Interaction<(String) -> Void, None, Void> {
                    Interaction(completion, spy: mock.execute)
                }
                func execute(completion: @escaping (String) -> Void) {
                    return mock.adapt(mock.execute, completion)
                }
                let mock = Mock()
            }
            #endif
            """
        }

    }
}
