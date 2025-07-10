
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
            #"""
            protocol PricingService {
                func price(_ item: String) -> Int
            }

            struct PricingServiceMock {
                typealias Witness = PricingServiceWitness<Self>
                var instance: Witness.Synthesized {
                    .init(context: self, witness: .init(price: adapt(\.price)))
                }
                let price = Spy<String, None, Int>()
                func price(_ item: ArgMatcher<String>) -> Interaction<String, None, Int> {
                    Interaction(item, spy: price)
                }
            }
            """#
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
            #"""
            protocol PricingService {
                func price(_ item: String) throws -> Int
            }

            struct PricingServiceMock {
                typealias Witness = PricingServiceWitness<Self>
                var instance: Witness.Synthesized {
                    .init(context: self, witness: .init(price: adapt(\.price)))
                }
                let price = Spy<String, Throws, Int>()
                func price(_ item: ArgMatcher<String>) -> Interaction<String, Throws, Int> {
                    Interaction(item, spy: price)
                }
            }
            """#
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
            #"""
            protocol PricingService {
                func price(_ item: String) async -> Int
            }

            struct PricingServiceMock {
                typealias Witness = PricingServiceWitness<Self>
                var instance: Witness.Synthesized {
                    .init(context: self, witness: .init(price: adapt(\.price)))
                }
                let price = Spy<String, Async, Int>()
                func price(_ item: ArgMatcher<String>) -> Interaction<String, Async, Int> {
                    Interaction(item, spy: price)
                }
            }
            """#
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
            #"""
            protocol PricingService {
                func price(_ item: String) async throws -> Int
            }

            struct PricingServiceMock {
                typealias Witness = PricingServiceWitness<Self>
                var instance: Witness.Synthesized {
                    .init(context: self, witness: .init(price: adapt(\.price)))
                }
                let price = Spy<String, AsyncThrows, Int>()
                func price(_ item: ArgMatcher<String>) -> Interaction<String, AsyncThrows, Int> {
                    Interaction(item, spy: price)
                }
            }
            """#
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
            #"""
            protocol FeedService {
                func fetch(from url: URL) async throws -> Data
                func post(to url: URL, data: Data) async throws
            }

            struct FeedServiceMock {
                typealias Witness = FeedServiceWitness<Self>
                var instance: Witness.Synthesized {
                    .init(context: self, witness: .init(fetch: adapt(\.fetch), post: adapt(\.post)))
                }
                let fetch = Spy<URL, AsyncThrows, Data>()
                func fetch(from url: ArgMatcher<URL>) -> Interaction<URL, AsyncThrows, Data> {
                    Interaction(url, spy: fetch)
                }
                let post = Spy<URL, Data, AsyncThrows, Void>()
                func post(to url: ArgMatcher<URL>, data: ArgMatcher<Data>) -> Interaction<URL, Data, AsyncThrows, Void> {
                    Interaction(url, data, spy: post)
                }
            }
            """#
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
            #"""
            protocol Service {
                func doSomething() -> String
            }

            struct ServiceMock {
                typealias Witness = ServiceWitness<Self>
                var instance: Witness.Synthesized {
                    .init(context: self, witness: .init(doSomething: adapt(\.doSomething_)))
                }
                let doSomething_ = Spy<None, String>()
                func doSomething() -> Interaction<None, String> {
                    Interaction(spy: doSomething_)
                }
            }
            """#
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
            #"""
            protocol Service {
                func doSomething(with value: Int)
            }

            struct ServiceMock {
                typealias Witness = ServiceWitness<Self>
                var instance: Witness.Synthesized {
                    .init(context: self, witness: .init(doSomething: adapt(\.doSomething)))
                }
                let doSomething = Spy<Int, None, Void>()
                func doSomething(with value: ArgMatcher<Int>) -> Interaction<Int, None, Void> {
                    Interaction(value, spy: doSomething)
                }
            }
            """#
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
            #"""
            protocol Service {
                func doSomething()
            }

            struct ServiceMock {
                typealias Witness = ServiceWitness<Self>
                var instance: Witness.Synthesized {
                    .init(context: self, witness: .init(doSomething: adapt(\.doSomething_)))
                }
                let doSomething_ = Spy<None, Void>()
                func doSomething() -> Interaction<None, Void> {
                    Interaction(spy: doSomething_)
                }
            }
            """#
        }
    }
}
