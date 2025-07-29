
# SwiftMocking

[![swift-version](https://img.shields.io/badge/swift-5.9-orange.svg)](https://img.shields.io/badge/swift-5.9-orange.svg)
[![platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-blue.svg)
[![license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://img.shields.io/badge/license-MIT-lightgrey.svg)
[![CI Status](https://github.com/DanielCardonaRojas/swift-mocking/actions/workflows/pull_request.yml/badge.svg)](https://github.com/DanielCardonaRojas/swift-mocking/actions/workflows/pull_request.yml)


`SwiftMocking` is a modern, type-safe mocking library for Swift that uses macros to provide a clean, readable, and efficient mocking experience. It offers an elegant API that leverages the power of parameter packs and `@dynamicMemberLookup`.

---

*   [Features](#-features)
*   [Protocol Feature Support](#-protocol-feature-support)
*   [Installation](#-installation)
*   [Usage](#-usage)
*   [Documentation](#-documentation)
*   [How it Works](#️-how-it-works)
*   [Advanced Usage](#️-advanced-usage)
*   [More Generated Code Examples](#more-generated-code-examples)
*   [Known Limitations](#️-known-limitations)

---

## ✨ Features

| Feature | Description |
| --- | --- |
| **Type-Safe Mocking** | Uses [parameter packs](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0393-parameter-packs.md) to keep mocks synchronized with protocol definitions, preventing runtime errors. |
| **Clean, Readable API** | Provides a Mockito-style API that makes tests expressive and easy to maintain. |
| **Flexible Argument Matching**| Offers powerful argument matchers like `.any` and `.equal`, with `ExpressibleBy...Literal` conformance for cleaner syntax. |
| **Effect-Safe Spies** | Models effects like `async` and `throws` as phantom types, ensuring type safety when stubbing. |
| **Compact Code Generation** | Keeps the generated code as small and compact as possible. |
| **Descriptive Error Reporting** | Provides clear and informative error messages when assertions fail, making it easier to debug tests. |
| **Options to configure the macro generated code** | Exposes the `MockableOptions` OptionSet that enables selecting what and how code gets generated. |
| **XCTest and Testing support** | SwiftMocking uses [swift-issue-reporting](https://github.com/pointfreeco/swift-issue-reporting) and exposes testing utilities to both XCTest and [swift-testing](https://github.com/swiftlang/swift-testing) frameworks. |

### Protocol Feature Support

| Feature | Supported |
| --- | :---: |
| Associated Types | ✅ |
| Variables | ✅ |
| Static Methods | ✅ |
| Generics | ✅ |
| Subscripts | ✅ |
| Initializers | ✅ |
| `async` Methods | ✅ |
| `throws` Methods | ✅ |

---

## 📦 Installation

To add `SwiftMocking` to your Swift package, add it as a dependency in your `Package.swift` file:

```swift
.package(url: "https://github.com/DanielCardonaRojas/swift-mocking.git", from: "0.1.0"),
```

Then, add `SwiftMocking` to your target's dependencies:

```swift
.target(
    name: "MyTests",
    dependencies: [
        .product(name: "SwiftMocking", package: "swift-mocking"),
    ]
),
```

---

## 🚀 Usage

For a comprehensive demonstration of `SwiftMocking`'s capabilities, including various mocking scenarios and advanced features, please refer to the [Examples](Examples/) project.

Here's an example of how to use `Mockable` to mock a `PricingService` protocol:

```swift
import SwiftMocking


@Mockable
protocol PricingService {
    func price(_ item: String) throws -> Int
}
```
<details>
<summary>Generated Code</summary>

```swift
class PricingServiceMock: Mock, PricingService {
    func price(_ item: String) throws -> Int {
        return try adaptThrowing(super.price, item)
    }
    func price(_ item: ArgMatcher<String>) -> Interaction<String, Throws, Int> {
        Interaction(item, spy: super.price)
    }
}
```
</details>


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
        let store = Store(pricingService: mock)

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

## 📚 Documentation

For more detailed information, please refer to the official [documentation](https://danielcardonarojas.github.io/swift-mocking/documentation/swiftmocking/).

---

## ⚙️ How it Works

`SwiftMocking` leverages the power of Swift macros to generate mock implementations of your protocols. When you apply the `@Mockable` macro to a protocol, it generates a new class that inherits from a `Mock` base class. This generated mock class conforms to the original protocol.

The `Mock` base class uses `@dynamicMemberLookup` to intercept method calls. This allows `SwiftMocking` to provide a dynamic and flexible mocking experience. The use of parameter packs ensures that all method calls are type-safe and that the mock stays in sync with the protocol definition.

This approach eliminates the need for manual mock implementations and provides a clean, expressive, and type-safe API for your tests.

---


## ⚡️ Advanced Usage

### Argument Matching

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
@Mockable
protocol Calculator {
    func calculate(a: Int, b: Int) -> Int
}

// Calculate summing
when(mock.calculate(a: .any, b: .any)).thenReturn { a, b in
    // Note that no casting is required. a and here are of type Int
    return a + b
}
XCTAssertEqual(mock.calculate(a: 5, b: 10), 15)

// Replace the calculation function
when(mock.calculate(a: .any, b: .any)).thenReturn(*)
XCTAssertEqual(mock.calculate(a: 5, b: 10), 50)
```

### Logging Invocations

`SwiftMocking` provides a simple way to log method invocations on your mock objects. This can be useful for debugging tests and understanding the flow of interactions. You can enable logging on a per-instance or per-type basis.

#### Enabling Logging for a Mock Instance

To enable logging for a specific mock instance, set the `isLoggingEnabled` property to `true`.

```swift
let mock = PricingServiceMock()
mock.isLoggingEnabled = true

// Any calls to mock.instance methods will now be logged to the console.
_ = mock.price(for: "apple")
// Output: PricingServiceMock.price("apple")
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
class PricingServiceMock: Mock, PricingService {
    func price(_ item: String) throws -> Int {
        return try adaptThrowing(super.price, item)
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
class PricingServiceMock: Mock, PricingService {
    func price(_ item: String) async -> Int {
        return await adapt(super.price, item)
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
class PricingServiceMock: Mock, PricingService {
    func price(_ item: String) async throws -> Int {
        return try await adaptThrowing(super.price, item)
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
class ServiceMock: Mock, Service {
    func doSomething() {
        return adapt(super.doSomething)
    }
    func doSomething() -> Interaction<Void, None, Void> {
        Interaction(.any, spy: super.doSomething)
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
class MockMyService: Mock, MyService {
    func doSomething() {
        return adapt(super.doSomething)
    }
    func doSomething() -> Interaction<Void, None, Void> {
        Interaction(.any, spy: super.doSomething)
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
class MyServiceMock<Item>: Mock, MyService {
    typealias Item = Item
    func item() -> Item {
        return adapt(super.item)
    }
    func item() -> Interaction<Void, None, Item> {
        Interaction(.any, spy: super.item)
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
class MyServiceMock: Mock, MyService {

    var value: Int {
        get {
            adapt(super.value)
        }
    }
    func getValue() -> Interaction<Void, None, Int > {
        Interaction(.any, spy: super.value)
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
class MyServiceMock: Mock, MyService {
    required init(value: Int) {
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
class MyServiceMock: Mock, MyService {
    subscript(index: Int) -> String {
        get {
            return adapt(super.subscript, index)
        }
    }
    subscript(index: ArgMatcher<Int>) -> Interaction<Int, None, String > {
        get {
            Interaction(index, spy: super.subscript)
        }
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
class ServiceMock: Mock, Service {
    func doSomething() {
        return adapt(super.doSomething)
    }
    func doSomething() -> Interaction<Void, None, Void> {
        Interaction(.any, spy: super.doSomething)
    }
}
```
</details>


## ⚠️ Known Limitations

### Xcode Autocomplete

Currently, Xcode's autocomplete feature may not work as expected when using the generated mock objects. This seems to be a known issue with Xcode. This limitation could be worked around by conforming to the mocked protocol within an extension. However due to limitations of Swift macros, generating this extension will result in an error.

For example, the ideal generated code would separate the protocol conformance into an extension, like this:

```swift
// Ideal generated code
public protocol PricingService {
    func price(_ item: String) throws -> Int
}

class PricingServiceMock: Mock {
    func price(_ item: ArgMatcher<String>) -> Interaction<String, Throws, Int> {
        Interaction(item, spy: super.price)
    }
}

extension PricingServiceMock: PricingService {
    func price(_ item: String) throws -> Int {
        return try adaptThrowing(super.price, item)
    }
}

```

Xcode's autocomplete will prioritize methods in the order they are declared. Since mocks are usualy not interacted with directly we opt for declaring the Interaction methods first.

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

