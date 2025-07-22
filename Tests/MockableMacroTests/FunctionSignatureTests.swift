
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import MockableMacro
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
            class PricingServiceMock: Mock, PricingService {
                func price(_ item: String) -> Int {
                    return adapt(super.price, item)
                }
                func price(_ item: ArgMatcher<String>) -> Interaction<String, None, Int> {
                    Interaction(item, spy: super.price)
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
            class PricingServiceMock: Mock, PricingService {
                func price(_ item: String) throws -> Int {
                    return try adaptThrowing(super.price, item)
                }
                func price(_ item: ArgMatcher<String>) -> Interaction<String, Throws, Int> {
                    Interaction(item, spy: super.price)
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
            class PricingServiceMock: Mock, PricingService {
                func price(_ item: String) async -> Int {
                    return await adapt(super.price, item)
                }
                func price(_ item: ArgMatcher<String>) -> Interaction<String, Async, Int> {
                    Interaction(item, spy: super.price)
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
            class PricingServiceMock: Mock, PricingService {
                func price(_ item: String) async throws -> Int {
                    return try await adaptThrowing(super.price, item)
                }
                func price(_ item: ArgMatcher<String>) -> Interaction<String, AsyncThrows, Int> {
                    Interaction(item, spy: super.price)
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
            class FeedServiceMock: Mock, FeedService {
                func fetch(from url: URL) async throws -> Data {
                    return try await adaptThrowing(super.fetch, url)
                }
                func post(to url: URL, data: Data) async throws {
                    return try await adaptThrowing(super.post, url, data)
                }
                func fetch(from url: ArgMatcher<URL>) -> Interaction<URL, AsyncThrows, Data> {
                    Interaction(url, spy: super.fetch)
                }
                func post(to url: ArgMatcher<URL>, data: ArgMatcher<Data>) -> Interaction<URL, Data, AsyncThrows, Void> {
                    Interaction(url, data, spy: super.post)
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
            class ServiceMock: Mock, Service {
                func doSomething() -> String {
                    return adapt(super.doSomething)
                }
                func doSomething() -> Interaction<Void, None, String> {
                    Interaction(.any, spy: super.doSomething)
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
            class ServiceMock: Mock, Service {
                func doSomething(with value: Int) {
                    return adapt(super.doSomething, value)
                }
                func doSomething(with value: ArgMatcher<Int>) -> Interaction<Int, None, Void> {
                    Interaction(value, spy: super.doSomething)
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
            class ServiceMock: Mock, Service {
                func doSomething() {
                    return adapt(super.doSomething)
                }
                func doSomething() -> Interaction<Void, None, Void> {
                    Interaction(.any, spy: super.doSomething)
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
            class LoggerMock: Mock, Logger {
                static func log(_ message: String) {
                    return adapt(super.log, message)
                }
                static func log(_ message: ArgMatcher<String>) -> Interaction<String, None, Void> {
                    Interaction(message, spy: super.log)
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
            class AnalyticsProtocolMock: Mock, AnalyticsProtocol {
                func logEvent<E: Identifiable>(_ event: E) -> Bool {
                    return adapt(super.logEvent, event)
                }
                func logEvent<E: Identifiable>(_ event: ArgMatcher<E>) -> Interaction<E, None, Bool> {
                    Interaction(event, spy: super.logEvent)
                }
            }
            #endif
            """
        }
    }
}
