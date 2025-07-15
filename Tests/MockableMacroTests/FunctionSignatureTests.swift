
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import MockableMacro
import MacroTesting

final class FunctionSignatureTests: XCTestCase {
    override func invokeTest() {
      withMacroTesting(
        record: false,
        macros: ["Mockable": MockableMacro.self]
      ) {
        super.invokeTest()
      }
    }

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

            class PricingServiceMock: Mock {
                typealias Witness = PricingServiceWitness<PricingServiceMock>
                var instance: Witness.Synthesized {
                    .init(
                        context: self,
                        witness: .init(
                            price: adaptNone(self, super.price)
                        )
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

            class PricingServiceMock: Mock {
                typealias Witness = PricingServiceWitness<PricingServiceMock>
                var instance: Witness.Synthesized {
                    .init(
                        context: self,
                        witness: .init(
                            price: adaptThrows(self, super.price)
                        )
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

            class PricingServiceMock: Mock {
                typealias Witness = PricingServiceWitness<PricingServiceMock>
                var instance: Witness.Synthesized {
                    .init(
                        context: self,
                        witness: .init(
                            price: adaptAsync(self, super.price)
                        )
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

            class PricingServiceMock: Mock {
                typealias Witness = PricingServiceWitness<PricingServiceMock>
                var instance: Witness.Synthesized {
                    .init(
                        context: self,
                        witness: .init(
                            price: adaptAsyncThrows(self, super.price)
                        )
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

            class FeedServiceMock: Mock {
                typealias Witness = FeedServiceWitness<FeedServiceMock>
                var instance: Witness.Synthesized {
                    .init(
                        context: self,
                        witness: .init(
                            fetch: adaptAsyncThrows(self, super.fetch),
                            post: adaptAsyncThrows(self, super.post)
                        )
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

            class ServiceMock: Mock {
                typealias Witness = ServiceWitness<ServiceMock>
                var instance: Witness.Synthesized {
                    .init(
                        context: self,
                        witness: .init(
                            doSomething: adaptNone(self, super.doSomething)
                        )
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

            class ServiceMock: Mock {
                typealias Witness = ServiceWitness<ServiceMock>
                var instance: Witness.Synthesized {
                    .init(
                        context: self,
                        witness: .init(
                            doSomething: adaptNone(self, super.doSomething)
                        )
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

            class ServiceMock: Mock {
                typealias Witness = ServiceWitness<ServiceMock>
                var instance: Witness.Synthesized {
                    .init(
                        context: self,
                        witness: .init(
                            doSomething: adaptNone(self, super.doSomething)
                        )
                    )
                }
                func doSomething() -> Interaction<None, Void> {
                    Interaction(spy: super.doSomething)
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

            class AnalyticsProtocolMock: Mock {
                typealias Witness = AnalyticsProtocolWitness<AnalyticsProtocolMock>
                var instance: Witness.Synthesized {
                    .init(
                        context: self,
                        witness: .init(
                            logEvent: adaptNone(self, super.logEvent)
                        )
                    )
                }
                func logEvent<E: Identifiable>(_ event: ArgMatcher<E>) -> Interaction<E, None, Bool> {
                    Interaction(event, spy: super.logEvent)
                }
            }
            """
        }
    }
}
