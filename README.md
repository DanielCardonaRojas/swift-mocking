# Mockable

Mockable is a modern, type-safe mocking library for Swift that leverages the power of parameter packs and protocol witnesses to provide a clean, readable, and efficient mocking experience.

| Feature | Description |
| --- | --- |
| **Type-Safe Mocking** | Utilizes parameter packs to keep mocks perfectly synchronized with protocol definitions, preventing runtime errors. |
| **Clean, Readable API** | Offers a Mockito-style API that makes tests expressive and easy to maintain. |
| **No Preprocessor Macros** | Avoids `#if DEBUG` by using macros to generate code only where needed, resulting in a cleaner and more reliable build process. |
| **Target-Specific Generation**| Generates protocol witnesses for your main target and synthesizes mock conformances for your test target, ensuring only useful code is added to each. |
| **Flexible Argument Matching**| Provides powerful argument matchers like `.any` and `.equal`. Conformance to `ExpressibleBy...Literal` protocols allows for cleaner syntax, such as using `called(2)` instead of `called(.equal(2))`. |
| **Effect-Safe Spies** | Models effects like `async` and `throws` as phantom types, ensuring that you can only stub throwing functions with throwing implementations, for example. |
| **Compact Code Generation** | A key goal of this library is to keep the generated code as small and compact as possible, minimizing the impact on your project's binary size. |

## How it Works

Mockable builds upon the powerful [ProtocolWitnessMacro](https://github.com/DanielCardonaRojas/ProtocolWitnessMacro) library to do the heavy lifting.

1.  **Protocol Analysis with `@Witnessed`**: The `@Witnessed` macro from the dependency package is responsible for analyzing the protocol. It supports a wide variety of requirements, including functions with different effects (`async`, `throws`), properties, and subscripts. It generates a generic `protocol witness` struct for the protocol.

2.  **Mock Generation with `@Mockable`**: The `@Mockable` macro in this library then takes that protocol witness and generates the necessary mocking infrastructure. This includes:
    *   A `Spying` struct with spies for each protocol requirement.
    *   A typealias that connects the generic witness to the `Spying` struct.
    *   A static `new()` function to easily create a fully synthesized mock instance for your tests.

This two-step process ensures that the core logic of protocol analysis is separate from the mock generation, and that your project only contains the code it needs for each specific target.

## Example

Here's an example of how to use Mockable to mock a `PricingService` protocol:

```swift
@Mockable
protocol PricingService {
    func price(for item: String) -> Int
}
```

### Generated Code

The `@Mockable` macro generates the following code within your **test target**:

```swift
public struct PricingServiceMock {
    public struct Spying {
        let price = Spy<String, None, Int>()
        func price(for item: ArgMatcher<String>) -> Interaction<String, None, Int> {
            Interaction.init(matchers: item, spy: price)
        }
    }
    typealias PricingServiceMockWitness = PricingServiceWitness<Spying>
    static func new() -> PricingServiceMockWitness.Synthesized {
        .init(
            context: .init(),
            witness: .init(price: adapt(\.price))
        )
    }
}
```

The `@Witnessed` macro (used by `@Mockable` under the hood) generates the protocol witness. This code would typically be placed in your main **application target**, allowing you to use it for dependency injection.

```swift
struct PricingServiceWitness<A> {
    var price: (A, String) -> Int

    struct Synthesized: PricingService {
        let context: A
        let witness: PricingServiceWitness

        func price(for item: String) -> Int {
            witness.price(context, item)
        }
    }
}
```

### Usage

Here is an example of a `Store` class that uses the `PricingService`.

```swift
class Store {
    var items: [String] = []
    var prices: [String: Int] =  [:]
    let pricingService: any PricingService
    init<Service: PricingService>(pricingService: Service) {
        self.pricingService = pricingService
    }

    func register(_ item: String) {
        items.append(item)
        let price = pricingService.price(for: item)
        prices[item] = price
    }
}
```

In your tests, you can use the generated `PricingServiceMock` to create a mock object and stub its functions.

Note the use of argument matchers like `.any` and how `called(2)` is used instead of `called(.equal(2))` thanks to `ExpressibleByIntegerLiteral` conformance.

```swift
import Mockable
import XCTest

final class MockitoTests: XCTestCase {
    func testMock() {
        let mock = PricingServiceMock.new()
        let spy = mock.context
        let store = Store(pricingService: mock)

        // Stub specific calls
        when(spy.price(for: "apple")).thenReturn(13)
        when(spy.price(for: "banana")).thenReturn(17)

        store.register("apple")
        store.register("banana")

        // Verify that price was called twice with any string
        verify(spy.price(for: .any)).called(2) // .called(2) is equivalent to .called(.equal(2))

        XCTAssertEqual(store.prices["apple"], 13)
        XCTAssertEqual(store.prices["banana"], 17)
    }
}
```
