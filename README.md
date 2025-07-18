
# SwiftMocking

[![swift-version](https://img.shields.io/badge/swift-5.9-orange.svg)](https://img.shields.io/badge/swift-5.9-orange.svg)
[![platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)
[![license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://img.shields.io/badge/license-MIT-lightgrey.svg)
[![CI Status](https://github.com/DanielCardonaRojas/swift-mocking/actions/workflows/pull_request.yml/badge.svg)](https://github.com/DanielCardonaRojas/swift-mocking/actions/workflows/pull_request.yml)


`SwiftMocking` is a modern, type-safe mocking library for Swift that uses macros to provide a clean, readable, and efficient mocking experience. It offers an elegant API that leverages the power of [parameter packs](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0393-parameter-packs.md) and protocol witness structs provided by the companion package called [swift-witness](https://github.com/DanielCardonaRojas/swift-witness).

---

## ✨ Features

| Feature | Description |
| --- | --- |
| **Type-Safe Mocking** | Uses [parameter packs](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0393-parameter-packs.md) to keep mocks synchronized with protocol definitions, preventing runtime errors. |
| **Clean, Readable API** | Provides a Mockito-style API that makes tests expressive and easy to maintain. |
| **No Preprocessor Macros** | Avoids `#if DEBUG` by using macros to generate code only where needed, resulting in a cleaner build process. |
| **Target-Specific Generation**| Allows generates protocol witnesses for your main target and synthesizes mock conformances for your test target. |
| **Flexible Argument Matching**| Offers powerful argument matchers like `.any` and `.equal`, with `ExpressibleBy...Literal` conformance for cleaner syntax. |
| **Effect-Safe Spies** | Models effects like `async` and `throws` as phantom types, ensuring type safety when stubbing. |
| **Compact Code Generation** | Keeps the generated code as small and compact as possible. |
| **Descriptive Error Reporting** | Provides clear and informative error messages when assertions fail, making it easier to debug tests. |
| **Options to configure the macro generated code** | Exposes the `MockableOptions` OptionSet that enables selecting what code gets generated . |

---

## 📦 Installation

To add `SwiftMocking` to your Swift package, add it as a dependency in your `Package.swift` file:

```swift
.package(url: "https://github.com/DanielCardonaRojas/swift-mocking.git", from: "0.1.0"),
```

---

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


```swift
import SwiftMocking
import XCTest

final class StoreTests: XCTestCase {
    func testItemRegistration() {
        let mock = PricingServiceMock()
        let store = Store(pricingService: mock.instance)

        // Stub specific calls
        when(mock.price(for: "apple")).thenReturn(13)
        when(mock.price(for: "banana")).thenReturn(17)

        store.register("apple")
        store.register("banana")

        // Verify that price was called twice with any string
        verify(mock.price(for: .any)).called(2) // .called(2) is equivalent to .called(.equal(2))

        XCTAssertEqual(store.prices["apple"], 13)
        XCTAssertEqual(store.prices["banana"], 17)
    }
}
```

---

## ⚙️ How it Works

`SwiftMocking` builds upon the powerful [swift-witness](https://github.com/DanielCardonaRojas/swift-witness) library to do the heavy lifting. `swift-witness` generates a struct with closures representing the protocol requirements. It also generates the code necessary to synthesize a protocol conformance (witness + Self). `swift-testing` takes advantage of this since it now only needs to create an instance of the witness and provide the correct context (the set of method spies that should be invoked).

1.  **Protocol Analysis with `@Witnessed`**: The `@Witnessed` macro from the [swift-witness](https://github.com/DanielCardonaRojas/swift-witness) is responsible for analyzing the protocol and providing a mechanism for synthesizing protocol conformances.

2.  **Mock Generation with `@Mockable`**: The `@Mockable` macro in this library then builds a witness value by passing in spies for each protocol requirement. These will power stubbing and spying of each protocol requirement.

This two-step process also enables different workflows. For example, you can annotate the protocol in your main target and generate both the witness which is useful for things other than testing and choose to generate the mock only in your test target. Or you can decide to generate both things in your main target. This enables that the core logic of protocol analysis is separate from the mock generation, and that your project only contains the code it needs for each specific target.

For a deeper understanding of protocol witnesses, please refer to the [swift-witness documentation](https://github.com/DanielCardonaRojas/ProtocolWitnessMacro?tab=readme-ov-file#-what-is-a-protocol-witness).

---


## 🚀 Example

Here's an example of how to use `Mockable` to mock a `PricingService` protocol:

```swift
import SwiftMocking

@Mockable
protocol PricingService {
    func price(for item: String) -> Int
}
```

### Generated Code

The `@Mockable` macro generates the following code:

```swift
struct PricingServiceMock {
    typealias Witness = PricingServiceWitness<Self>

    var instance: Witness.Synthesized {
        .init(context: self, witness: .init(price: adapt(self, super.price)))
    }

    func price(_ item: ArgMatcher<String>) -> Interaction<String, Throws, Int> {
        Interaction(item, spy: super.price)
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

## ⚡️ Advanced Usage

### Advanced Argument Matching

`Mockable` provides a rich set of argument matchers to precisely control stubbing and verification.

#### Matching Any Argument

```swift
// Stub a method to return a value regardless of the input string
when(mock.someMethod(.any)).thenReturn(10)

// Verify a method was called with any integer argument
verify(mock.anotherMethod(.any)).called()
```

#### Matching Specific Values (using `.equal` or literals)

```swift
// Stub a method to return 10 only when called with "specific"
when(mock.someMethod(.equal("specific"))).thenReturn(10)

// Verify a method was called exactly with 42 (using literal conformance)
verify(mock.anotherMethod(42)).called()
```

#### Matching Comparable Values (`.lessThan`, `.greaterThan`)

```swift
// Stub a method to return a value if the integer argument is less than 10
when(mock.processValue(.lessThan(10))).thenReturn("small")

// Verify a method was called with an integer argument greater than 100
verify(mock.processValue(.greaterThan(100))).called()
```

#### Matching Object Identity (`.identical`)

```swift
class MyObject {}
let obj = MyObject()

// Stub a method to return a value only when called with the exact instance 'obj'
when(mock.handleObject(.identical(obj))).thenReturn("same instance")
```

#### Matching Optional Values (`.notNil`, `.nil`)

```swift
// Verify a method was called with a non-nil optional string
verify(mock.handleOptional(.notNil())).called()

// Stub a method to return a default value when called with a nil optional integer
when(mock.handleOptional(.nil())).thenReturn(0)
```

#### Matching Errors (`.anyError`, `.error`)

```swift
enum MyError: Error { case invalid }

// Verify a method threw any error
verify(mock.performAction()).throws(.anyError())

// Verify a method threw an error of type MyError
verify(mock.processData()).throws(.error(MyError.self))
```

### Dynamic Stubbing with `thenReturn` Closure


A powerful feature of `SwiftMocking` is that you can define the return value of a stub dynamically based on the arguments passed to the mocked function. This is achieved by providing a closure to `thenReturn`.

It is common in other testing frameworks, that the parameters of this closure be of type Any. However, thanks to the use of parameter packs, the set of arguments here are concrete types, and are guaranteed to match the types of the function signature that is being stubbed. This essentially enables substituting the mocked function dynamically. For example:

```swift
@Mocked
protocol Calculator {
    func calculate(a: Int, b: Int) -> Int
}

// Calculate summing
when(mock.calculate(a: .any, b: .any)).thenReturn { a, b in
    // Note that no casting is required. a and here are of type Int
    return a + b
}
XCTAssertEqual(mock.instance.calculate(a: 5, b: 10), 15)

// Replace the calculation function
when(mock.calculate(a: .any, b: .any)).thenReturn(*)
XCTAssertEqual(mock.instance.calculate(a: 5, b: 10), 50)
```

### Default Values for Unstubbed Methods

`SwiftMocking` provides a mechanism to return default values for methods that have not been explicitly stubbed. This is achieved through the `DefaultProvidable` protocol and the `DefaultProvidableRegistry`.

-   **`DefaultProvidable` Protocol**: Types conforming to this protocol can provide a `defaultValue`.
-   **`DefaultProvidableRegistry`**: This registry manages and provides access to default values for registered `DefaultProvidable` types.

Without a mechanism to provide default/fallback values when a method is not stubbed, calling the mock would unavoidably result in a `fatalError`.

For this reason, and to providide a less rigid testing experience, generated mocks include a `defaultProviderRegistry` property. This provides the flexibility of not having to stub every combination of arguments of a function, for certain return types.


By default, common Swift types like `String`, `Int`, `Double`, `Float`, `Bool`, `Optional`, `Array`, `Dictionary`, and `Set` conform to `DefaultProvidable` and are automatically registered.

```swift
// Assuming MyServiceMock is generated by @Mockable macro
let mock = MyServiceMock()

// If 'fetchData' is not stubbed, and its return type (e.g., String) is DefaultProvidable,
// it will return the default value for String ("")
let data = mock.fetchData() // data will be ""
```

You can also register your custom types that conform to `DefaultProvidable`:

```swift
struct MyCustomType: DefaultProvidable {
    static var defaultValue: MyCustomType {
        return MyCustomType(name: "Default", value: 0)
    }
    let name: String
    let value: Int
}

// Register your custom type with the shared registry
DefaultProvidableRegistry.shared.register(MyCustomType.self)

// Now, if a method returns MyCustomType and is unstubbed, it will return MyCustomType.defaultValue
let customValue = mock.getCustomType() // customValue will be MyCustomType(name: "Default", value: 0)
```

### Descriptive Error Reporting

`Mockable` provides detailed error messages when a test assertion fails. For example, if you expect a function to be called 4 times but it was only called twice, you'll get a clear message indicating the discrepancy.

```swift
// Example of a failing test
verify(mock.price(for: .any)).called(4)
```

This will produce the following error:

```
error: Unfulfilled call count. Actual: 2
```

---

### More Generated Code Examples

Here are more examples of how `@Mockable` expands different protocol definitions:

#### Method with `throws`

```swift
@Mockable
protocol PricingService {
    func price(_ item: String) throws -> Int
}
```
<details>
<summary>Generated Code</summary>

```swift
class PricingServiceMock: Mock, MockWitnessContainer {
    typealias Witness = PricingServiceWitness<PricingServiceMock>
    typealias Conformance = PricingServiceWitness<PricingServiceMock>.Synthesized
    required override init() {
        super.init()
        self.setup()
    }
    lazy var instance: Conformance = .init(context: self, strategy: "mocking")
    var witness: Witness {
        .init(
            price: adaptThrows(self, super.price)
        )
    }
    func price(_ item: ArgMatcher<String>) -> Interaction<String, Throws, Int> {
        Interaction(item, spy: super.price)
    }
}
```
</details>

#### Method with `async`

```swift
@Mockable
protocol PricingService {
    func price(_ item: String) async -> Int
}
```
<details>
<summary>Generated Code</summary>

```swift
class PricingServiceMock: Mock, MockWitnessContainer {
    typealias Witness = PricingServiceWitness<PricingServiceMock>
    typealias Conformance = PricingServiceWitness<PricingServiceMock>.Synthesized
    required override init() {
        super.init()
        self.setup()
    }
    lazy var instance: Conformance = .init(context: self, strategy: "mocking")
    var witness: Witness {
        .init(
            price: adaptAsync(self, super.price)
        )
    }
    func price(_ item: ArgMatcher<String>) -> Interaction<String, Async, Int> {
        Interaction(item, spy: super.price)
    }
}
```
</details>

#### Method with `async throws`

```swift
@Mockable
protocol PricingService {
    func price(_ item: String) async throws -> Int
}
```
<details>
<summary>Generated Code</summary>

```swift
class PricingServiceMock: Mock, MockWitnessContainer {
    typealias Witness = PricingServiceWitness<PricingServiceMock>
    typealias Conformance = PricingServiceWitness<PricingServiceMock>.Synthesized
    required override init() {
        super.init()
        self.setup()
    }
    lazy var instance: Conformance = .init(context: self, strategy: "mocking")
    var witness: Witness {
        .init(
            price: adaptAsyncThrows(self, super.price)
        )
    }
    func price(_ item: ArgMatcher<String>) -> Interaction<String, AsyncThrows, Int> {
        Interaction(item, spy: super.price)
    }
}
```
</details>

#### Multiple Methods

```swift
@Mockable
protocol FeedService {
    func fetch(from url: URL) async throws -> Data
    func post(to url: URL, data: Data) async throws
}
```
<details>
<summary>Generated Code</summary>

```swift
class FeedServiceMock: Mock, MockWitnessContainer {
    typealias Witness = FeedServiceWitness<FeedServiceMock>
    typealias Conformance = FeedServiceWitness<FeedServiceMock>.Synthesized
    required override init() {
        super.init()
        self.setup()
    }
    lazy var instance: Conformance = .init(context: self, strategy: "mocking")
    var witness: Witness {
        .init(
            fetch: adaptAsyncThrows(self, super.fetch),
            post: adaptAsyncThrows(self, super.post)
        )
    }
    func fetch(from url: ArgMatcher<URL>) -> Interaction<URL, AsyncThrows, Data> {
        Interaction(url, spy: super.fetch)
    }
    func post(to url: ArgMatcher<URL>, data: ArgMatcher<Data>) -> Interaction<URL, Data, AsyncThrows, Void> {
        Interaction(url, data, spy: super.post)
    }
}
```
</details>

#### Method with No Parameters and No Return

```swift
@Mockable
protocol Service {
    func doSomething()
}
```
<details>
<summary>Generated Code</summary>

```swift
class ServiceMock: Mock, MockWitnessContainer {
    typealias Witness = ServiceWitness<ServiceMock>
    typealias Conformance = ServiceWitness<ServiceMock>.Synthesized
    required override init() {
        super.init()
        self.setup()
    }
    lazy var instance: Conformance = .init(context: self, strategy: "mocking")
    var witness: Witness {
        .init(
            doSomething: adaptNone(self, super.doSomething)
        )
    }
    func doSomething() -> Interaction<None, Void> {
        Interaction(spy: super.doSomething)
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
class MockMyService: Mock, MockWitnessContainer {
    typealias Witness = MyServiceWitness<MockMyService>
    typealias Conformance = MyServiceWitness<MockMyService>.Synthesized
    required override init() {
        super.init()
        self.setup()
    }
    lazy var instance: Conformance = .init(context: self, strategy: "mocking")
    var witness: Witness {
        .init(
            doSomething: adaptNone(self, super.doSomething)
        )
    }
    func doSomething() -> Interaction<None, Void> {
        Interaction(spy: super.doSomething)
    }
}
```
</details>

#### Protocol with Associated Type

```swift
@Mockable
protocol MyService {
    associatedtype Item
    func item() -> Item
}
```
<details>
<summary>Generated Code</summary>

```swift
class MyServiceMock<Item>: Mock, MockWitnessContainer {
    typealias Witness = MyServiceWitness<Item, MyServiceMock<Item>>
    typealias Conformance = MyServiceWitness<Item, MyServiceMock<Item>>.Synthesized
    required override init() {
        super.init()
        self.setup()
    }
    lazy var instance: Conformance = .init(context: self, strategy: "mocking")
    var witness: Witness {
        .init(
            item: adaptNone(self, super.item)
        )
    }
    func item() -> Interaction<None, Item> {
        Interaction(spy: super.item)
    }
}
```
</details>

#### Protocol with Property

```swift
@Mockable
protocol MyService {
    var value: Int { get }
}
```
<details>
<summary>Generated Code</summary>

```swift
class MyServiceMock: Mock, MockWitnessContainer {
    typealias Witness = MyServiceWitness<MyServiceMock>
    typealias Conformance = MyServiceWitness<MyServiceMock>.Synthesized
    required override init() {
        super.init()
        self.setup()
    }
    lazy var instance: Conformance = .init(context: self, strategy: "mocking")
    var witness: Witness {
        .init(
            value: adapt(self, super.value)
        )
    }
}
```
</details>

#### Protocol with Initializer

```swift
@Mockable
protocol MyService {
    init(value: Int)
}
```
<details>
<summary>Generated Code</summary>

```swift
class MyServiceMock: Mock, MockWitnessContainer {
    typealias Witness = MyServiceWitness<MyServiceMock>
    typealias Conformance = MyServiceWitness<MyServiceMock>.Synthesized
    required override init() {
        super.init()
        self.setup()
    }
    lazy var instance: Conformance = .init(context: self, strategy: "mocking")
    var witness: Witness {
        .init(
            init_value: adapt(Super.init)
        )
    }
}
```
</details>

#### Protocol with Subscript

```swift
@Mockable
protocol MyService {
    subscript(index: Int) -> String { get }
}
```
<details>
<summary>Generated Code</summary>

```swift
class MyServiceMock: Mock, MockWitnessContainer {
    typealias Witness = MyServiceWitness<MyServiceMock>
    typealias Conformance = MyServiceWitness<MyServiceMock>.Synthesized
    required override init() {
        super.init()
        self.setup()
    }
    lazy var instance: Conformance = .init(context: self, strategy: "mocking")
    var witness: Witness {
        .init(
            subscriptIndex: adapt(self, super.subscriptIndex)
        )
    }
}
```
</details>

#### Public Protocol

```swift
@Mockable
public protocol Service {
    func doSomething()
}
```
<details>
<summary>Generated Code</summary>

```swift
public class ServiceMock: Mock, MockWitnessContainer {
    public typealias Witness = ServiceWitness<ServiceMock>
    public typealias Conformance = ServiceWitness<ServiceMock>.Synthesized
    public required override init() {
        super.init()
        self.setup()
    }
    public lazy var instance: Conformance = .init(context: self, strategy: "mocking")
    public var witness: Witness {
        .init(
            doSomething: adaptNone(self, super.doSomething)
        )
    }
    public func doSomething() -> Interaction<None, Void> {
        Interaction(spy: super.doSomething)
    }
}
```
</details>


## 📚 Documentation

For more detailed information, please refer to the official [documentation](https://danielcardonarojas.github.io/swift-mocking/documentation/mockabletypes/).

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
