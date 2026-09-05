
# SwiftMocking

[![Swift](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FDanielCardonaRojas%2Fswift-mocking%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/DanielCardonaRojas/swift-mocking)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FDanielCardonaRojas%2Fswift-mocking%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/DanielCardonaRojas/swift-mocking)
[![license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)
[![CI Status](https://github.com/DanielCardonaRojas/swift-mocking/actions/workflows/pull_request.yml/badge.svg?branch=main)](https://github.com/DanielCardonaRojas/swift-mocking/actions/workflows/pull_request.yml?query=branch%3Amain)


`SwiftMocking` is a modern, type-safe mocking library for Swift that provides a clean, readable, and efficient mocking experience. It offers an elegant API that leverages the power of [parameter packs](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0393-parameter-packs.md) and `@dynamicMemberLookup`.

**Macros are optional.** The `@Mockable` macro is the most convenient way to get a mock, but it is not required, since mocks are ordinary Swift classes. You can generate them as written source with the [`mockable` CLI](#mock-generation-cli), or have an AI assistant write them for you with the [agent skill](#-agent-skill), with surprisingly short code.

The CLI shares its generator with the macro, so it produces the same output and has the same blind spots — it is a way to get the code *as source*, not a way to get more of it. For what the generator cannot express at all (protocol inheritance, mocking classes, types that cannot inherit `Mock`), the escape hatch is writing the mock yourself against `Spy` and `Mock` directly — which the [agent skill](#-agent-skill) documents in full.

---

*   [Features](#-features)
*   [Protocol Feature Support](#protocol-feature-support)
*   [Installation](#-installation)
*   [Agent Skill & CLI](#-agent-skill)
*   [Example](#-example)
*   [Documentation](#-documentation)
*   [Protocol Inheritance](#-protocol-inheritance-is-not-supported-by-macros)
*   [Swift 6 and Sendable](#-swift-6-and-sendable)
*   [How it Works](#-how-it-works)

---

## ✨ Features

| Feature | Description |
| --- | --- |
| **Type-Safe Mocking** | Uses [parameter packs](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0393-parameter-packs.md) to keep mocks synchronized with protocol definitions, preventing runtime errors. |
| **Clean, Readable API** | Provides a Mockito-style API that makes tests expressive and easy to maintain. |
| **Flexible Argument Matching**| Offers powerful argument matchers like `.any` and `.equal`, with `ExpressibleBy...Literal` conformance for cleaner syntax. |
| **Cross-Mock Call Order Verification** | Verify that method calls occurred in a specific sequence, even across different mock objects with `verifyInOrder()`. |
| **Effect-Safe Spies** | Models effects like `async` and `throws` as phantom types, ensuring type safety when stubbing. Typed throws (`throws(E)`) carry the declared error type, so stubbing the wrong error is a compile error. See the [Usage Reference](docs/usage.md#typed-throws). |
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
| `throws(E)` (typed throws) | ✅ |
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

Because it is the same generator, its output has the same limits as the macro's: it drops requirements inherited from a parent protocol (warning on stderr) and emits the zero-parameter shape described in [Known Limitations](docs/limitations.md). Treat it as a starting point to hand-adjust, not as a superset of the macro.

Build the release binary once so startup is near-instant on every subsequent run:

```bash
swift build -c release --product mockable   # → .build/release/mockable
echo 'protocol PricingService { func price(_ item: String) throws -> Int }' | .build/release/mockable
```

The input needs no annotation — a bare protocol is mocked as-is. Pass `--options` to choose a generation strategy for protocols you cannot annotate, such as one vended by a library you don't own:

```bash
# A class-constrained protocol needs `.composition`; the default inheriting
# strategy cannot mock it, since Mock would claim the one superclass slot.
echo 'protocol Service: UIViewController { func load() }' | mockable --options composition
```

`--options` takes a comma-separated list (`--options composition,suffixMock`) and accepts the same names as the macro's attribute. It supplies the default only: a protocol carrying an explicit `@Mockable([...])` keeps the options written there.

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

**New here?** The interactive tutorials are the fastest way in. They build the
example above into a full test suite, one runnable step at a time:

| Tutorial | Covers |
| --- | --- |
| [Mock Your First Protocol](https://danielcardonarojas.github.io/swift-mocking/tutorials/swiftmocking/mocking-your-first-protocol/) | `@Mockable`, stubbing with `when`, verifying with `verify` |
| [Match Arguments Precisely](https://danielcardonarojas.github.io/swift-mocking/tutorials/swiftmocking/matching-arguments/) | `.any`, exact values, ranges, predicates, capturing arguments |
| [Stub Dynamically](https://danielcardonarojas.github.io/swift-mocking/tutorials/swiftmocking/dynamic-stubbing/) | Computed returns, stub ordering, side effects, callback APIs |
| [Verify Every Interaction](https://danielcardonarojas.github.io/swift-mocking/tutorials/swiftmocking/verifying-interactions/) | Call counts, cross-mock ordering, debugging failures |

Reference material:

| Document | Contents |
| --- | --- |
| [Usage Reference](docs/usage.md) | Full matcher catalog, properties and subscripts, closure dependencies, default values, test isolation |
| [Swift 6 and Sendable](docs/swift6-sendable.md) | The `@Sendable` contract, non-Sendable workarounds, Swift 5 consumers, migration notes |
| [Known Limitations](docs/limitations.md) | Protocol inheritance, zero-parameter members, Xcode autocomplete |
| [Generated Code Examples](GENERATED_CODE_EXAMPLES.md) | How `@Mockable` expands each protocol feature |

The [API documentation](https://danielcardonarojas.github.io/swift-mocking/documentation/swiftmocking/) covers every public type.

---

## ⚠️ Protocol Inheritance Is Not Supported by Macros

**`@Mockable` does not generate inherited requirements.** For `protocol B: A`, the generated mock implements only `B`'s own members and fails to compile:

```
error: type 'BMock' does not conform to protocol 'A'
```

This is a hard limit of the Swift macro system, not an oversight: a macro sees only the single declaration it is attached to, so `A`'s requirements are invisible to it. Annotating `A` with `@Mockable` too does not help, because each expansion still runs in isolation.

**The `mockable` CLI does not work around this.** It shares the same `MockableGenerator`, so it drops inherited requirements exactly as the macro does — it warns on stderr and emits a mock that will not conform:

```
warning: mock for protocol 'B' does not implement requirements inherited from 'A' and may fail to conform
```

The fix is to write the mock yourself. A mock is an ordinary class over `Mock` and `Spy`, so flattening the chain by hand — a runtime member and an `ArgMatcher` interaction member for every requirement of every protocol in the chain — is mechanical and short:

```swift
class MockB: Mock, @unchecked Sendable, B {
    func a() -> Int { adapt(super.a, ()) }                      // inherited from A
    func a() -> Interaction<Void, None, Int> { Interaction(.any, spy: super.a) }

    func b() -> String { adapt(super.b, ()) }                   // B's own
    func b() -> Interaction<Void, None, String> { Interaction(.any, spy: super.b) }
}
```

Generating the base with the CLI and then adding the inherited members by hand is a reasonable shortcut. **[The agent skill](#-agent-skill)** teaches an AI assistant to do the whole thing, and documents the same `Spy`/`Mock` techniques for the other cases the generator cannot reach — mocking classes, and composing a `Mock` property when a type cannot inherit from `Mock` (an existing superclass, or a struct or actor).

See [Known Limitations](docs/limitations.md) for the remaining macro caveats.

---

## 🔒 Swift 6 and Sendable

`SwiftMocking` compiles in Swift 6 language mode. Mocks are `Sendable` and cross isolation domains freely, backed by real `NSLock` synchronization:

```swift
let mock = MockLoader()
when(mock.load(.any)).thenReturn("value")

await withTaskGroup(of: String.self) { group in
    for id in 0..<10 {
        group.addTask { await mock.load(id) }   // ✅ no warnings in Swift 6 mode
    }
}
```

The stubbing APIs carry `Sendable` constraints, and non-Sendable types have documented workarounds. See the [Swift 6 and Sendable guide](docs/swift6-sendable.md).

---

## ⚙️ How it Works

`SwiftMocking` leverages the power of Swift macros to generate mock implementations of your protocols. When you apply the `@Mockable` macro to a protocol, it generates a new class that inherits from a `Mock` base class that acts as a factory for spies. This generated mock class conforms to the original protocol.

At the heart of the system is the Spy type, which uses parameter packs to model any function signature and protocol requirement:

```swift
let spy = Spy<ParamType1, ParamType2, ParamTypeN, Effect, ReturnType>()

// So for example:

// Represents a function signature: (Bool, Int) async throws -> String?
let methodSpy = Spy<Bool, Int, AsyncThrows, Optional<String>>()

```

Every protocol requirement is backed by a `Spy` and tracked internally by the `Mock` base class, allowing the expanded code to remain compact.

The use of parameter packs here allows creating any number of parmeter types `ParamType1 ... ParamTypeN`.
This approach eliminates the need for manual mock implementations and provides a clean, expressive, and type-safe API for your tests.

See this [article](https://dev.to/danielcardonarojas/swiftmocking-rethinking-test-doubles-with-modern-swift-3hoa)

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
