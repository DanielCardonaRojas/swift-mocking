
# SwiftMocking

[![swift-version](https://img.shields.io/badge/swift-6.0-orange.svg)](https://img.shields.io/badge/swift-6.0-orange.svg)
[![platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-blue.svg)
[![license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://img.shields.io/badge/license-MIT-lightgrey.svg)
[![CI Status](https://github.com/DanielCardonaRojas/swift-mocking/actions/workflows/pull_request.yml/badge.svg?branch=main)](https://github.com/DanielCardonaRojas/swift-mocking/actions/workflows/pull_request.yml?query=branch%3Amain)


`SwiftMocking` is a modern, type-safe mocking library for Swift that provides a clean, readable, and efficient mocking experience. It offers an elegant API that leverages the power of [parameter packs](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0393-parameter-packs.md) and `@dynamicMemberLookup`.

**Macros are optional.** The `@Mockable` macro is the most convenient way to get a mock, but it is not required, since mocks are ordinary Swift classes. You can generate them as written source with the [`mockable` CLI](#mock-generation-cli), or have an AI assistant write them for you with the [agent skill](#-agent-skill). Both produce the same code the macro does, without the compile-time plugin, and both handle cases the macro cannot (notably protocol inheritance).

---

*   [Features](#-features)
*   [Protocol Feature Support](#-protocol-feature-support)
*   [Installation](#-installation)
*   [Agent Skill & CLI](#-agent-skill)
*   [Example](#-example)
*   [Documentation](#-documentation)
*   [Usage](#️-usage)
    *   [Argument Matching](#argument-matching)
    *   [Verifying Call Order](#verifying-call-order-across-mocks)
    *   [Dynamic Stubbing](#dynamic-stubbing)
    *   [Logging Invocations](#logging-invocations)
    *   [Testing Methods with Callbacks](#testing-methods-with-callbacks)
    *   [Testing Closure-Based Dependencies](#testing-closure-based-dependencies)
    *   [Test Isolation for Concurrent Testing](#test-isolation-for-concurrent-testing)
    *   [Test-Scoped Default Values](#test-scoped-default-values)
    *   [Default Values for Unstubbed Methods](#default-values-for-unstubbed-methods)
    *   [Descriptive Error Reporting](#descriptive-error-reporting)
*   [Swift 6 and Sendable](#-swift-6-and-sendable)
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
| **Cross-Mock Call Order Verification** | Verify that method calls occurred in a specific sequence, even across different mock objects with `verifyInOrder()`. |
| **Effect-Safe Spies** | Models effects like `async` and `throws` as phantom types, ensuring type safety when stubbing. |
| **Compact Code Generation** | Keeps the generated code as small and compact as possible. |
| **Descriptive Error Reporting** | Provides clear and informative error messages when assertions fail, making it easier to debug tests. |
| **Options to configure the macro generated code** | Exposes the `MockableOptions` OptionSet that enables selecting what and how code gets generated. |
| **XCTest and Testing support** | SwiftMocking uses [swift-issue-reporting](https://github.com/pointfreeco/swift-issue-reporting) and exposes testing utilities to both XCTest and [swift-testing](https://github.com/swiftlang/swift-testing) frameworks. |
| **Test Isolation for Concurrency** | Provides isolation for concurrent test execution through [TaskLocal](https://www.hackingwithswift.com/quick-start/concurrency/how-to-create-and-use-task-local-values). |
| **Swift 6 Data-Race Safety** | Compiles in Swift 6 language mode. Mocks are `Sendable` and cross isolation domains freely; every stored closure is compiler-proven `@Sendable`. See [Swift 6 and Sendable](#-swift-6-and-sendable). |

### Protocol Feature Support

| Feature | Supported |
| --- | :---: |
| Associated Types | ✅ |
| Variables | ✅ |
| Static Methods | ✅ |
| Generics | ✅ |
| Subscripts | ✅ |
| `async` Methods | ✅ |
| `throws` Methods | ✅ |
| Variadic parameters | ✅ |
| Closure parameters | ✅ |
| Metatype parameters | ✅ |

---

## 📦 Installation

To add `SwiftMocking` to your Swift package, add it as a dependency in your `Package.swift` file:

```swift
.package(url: "https://github.com/DanielCardonaRojas/swift-mocking.git", from: "0.7.2"),
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

## 🤖 Agent Skill

An installable **agent skill** (`skills/swift-mocking/`) teaches AI coding assistants (Claude Code, Codex, Cursor, ...) to write correct SwiftMocking tests, including hand-written mocks for protocols with inheritance, which `@Mockable` does not support. It covers manual mock generation, `when`/`verify` patterns, the Swift 6 `Sendable` contract, and ships a generated `.swiftinterface` reference so the agent checks signatures instead of guessing.

Install with the [Skills CLI](https://skills.sh/):

```bash
npx skills add DanielCardonaRojas/swift-mocking@swift-mocking -g
```

Or symlink the directory into your agent's skills folder (`~/.claude/skills/` for Claude Code, `~/.agents/skills/` for Codex). Once installed it activates automatically; no prompt changes required.

### Mock Generation CLI

The `mockable` executable runs the same code generation as the `@Mockable` macro, outside the compiler. It reads protocol definitions from stdin and writes mock classes to stdout, which is useful for agents, codegen pipelines, or whenever you want the mock source materialized. Together with the skill, this means **you never have to apply the macro** to use this library, only `import SwiftMocking` for the runtime types.

Build the release binary once so startup is near-instant on every subsequent run:

```bash
swift build -c release --product mockable   # → .build/release/mockable
echo 'protocol PricingService { func price(_ item: String) throws -> Int }' | .build/release/mockable
```

Copy it onto your `PATH` (`cp .build/release/mockable /opt/homebrew/bin/`) to make it available everywhere. `swift run mockable` works too, but pays SwiftPM planning overhead each invocation.

- Output keeps the `#if DEBUG` wrapper the macro emits; pass `--no-debug-wrap` when pasting into a test target, since a wrapped mock would vanish under `swift test -c release`.
- Every top-level protocol in the input gets a mock, in declaration order.
- Warnings go to stderr; stdout only ever contains generated code. Exits non-zero with annotated diagnostics when the input does not parse or declares no protocol.

The skill's `.swiftinterface` files are generated from the compiled modules. Refresh them after changing public API with `./Scripts/generate-interface.sh`.

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
    func price(_ item: ArgMatcher<String>) -> Interaction<String, Throws, Int> {
        Interaction(item, spy: super.price)
    }
    func price(_ item: String) throws -> Int {
        return try adaptThrowing(super.price, item)
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

In your tests, you can use the generated `MockPricingService` to create a mock object and stub its functions.


```swift
import SwiftMocking
import XCTest

final class StoreTests: XCTestCase {
    func testItemRegistration() {
        let mock = MockPricingService()
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

#### Verifying Call Order Across Mocks

Verify that method calls occurred in a specific order, even across different mock objects:

```swift
let pricingMock = MockPricingService()
let analyticsMock = MockAnalyticsService()

when(pricingMock.price("apple")).thenReturn(13)

_ = try pricingMock.price("apple")
analyticsMock.logEvent("purchase")
_ = try pricingMock.price("banana")

// Verify the sequence of calls across both mocks
verifyInOrder([
    pricingMock.price("apple"),
    analyticsMock.logEvent("purchase"),
    pricingMock.price("banana")
])
```

### Properties and Subscripts

Read-only requirements behave like any other member. **Settable** requirements (`{ get set }`) record reads and writes on two separate spies, because their argument lists differ: a write is the read's arguments plus the assigned value. Both are reached through a single interaction member:

```swift
@Mockable
protocol Settings {
    var isEnabled: Bool { get set }
    subscript(key: String) -> Int { get set }
}

let mock = MockSettings()

// Reads: stub and verify exactly like a method
when(mock.isEnabled).thenReturn(true)
when(mock[.any]).thenReturn(0)

XCTAssertTrue(mock.isEnabled)
verify(mock.isEnabled).called(1)

// Writes: the `<-` operator turns the interaction into a write interaction
mock.isEnabled = false
mock["retries"] = 3

verify(mock.isEnabled <- false).called(1)
verify(mock[.equal("retries")] <- 3).called(1)
verifyNever(mock.isEnabled <- true)
```

Reads and writes are counted independently: `verify(mock.isEnabled)` counts only reads, and a write never registers as a read.

Because a write records the read's arguments followed by the assigned value, captured arguments and stub closures take the value last:

```swift
verify(mock[.any] <- .any).captured { key, newValue in
    XCTAssertEqual(key, "retries")
    XCTAssertEqual(newValue, 3)
}

when(mock.isEnabled <- .any).thenReturn { _, newValue in
    print("isEnabled set to \(newValue)")
}
```

Since `<-` yields an ordinary `Interaction`, writes compose with `verifyInOrder` too. One toolchain caveat: for a **multi-index** subscript, bind the write before verifying it (`let write = mock[.equal(1), .equal(2)] <- "v"; verify(write).called(1)`), as forwarding the result directly into `verify` fails to infer.

### Dynamic Stubbing


A powerful feature of `SwiftMocking` is that you can define the return value of a stub dynamically based on the arguments passed to the mocked function. This is achieved by providing a closure to `thenReturn`.

It is common in other testing frameworks, that the parameters of this closure be of type Any. However, thanks to the use of parameter packs, the set of arguments here are concrete types, and are guaranteed to match the types of the function signature that is being stubbed. This essentially enables substituting the mocked function dynamically. For example:

```swift
@Mockable
protocol Calculator {
    func calculate(a: Int, b: Int) -> Int
}

// Calculate summing
when(mock.calculate(a: .any, b: .any)).thenReturn { a, b in
    // Note that no casting is required, a and b are of type Int.
    return a + b
}
XCTAssertEqual(mock.calculate(a: 5, b: 10), 15)

// Replace the calculation function
when(mock.calculate(a: .any, b: .any)).thenReturn(*)
XCTAssertEqual(mock.calculate(a: 5, b: 10), 50)
```

### Arranging Side Effects with `do`

Every `when(...)` call returns an arrangement object that can both stub return values and register side effects. Use `.do { … }` when you need to observe or mutate state without altering the stubbed response:

```swift
var events: [String] = []

when(mock.refresh(id: .equal("primary"))).do { id in
    events.append("refresh called with \(id)")
}

when(mock.refresh(id: .equal("primary"))).then()

mock.refresh(id: "primary")
XCTAssertEqual(events, ["refresh called with primary"])
```

For `Void`-returning interactions you can use the convenience alias `then { … }` instead of calling `thenReturn(())`. This keeps call sites concise while still allowing the same effect-specific APIs (throwing, async, async-throwing) shown above.

### Logging Invocations

`SwiftMocking` provides a simple way to log method invocations on your mock objects. This can be useful for debugging tests and understanding the flow of interactions. You can enable logging on a per-instance or per-type basis.

#### Enabling Logging for a Mock Instance

To enable logging for a specific mock instance, set the `isLoggingEnabled` property to `true`.

```swift
let mock = MockPricingService()
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


**Important:** When testing methods with callbacks, always use the `.any` matcher for callback parameters, as it's the only matcher that makes sense for closure types.

### Waiting for Asynchronous Interactions

When a system under test triggers a dependency inside a detached task, you can wait for the interaction with the `until` helper.

```swift
struct Controller {
    let refresh: (String) async throws -> Void

    func start() {
        Task {
            try await Task.sleep(for: .milliseconds(25))
            try await refresh("primary")
        }
    }
}

func testControllerRefreshesInBackground() async throws {
    let spy = Spy<String, AsyncThrows, Void>()
    let sut = Controller(refresh: adapt(spy))
    sut.start()
    try await until(spy("primary"))
    verify(spy("primary")).called()
}
```


### Testing Closure-Based Dependencies

`SwiftMocking` also supports testing systems that use closures as dependencies instead of protocols. This is particularly useful for projects using The Composable Architecture (TCA) from Point-Free or similar dependency injection approaches.

```swift
// Define a struct with closure-based dependencies
struct FetchClient {
    var loadNumber: () async throws -> [Int]
    var saveNumber: (Int) async throws -> Void
}

func testClosureBasedDependencies() async throws {
    // Create spies for each closure
    let loadNumberSpy = Spy<Void, AsyncThrows, [Int]>()
    let saveNumberSpy = Spy<Int, AsyncThrows, Void>()

    // Stub the behaviors
    when(loadNumberSpy(.any)).thenReturn([1, 2, 3])
    when(saveNumberSpy(.any)).then { number in
        print("Saving number: \(number)")
    }

    // Create the client with adapted spies
    let client = FetchClient(
        loadNumber: adapt(loadNumberSpy),
        saveNumber: adapt(saveNumberSpy)
    )

    // Use the client
    let numbers = try await client.loadNumber()
    try await client.saveNumber(42)

    // Verify interactions
    XCTAssertEqual(numbers, [1, 2, 3])
    verify(loadNumberSpy(.any)).called(1)
    verify(saveNumberSpy(42)).called(1)
}
```

This approach provides the same testing capabilities as protocol-based mocking but works with closure-based dependency injection patterns. The `adapt()` function converts a `Spy` into a closure that can be used directly as a dependency.

### Test Isolation for Concurrent Testing

SwiftMocking provides test isolation to ensure concurrent tests don't interfere with each other when using static mocks. This is essential for Swift Testing which runs tests in parallel by default.

- **XCTest**: Inherit from `MockingTestCase` instead of `XCTestCase` for automatic spy isolation
- **Swift Testing**: Use the `@Test(.mocking)` trait to enable test scoping

Without proper isolation, concurrent tests can experience race conditions where static spies accumulate calls from multiple tests, making verification assertions unpredictable.

### Test-Scoped Default Values

SwiftMocking provides a powerful trait-based system for injecting custom default values that are scoped to individual tests or test suites. This allows you to provide specific default return values for unstubbed mock methods within the scope of a test execution.

#### Using .withDefaults Trait

```swift
import Testing
import SwiftMocking

@Test(.withDefaults("Test User", 42, true))
func testWithCustomDefaults() {
    let mock = MockUserService()

    // Unstubbed methods return the custom defaults
    let name = mock.getUserName()     // Returns "Test User"
    let age = mock.getUserAge()       // Returns 42
    let isActive = mock.isUserActive() // Returns true

    #expect(name == "Test User")
    #expect(age == 42)
    #expect(isActive == true)
}
```

#### Suite-Level Default Values

Apply default values to an entire test suite:

```swift
@Suite(.withDefaults("Default User"))
struct UserServiceTests {
    @Test
    func testUserCreation() {
        let mock = MockUserService()
        let name = mock.getUserName() // Returns "Default User"
    }

    @Test(.withDefaults("Override User"))
    func testWithOverride() {
        let mock = MockUserService()
        let name = mock.getUserName() // Returns "Override User"
    }
}
```

#### Benefits

- **Test Isolation**: Each test gets its own isolated default value scope
- **Concrete Values**: Use actual instances instead of static default implementations
- **Type Safety**: Compile-time validation ensures type correctness
- **Flexible**: Different tests can have different defaults for the same types
- **Composable**: Works seamlessly with other traits like `.mocking`

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

## 🔒 Swift 6 and Sendable

`SwiftMocking` is fully Swift 6 data-race safe. The library compiles in Swift 6 language mode, and every closure it stores and later invokes across isolation domains is compiler-proven `@Sendable`.

### Mocks are Sendable

`Mock` and `Spy` are `@unchecked Sendable`, backed by real `NSLock` synchronization rather than annotation alone. All spy storage, stubs, invocations, and configuration are locked on both read and write paths. Generated mocks inherit the conformance, so:

```swift
@Mockable
protocol Loader: Sendable {          // ✅ a mock satisfies a `: Sendable` requirement
    func load(_ id: Int) async -> String
}

let mock = MockLoader()
when(mock.load(.any)).thenReturn("value")

// Share the mock across isolation domains, no warnings in Swift 6 mode
await withTaskGroup(of: String.self) { group in
    for id in 0..<10 {
        group.addTask { await mock.load(id) }   // ✅ captured in a @Sendable closure
    }
}
```

Hand-written mocks should restate the conformance: `class LoaderMock: Mock, @unchecked Sendable, Loader`.

### The `@Sendable` contract

Value-based stubbing constrains its values; closure-based stubbing constrains its captures.

| API | Requirement |
| --- | --- |
| `thenReturn(value)` | `Output: Sendable` |
| `thenThrow(error)` | `E: Error & Sendable` |
| `thenReturn { ... }` / `.do { ... }` | closure is `@Sendable`, so **captures** must be Sendable |
| Value-capturing matchers (`.equal`, `.identical`, `.contains`, `.in`, `.approximately`) | argument type `: Sendable` |
| `.any`, `.any(that:)` | unconstrained; predicates may *take* non-Sendable values |
| Default values for unstubbed returns | unconstrained |

### Working with non-Sendable types

A `@Sendable` closure may *return* a non-Sendable value; it just cannot *capture* one. So construct the value inside the handler:

```swift
// ❌ requires Receipt: Sendable
when(mock.send(.any)).thenReturn(receipt)

// ✅ constructed inside the handler, no capture
when(mock.send(.any)).thenReturn { _ in Receipt(code: 42) }

// ✅ same trick for throwing a non-Sendable error
when(mock.validate(.any)).thenReturn { _ in throw ValidationError(reason: "invalid") }
```

To match a non-Sendable argument, capture a Sendable stand-in instead of the instance:

```swift
let targetID = target.id                      // UUID is Sendable
when(mock.send(.any(that: { $0.id == targetID }))).thenReturn { _ in Receipt(code: 0) }
```

**One boundary to know:** the handler overloads for `throws`, `async`, and `async throws` spies are declared `where repeat each I: Sendable`, because they defer the invocation, so the *arguments* must be Sendable too. The handler workarounds above therefore apply as written only to synchronous, non-throwing requirements. If a requirement both `throws` (or is `async`) **and** takes a non-Sendable parameter, no handler form compiles; make the parameter type `Sendable`, or restructure the requirement to take a Sendable stand-in (an ID) instead of the object.

Mocking protocols whose requirements use non-Sendable types is otherwise fully supported; the constraints above apply only to what you hand the stubbing APIs.

### Swift 5 consumers

The toolchain floor is Swift 6.0 (Xcode 16+), unchanged. Language mode is per-module, so a target building in **Swift 5 mode** can import the library unchanged: `Sendable` *constraints* still apply (they are type-system requirements), but `@Sendable` capture violations surface as warnings rather than errors. A `Swift5CompatTests` target verifies this path continuously.

### Migration notes

If you are upgrading from a pre-Sendable version:

1. Handler closures capturing non-Sendable state no longer compile in Swift 6 mode. Construct values inside the handler, or wrap shared state in a lock or actor.
2. `thenReturn(value)`/`thenThrow` on non-Sendable types: switch to the handler form above.
3. `.any(that: { ... })` may need an explicit `@Sendable` in some positions, since inference does not always propagate through the member chain.
4. `Recorded` is no longer `Sendable` (its `arguments: [Any]` payload cannot soundly claim transfer); consume `InvocationRecorder.snapshot()` within a single isolation domain.

---

## ⚙️ How it Works

`SwiftMocking` leverages the power of Swift macros to generate mock implementations of your protocols. When you apply the `@Mockable` macro to a protocol, it generates a new class that inherits from a `Mock` base class. This generated mock class conforms to the original protocol.

A Spy has this structure:

```swift
let spy = Spy<ParamType1, ParamType2, ParamTypeN, Effect, ReturnType>()

// So for example:

// Represents a function signature: (Bool, Int) async throws -> String?
let methodSpy = Spy<Bool, Int, AsyncThrows, Optional<String>>()

```

The use of parameter packs here allows creating any number of parmeter types `ParamType1 ... ParamTypeN`.

This approach eliminates the need for manual mock implementations and provides a clean, expressive, and type-safe API for your tests.



## ⚠️ Known Limitations

### Protocol Inheritance

`@Mockable` does not generate inherited requirements. For `protocol B: A` where `A` declares members, the generated mock fails to conform (`error: type 'BMock' does not conform to protocol 'A'`). Workaround: hand-write the mock. The [Agent Skill](#-agent-skill) teaches the exact recipe, or see [GENERATED_CODE_EXAMPLES.md](GENERATED_CODE_EXAMPLES.md) for the code shapes to mirror.

### Zero-Parameter Members and Property Getters

In macro-generated mocks, stubbing zero-parameter methods (`when(mock.f()).thenReturn(v)`) and property getters (`when(mock.getX()).thenReturn(v)`) is silently ignored, and verification of those members always counts 0, because a parameter-pack shape mismatch creates a second, disconnected spy. Setters and members with one or more parameters are unaffected. Workaround: hand-write those members with the pinned-spy form documented in the [Agent Skill](#-agent-skill).


### Colliding Spy Names

Spies are keyed by a name derived from the requirement: a method uses its own name, a subscript is namespaced as `subscript` + its parameter names in camelCase (`subscript(row:column:)` → `subscriptRowColumn`), and a settable member adds a `set`-prefixed write spy. Argument labels do not contribute.

The subscript prefix means a subscript never collides with a method or variable of the same name. Most ways two requirements could derive the same key are already rejected by the compiler: two subscripts differing only by argument label are an `invalid redeclaration of 'subscript(_:)'`, since subscript labels do not participate in the signature, and a `var value` alongside a `func value()` is an `invalid redeclaration of 'value'`.

The case that compiles but does not mock correctly is two **methods** that differ only by argument label:

```swift
@Mockable
protocol CollisionService {
    func fetch(id: Int) -> String
    func fetch(name: Int) -> String   // ⚠️ both derive the spy `fetch`
}
```

This is legal Swift, but because labels do not reach the spy name and both have the same signature, the two requirements share one spy: stubbing one answers calls to the other, and verification counts both. Nothing fails; the test quietly tests the wrong thing. Workaround: rename one method, or give the parameters distinct types so the spy signatures differ.

Overloads that differ in signature (`func fetch(_ id: Int)` and `func fetch(_ id: String)`) are **not** a collision and work fine: `Mock` stores a list per key and matches on type. A method and a subscript sharing a name (`func index(_:)` alongside `subscript(index:)`) are separated by the prefix.

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
