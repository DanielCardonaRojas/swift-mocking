
# Mockable 🐦

[![swift-version](https://img.shields.io/badge/swift-5.9-orange.svg)](https://img.shields.io/badge/swift-5.9-orange.svg)
[![platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)
[![license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://img.shields.io/badge/license-MIT-lightgrey.svg)

`Mockable` is a modern, type-safe mocking library for Swift that uses macros to provide a clean, readable, and efficient mocking experience. It offers an elegant API that leverages the power of parameter packs and protocol witness structs.

---

## ✨ Features

| Feature | Description |
| --- | --- |
| **Type-Safe Mocking** | Uses parameter packs to keep mocks synchronized with protocol definitions, preventing runtime errors. |
| **Clean, Readable API** | Provides a Mockito-style API that makes tests expressive and easy to maintain. |
| **No Preprocessor Macros** | Avoids `#if DEBUG` by using macros to generate code only where needed, resulting in a cleaner build process. |
| **Target-Specific Generation**| Generates protocol witnesses for your main target and synthesizes mock conformances for your test target. |
| **Flexible Argument Matching**| Offers powerful argument matchers like `.any` and `.equal`, with `ExpressibleBy...Literal` conformance for cleaner syntax. |
| **Effect-Safe Spies** | Models effects like `async` and `throws` as phantom types, ensuring type safety when stubbing. |
| **Compact Code Generation** | Keeps the generated code as small and compact as possible to minimize binary size. |
| **Descriptive Error Reporting** | Provides clear and informative error messages when assertions fail, making it easier to debug tests. |

---

## ⚙️ How it Works

`Mockable` builds upon the powerful `ProtocolWitnessMacro` library to do the heavy lifting.

1.  **Protocol Analysis with `@Witnessed`**: The `@Witnessed` macro from the dependency package is responsible for analyzing the protocol. It supports a wide variety of requirements, including functions with different effects (`async`, `throws`), properties, and subscripts. It generates a generic `protocol witness` struct for the protocol.

2.  **Mock Generation with `@Mockable`**: The `@Mockable` macro in this library then takes that protocol witness and generates the necessary mocking infrastructure. This includes:
    *   A `Spying` struct with spies for each protocol requirement.
    *   A typealias that connects the generic witness to the `Spying` struct.
    *   A static `new()` function to easily create a fully synthesized mock instance for your tests.

This two-step process ensures that the core logic of protocol analysis is separate from the mock generation, and that your project only contains the code it needs for each specific target.

For a deeper understanding of protocol witnesses, please refer to the [ProtocolWitnessMacro documentation](https://github.com/DanielCardonaRojas/ProtocolWitnessMacro?tab=readme-ov-file#-what-is-a-protocol-witness).

---

## 📦 Installation

To add `Mockable` to your Swift package, add it as a dependency in your `Package.swift` file:

```swift
.package(url: "https://github.com/DanielCardonaRojas/swift-mockito.git", from: "1.0.0"),
```

Then, add `Mockable` to your target's dependencies:

```swift
.target(name: "MyTarget", dependencies: ["Mockable"]),
```

---

## 🚀 Example

Here's an example of how to use `Mockable` to mock a `PricingService` protocol:

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
    typealias PricingServiceMockWitness = PricingServiceWitness<Spying>
    static func new() -> PricingServiceMockWitness.Synthesized {
        .init(
            context: .init(),
            witness: .init(price: adapt(\.price))
        )
    }
    public struct Spying {
        let price = Spy<String, None, Int>()
        func price(for item: ArgMatcher<String>) -> Interaction<String, None, Int> {
            Interaction.init(matchers: item, spy: price)
        }
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

---

## ⚡️ Advanced Usage

### Async and Throws

`Mockable` seamlessly handles `async` and `throws` functions.

```swift
@Mockable
protocol DataService {
    func fetchData() async throws -> Data
}
```

In your tests, you can stub throwing functions with `thenThrow` and `async` functions with `thenReturn`.

```swift
func testAsyncThrows() async throws {
    let mock = DataServiceMock.new()
    let spy = mock.context

    // Stub a successful result
    when(spy.fetchData()).thenReturn(Data())

    // Stub an error
    when(spy.fetchData()).thenThrow(URLError(.badURL))
}
```

### Descriptive Error Reporting

`Mockable` provides detailed error messages when a test assertion fails. For example, if you expect a function to be called 4 times but it was only called twice, you'll get a clear message indicating the discrepancy.

```swift
// Example of a failing test
verify(spy.price(for: .any)).called(4)
```

This will produce the following error:

```
error: Unfulfilled call count. Actual: 2
```

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
