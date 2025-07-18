
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

            class PricingServiceMock: Mocking {
                typealias Witness = PricingServiceWitness<PricingServiceMock>
                typealias Conformance = Witness.Synthesized
                required override init() {
                    super.init()
                    self.setup()
                }
                lazy var instance: Conformance = .init(context: self, strategy: "mocking")
                var witness: Witness {
                    .init(
                        price: adaptNone(super.price)
                    )
                }
                func price(_ item: ArgMatcher<String>) -> Interaction<String, None, Int> {
                    Interaction(item, spy: super.price)
                }
            }
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

            class PricingServiceMock: Mocking {
                typealias Witness = PricingServiceWitness<PricingServiceMock>
                typealias Conformance = Witness.Synthesized
                required override init() {
                    super.init()
                    self.setup()
                }
                lazy var instance: Conformance = .init(context: self, strategy: "mocking")
                var witness: Witness {
                    .init(
                        price: adaptThrows(super.price)
                    )
                }
                func price(_ item: ArgMatcher<String>) -> Interaction<String, Throws, Int> {
                    Interaction(item, spy: super.price)
                }
            }
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

            class PricingServiceMock: Mocking {
                typealias Witness = PricingServiceWitness<PricingServiceMock>
                typealias Conformance = Witness.Synthesized
                required override init() {
                    super.init()
                    self.setup()
                }
                lazy var instance: Conformance = .init(context: self, strategy: "mocking")
                var witness: Witness {
                    .init(
                        price: adaptAsync(super.price)
                    )
                }
                func price(_ item: ArgMatcher<String>) -> Interaction<String, Async, Int> {
                    Interaction(item, spy: super.price)
                }
            }
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

            class PricingServiceMock: Mocking {
                typealias Witness = PricingServiceWitness<PricingServiceMock>
                typealias Conformance = Witness.Synthesized
                required override init() {
                    super.init()
                    self.setup()
                }
                lazy var instance: Conformance = .init(context: self, strategy: "mocking")
                var witness: Witness {
                    .init(
                        price: adaptAsyncThrows(super.price)
                    )
                }
                func price(_ item: ArgMatcher<String>) -> Interaction<String, AsyncThrows, Int> {
                    Interaction(item, spy: super.price)
                }
            }
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

            class FeedServiceMock: Mocking {
                typealias Witness = FeedServiceWitness<FeedServiceMock>
                typealias Conformance = Witness.Synthesized
                required override init() {
                    super.init()
                    self.setup()
                }
                lazy var instance: Conformance = .init(context: self, strategy: "mocking")
                var witness: Witness {
                    .init(
                        fetch: adaptAsyncThrows(super.fetch),
                        post: adaptAsyncThrows(super.post)
                    )
                }
                func fetch(from url: ArgMatcher<URL>) -> Interaction<URL, AsyncThrows, Data> {
                    Interaction(url, spy: super.fetch)
                }
                func post(to url: ArgMatcher<URL>, data: ArgMatcher<Data>) -> Interaction<URL, Data, AsyncThrows, Void> {
                    Interaction(url, data, spy: super.post)
                }
            }
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

            class ServiceMock: Mocking {
                typealias Witness = ServiceWitness<ServiceMock>
                typealias Conformance = Witness.Synthesized
                required override init() {
                    super.init()
                    self.setup()
                }
                lazy var instance: Conformance = .init(context: self, strategy: "mocking")
                var witness: Witness {
                    .init(
                        doSomething: adaptNone(super.doSomething)
                    )
                }
                func doSomething() -> Interaction<None, String> {
                    Interaction(spy: super.doSomething)
                }
            }
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

            class ServiceMock: Mocking {
                typealias Witness = ServiceWitness<ServiceMock>
                typealias Conformance = Witness.Synthesized
                required override init() {
                    super.init()
                    self.setup()
                }
                lazy var instance: Conformance = .init(context: self, strategy: "mocking")
                var witness: Witness {
                    .init(
                        doSomething: adaptNone(super.doSomething)
                    )
                }
                func doSomething(with value: ArgMatcher<Int>) -> Interaction<Int, None, Void> {
                    Interaction(value, spy: super.doSomething)
                }
            }
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

            class ServiceMock: Mocking {
                typealias Witness = ServiceWitness<ServiceMock>
                typealias Conformance = Witness.Synthesized
                required override init() {
                    super.init()
                    self.setup()
                }
                lazy var instance: Conformance = .init(context: self, strategy: "mocking")
                var witness: Witness {
                    .init(
                        doSomething: adaptNone(super.doSomething)
                    )
                }
                func doSomething() -> Interaction<None, Void> {
                    Interaction(spy: super.doSomething)
                }
            }
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

            class LoggerMock: Mocking {
                typealias Witness = LoggerWitness<LoggerMock>
                typealias Conformance = Witness.Synthesized
                required override init() {
                    super.init()
                    self.setup()
                }
                lazy var instance: Conformance = .init(context: self, strategy: "mocking")
                var witness: Witness {
                    .init(
                        log: Self.adaptNone(Super.log)
                    )
                }
                static func log(_ message: ArgMatcher<String>) -> Interaction<String, None, Void> {
                    Interaction(message, spy: super.log)
                }
            }
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

            class AnalyticsProtocolMock: Mocking {
                typealias Witness = AnalyticsProtocolWitness<AnalyticsProtocolMock>
                typealias Conformance = Witness.Synthesized
                required override init() {
                    super.init()
                    self.setup()
                }
                lazy var instance: Conformance = .init(context: self, strategy: "mocking")
                var witness: Witness {
                    .init(
                        logEvent: adaptNone(super.logEvent)
                    )
                }
                func logEvent(_ event: ArgMatcher<any Identifiable>) -> Interaction<any Identifiable, None, Bool> {
                    Interaction(event, spy: super.logEvent)
                }
            }
            """
        }
    }
}
