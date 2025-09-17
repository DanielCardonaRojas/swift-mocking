
# SwiftMocking

[![swift-version](https://img.shields.io/badge/swift-5.9-orange.svg)](https://img.shields.io/badge/swift-5.9-orange.svg)
[![platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-blue.svg)
[![license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://img.shields.io/badge/license-MIT-lightgrey.svg)
[![CI Status](https://github.com/DanielCardonaRojas/swift-mocking/actions/workflows/pull_request.yml/badge.svg)](https://github.com/DanielCardonaRojas/swift-mocking/actions/workflows/pull_request.yml)


`SwiftMocking` is a modern, type-safe mocking library for Swift that uses macros to provide a clean, readable, and efficient mocking experience. It offers an elegant API that leverages the power of [parameter packs](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0393-parameter-packs.md) and `@dynamicMemberLookup`.

---

*   [Features](#-features)
*   [Protocol Feature Support](#-protocol-feature-support)
*   [Installation](#-installation)
*   [Example](#-example)
*   [Documentation](#-documentation)
*   [Usage](#️-usage)
    *   [Argument Matching](#argument-matching)
    *   [Dynamic Stubbing with `then` Closure](#dynamic-stubbing-with-then-closure)
    *   [Testing Methods with Callbacks](#testing-methods-with-callbacks)
    *   [Logging Invocations](#logging-invocations)
    *   [Testing Methods with Callbacks](#testing-methods-with-callbacks)
    *   [Default Values for Unstubbed Methods](#default-values-for-unstubbed-methods)
    *   [Descriptive Error Reporting](#descriptive-error-reporting)
*   [How it Works](#️-how-it-works)
*   [Generated Code Examples](GENERATED_CODE_EXAMPLES.md)
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
| Variadic parameters | ✅ |
| Closure parameters | ✅ |
| Metatype parameters | ✅ |

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

## 🚀 Example

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

For detailed examples of how `@Mockable` expands different protocol definitions into mock implementations, see [Generated Code Examples](GENERATED_CODE_EXAMPLES.md).


## ⚡️ Usage

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

#### Range-Based Matching

```swift
// Using Swift's range syntax for more idiomatic matching
verify(mock.setVolume(.in(0...100))).called()        // ClosedRange: 0 through 100
verify(mock.validateAge(.in(18...))).called()        // PartialRangeFrom: 18 and above
verify(mock.setSpeed(.in(...65))).called()           // PartialRangeThrough: up to 65

// Collection count matching with ranges
verify(mock.processBatch(.hasCount(in: 5...10))).called()    // 5-10 items
verify(mock.handleLarge(.hasCount(in: 100...))).called()     // 100+ items
verify(mock.processSmall(.hasCount(in: ...3))).called()      // up to 3 items
```

#### Never Called Verification

```swift
// Verify a specific method was never called
verifyNever(mock.sensitiveMethod(password: .any))

// Verify a mock object had no interactions at all
let unusedMock = MockPricingService()
verifyZeroInteractions(unusedMock)  // Ensures mock was completely unused
```

#### Captured Argument Inspection

After verifying that methods were called, you can inspect the actual arguments that were passed using the `captured` method:

```swift
verify(mock.calculate(a: .any, b: .any))
    .captured { a, b in
        print("Called calculate with: a=\(a), b=\(b)")
        XCTAssertTrue(a + b > 0)
    }
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

### Dynamic Stubbing with `then` Closure


A powerful feature of `SwiftMocking` is that you can define the return value of a stub dynamically based on the arguments passed to the mocked function. This is achieved by providing a closure to `then`.

It is common in other testing frameworks, that the parameters of this closure be of type Any. However, thanks to the use of parameter packs, the set of arguments here are concrete types, and are guaranteed to match the types of the function signature that is being stubbed. This essentially enables substituting the mocked function dynamically. For example:

```swift
@Mockable
protocol Calculator {
    func calculate(a: Int, b: Int) -> Int
}

// Calculate summing
when(mock.calculate(a: .any, b: .any)).then { a, b in
    // Note that no casting is required. a and here are of type Int
    return a + b
}
XCTAssertEqual(mock.calculate(a: 5, b: 10), 15)

// Replace the calculation function
when(mock.calculate(a: .any, b: .any)).then(*)
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

### Testing Methods with Callbacks

`SwiftMocking` excels at testing methods that use completion handlers or callbacks. This is particularly useful for testing asynchronous operations like network requests, file I/O, or any method that takes a closure parameter.

When testing callbacks, use the `.any` matcher for the callback parameter and the `.then` closure to control how the callback is executed:

```swift
@Mockable
protocol NetworkService {
    func fetchUser(id: String, completion: @escaping (Result<User, Error>) -> Void)
}

func testNetworkServiceCallback() async {
    let mock = MockNetworkService()
    let expectation = XCTestExpectation()

    // Use .any matcher for the callback parameter
    when(mock.fetchUser(id: .equal("123"), completion: .any)).then { id, completion in
        // Control when and how the callback is executed
        completion(.success(User(id: id, name: "Test User")))
    }

    mock.fetchUser(id: "123") { result in
        switch result {
        case .success(let user):
            XCTAssertEqual(user.name, "Test User")
            expectation.fulfill()
        case .failure:
            XCTFail("Expected success")
        }
    }

    await fulfillment(of: [expectation], timeout: 1.0)
}
```

This pattern is invaluable for testing:
- Network operations with completion handlers
- File I/O operations
- Authentication services
- Database operations
- Event handlers and delegates
- Timer/delayed operations

**Important:** When testing methods with callbacks, always use the `.any` matcher for callback parameters, as it's the only matcher that makes sense for closure types.



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

## ⚙️ How it Works

`SwiftMocking` leverages the power of Swift macros to generate mock implementations of your protocols. When you apply the `@Mockable` macro to a protocol, it generates a new class that inherits from a `Mock` base class. This generated mock class conforms to the original protocol.

The `Mock` base class uses `@dynamicMemberLookup` to intercept method calls. This allows `SwiftMocking` to provide a dynamic and flexible mocking experience. The use of parameter packs ensures that all method calls are type-safe and that the mock stays in sync with the protocol definition.

This approach eliminates the need for manual mock implementations and provides a clean, expressive, and type-safe API for your tests.



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

