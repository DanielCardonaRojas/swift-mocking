
# SwiftMocking

[![swift-version](https://img.shields.io/badge/swift-5.9-orange.svg)](https://img.shields.io/badge/swift-5.9-orange.svg)
[![platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)
[![license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://img.shields.io/badge/license-MIT-lightgrey.svg)

`SwiftMocking` is a modern, type-safe mocking library for Swift that uses macros to provide a clean, readable, and efficient mocking experience. It offers an elegant API that leverages the power of parameter packs and protocol witness structs provided by the companion package called [swift-witness](https://github.com/DanielCardonaRojas/swift-witness).

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

`SwiftMocking` builds upon the powerful [swift-witness](https://github.com/DanielCardonaRojas/swift-witness) library to do the heavy lifting.

1.  **Protocol Analysis with `@Witnessed`**: The `@Witnessed` macro from the [swift-witness](https://github.com/DanielCardonaRojas/swift-witness) is responsible for analyzing the protocol and providing a mechanism for synthesizing protocol conformances.

2.  **Mock Generation with `@Mockable`**: The `@Mockable` macro in this library then builds a witness value by passing in spies for each protocol requirement. These will power stubbing and spying of each protocol requirement.

This two-step process also enables different workflows. For example, you can annotate the protocol in your main target and generate both the witness which is useful for things other than testing and choose to generate the mock only in your test target. Or you can decide to generate both things in your main target. This enables that the core logic of protocol analysis is separate from the mock generation, and that your project only contains the code it needs for each specific target.

For a deeper understanding of protocol witnesses, please refer to the [swift-witness documentation](https://github.com/DanielCardonaRojas/ProtocolWitnessMacro?tab=readme-ov-file#-what-is-a-protocol-witness).

---

## 📦 Installation

To add `SwiftMocking` to your Swift package, add it as a dependency in your `Package.swift` file:

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

### Generated Code Examples

Here are some examples of how `@Mockable` expands different protocol definitions:

#### Basic Method

```swift
@Mockable()
protocol PricingService {
    func price(_ item: String) -> Int
}
```
<details>
<summary>Generated Code</summary>

```swift
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
```
</details>

#### Method with `throws`

```swift
@Mockable()
protocol PricingService {
    func price(_ item: String) throws -> Int
}
```
<details>
<summary>Generated Code</summary>

```swift
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
```
</details>

#### Method with `async`

```swift
@Mockable()
protocol PricingService {
    func price(_ item: String) async -> Int
}
```
<details>
<summary>Generated Code</summary>

```swift
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
```
</details>

#### Method with `async throws`

```swift
@Mockable()
protocol PricingService {
    func price(_ item: String) async throws -> Int
}
```
<details>
<summary>Generated Code</summary>

```swift
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
```
</details>

#### Multiple Methods

```swift
@Mockable()
protocol FeedService {
    func fetch(from url: URL) async throws -> Data
    func post(to url: URL, data: Data) async throws
}
```
<details>
<summary>Generated Code</summary>

```swift
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
```
</details>

#### Method with No Parameters and No Return

```swift
@Mockable()
protocol Service {
    func doSomething()
}
```
<details>
<summary>Generated Code</summary>

```swift
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
```
</details>

#### Macro Option: `.prefixMock`

```swift
@Mockable([.prefixMock])
protocol MyService {
    func doSomething()
}
```
<details>
<summary>Generated Code</summary>

```swift
protocol MyService {
    func doSomething()
}

struct MockMyService {
    typealias Witness = MyServiceWitness<Self>
    var instance: Witness.Synthesized {
        .init(context: self, witness: .init(doSomething: adapt(\.doSomething_)))
    }
    let doSomething_ = Spy<None, Void>()
    func doSomething() -> Interaction<None, Void> {
        Interaction(spy: doSomething_)
    }
}
```
</details>

#### Protocol with Associated Type

```swift
@Mockable()
protocol MyService {
    associatedtype Item
    func item() -> Item
}
```
<details>
<summary>Generated Code</summary>

```swift
protocol MyService {
    associatedtype Item
    func item() -> Item
}

struct MyServiceMock {
    typealias Witness = MyServiceWitness<Self>
    var instance: Witness.Synthesized {
        .init(context: self, witness: .init(item: adapt(\.item_)))
    }
    let item_ = Spy<None, Item>()
    func item() -> Interaction<None, Item> {
        Interaction(spy: item_)
    }
}
```
</details>
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
