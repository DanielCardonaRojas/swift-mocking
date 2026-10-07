# Generated Code Examples

Here are some examples of how `@Mockable` macro expands for different protocol definitions:

## Basic Method Signatures

### Method with `throws`

```swift
@Mockable
protocol PricingService {
    func price(_ item: String) throws -> Int
}
```
<details>
<summary>Generated Code</summary>

```swift
class PricingServiceMock: Mock, @unchecked Sendable, PricingService {
    func price(_ item: String) throws -> Int {
        return try adaptThrowing(super.price, item)
    }
    func price(_ item: ArgMatcher<String>) -> Interaction<String, Throws, Int> {
        Interaction(item, spy: super.price)
    }
}
```
</details>

### Method with `async`

```swift
@Mockable
protocol PricingService {
    func price(_ item: String) async -> Int
}
```
<details>
<summary>Generated Code</summary>

```swift
class PricingServiceMock: Mock, @unchecked Sendable, PricingService {
    func price(_ item: String) async -> Int {
        return await adapt(super.price, item)
    }
    func price(_ item: ArgMatcher<String>) -> Interaction<String, Async, Int> {
        Interaction(item, spy: super.price)
    }
}
```
</details>

### Method with `async throws`

```swift
@Mockable
protocol PricingService {
    func price(_ item: String) async throws -> Int
}
```
<details>
<summary>Generated Code</summary>

```swift
class PricingServiceMock: Mock, @unchecked Sendable, PricingService {
    func price(_ item: String) async throws -> Int {
        return try await adaptThrowing(super.price, item)
    }
    func price(_ item: ArgMatcher<String>) -> Interaction<String, AsyncThrows, Int> {
        Interaction(item, spy: super.price)
    }
}
```
</details>

### Method with typed `throws(E)`

The declared error type is carried into the spy as `TypedThrows<E>`, so the conformance keeps its `throws(E)` signature instead of widening to `any Error`.

```swift
@Mockable
protocol PricingService {
    func price(_ item: String) throws(PricingError) -> Int
}
```
<details>
<summary>Generated Code</summary>

```swift
class PricingServiceMock: Mock, @unchecked Sendable, PricingService {
    func price(_ item: String) throws(PricingError) -> Int {
        let typedSpy: Spy<String, TypedThrows<PricingError>, Int> = super.price
        return try adaptTypedThrowing(typedSpy, item)
    }
    func price(_ item: ArgMatcher<String>) -> Interaction<String, TypedThrows<PricingError>, Int> {
        Interaction(item, spy: super.price)
    }
}
```
</details>

The spy is bound to an explicitly typed local first. The adapter's error type appears only in its `throws(E)` clause and in the spy's effect, and the spy itself comes from a generic subscript — with nothing spelled, both stay open and the compiler reports `generic parameter 'E' could not be inferred`.

Two spellings keep the untyped behaviour, since they mean the same thing as their untyped forms: `throws(any Error)` generates a `Throws` spy, and `throws(Never)` generates a `None` spy whose member needs no `try`.

### Method with `async throws(E)`

```swift
@Mockable
protocol PricingService {
    func price(_ item: String) async throws(PricingError) -> Int
}
```
<details>
<summary>Generated Code</summary>

```swift
class PricingServiceMock: Mock, @unchecked Sendable, PricingService {
    func price(_ item: String) async throws(PricingError) -> Int {
        let typedSpy: Spy<String, AsyncTypedThrows<PricingError>, Int> = super.price
        return try await adaptAsyncTypedThrowing(typedSpy, item)
    }
    func price(_ item: ArgMatcher<String>) -> Interaction<String, AsyncTypedThrows<PricingError>, Int> {
        Interaction(item, spy: super.price)
    }
}
```
</details>

## Complex Protocol Features

### Multiple Methods

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
class FeedServiceMock: Mock, @unchecked Sendable, FeedService {
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

### Method with No Parameters and No Return

```swift
@Mockable
protocol Service {
    func doSomething()
}
```
<details>
<summary>Generated Code</summary>

```swift
class ServiceMock: Mock, @unchecked Sendable, Service {
    func doSomething() {
        return adapt(super.doSomething, ())
    }
    func doSomething() -> Interaction<Void, None, Void> {
        Interaction(.any, spy: super.doSomething)
    }
}
```
</details>

## Macro Configuration Options

### Macro Option: `.prefixMock`

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
        return adapt(super.doSomething, ())
    }
    func doSomething() -> Interaction<Void, None, Void> {
        Interaction(.any, spy: super.doSomething)
    }
}
```
</details>

### Macro Option: `.composition`

By default the mock *inherits* `Mock` and reaches its spies through `super`. That is impossible when the mock must already inherit something else — most notably a protocol carrying a class constraint, since Swift permits only one superclass. `.composition` makes the mock **hold** a `Mock` in a stored `mock` property instead, freeing the superclass slot.

Note the three differences from the inheriting strategy: the mock inherits `SampleBase` rather than `Mock`, spies are reached through `self.mock` rather than `super`, and it calls the *static* `Mock.adapt` — a composing type inherits no instance adapters. The generated mock also conforms to `MockProviding`, so `verifyZeroInteractions` works with either strategy.

```swift
@Mockable([.composition])
protocol MyService: SampleBase {
    func doSomething()
}
```
<details>
<summary>Generated Code</summary>

```swift
class MockMyService: SampleBase, MyService, MockProviding, @unchecked Sendable {
    let mock = Mock()

    func doSomething() -> Interaction<Void, None, Void> {
        Interaction(.any, spy: self.mock.doSomething)
    }

    func doSomething() {
        return Mock.adapt(self.mock.doSomething, ())
    }
}
```
</details>

Without this option that protocol cannot be mocked at all — the generated class fails with `requires that 'MockMyService' inherit from 'SampleBase'`.

#### Composition without a class constraint

A composed protocol with no inheritance clause has no superclass to restate, so the mock becomes `final` and conforms to plain `Sendable` rather than `@unchecked Sendable`. The two go together: a non-final class cannot conform to `Sendable`, and a `Sendable` class cannot inherit another class. Here the conformance is *checked* rather than asserted — the mock's only storage is `let mock`, so the compiler rejects any mutable stored property.

```swift
@Mockable([.composition])
protocol MyService {
    func doSomething()
}
```
<details>
<summary>Generated Code</summary>

```swift
final class MockMyService: MyService , MockProviding, Sendable {
    let mock = Mock()

    func doSomething() -> Interaction<Void, None, Void> {
        Interaction(.any, spy: self.mock.doSomething)
    }

    func doSomething() {
        return Mock.adapt(self.mock.doSomething, ())
    }
}
```
</details>

#### Composition with a settable property

A settable property is where the two strategies diverge most visibly. The setter interaction is built inside an escaping closure, so it reaches the write spy through a captured `self.mock` rather than through `super`, and both accessors call the static `Mock.adapt`.

```swift
@Mockable([.composition])
protocol MyService: SampleBase {
    var value: Int { get set }
}
```
<details>
<summary>Generated Code</summary>

```swift
class MockMyService: SampleBase, MyService, MockProviding, @unchecked Sendable {
    let mock = Mock()

    func value(_ void: Void = ()) -> SettableInteraction<Void, None, Int > {
        SettableInteraction(
            get: Interaction(.any, spy: self.mock.value),
            setInteraction: { newValue in
                let writeSpy: Spy<Void, Int, None, Void> = self.mock.setValue
                let writeInteraction: Interaction<Void, Int, None, Void> = Interaction(.any, newValue, spy: writeSpy)
                return writeInteraction
            }
        )
    }

    var value: Int {
        set {
            return Mock.adapt(self.mock.setValue, (), newValue)
        }
        get {
            Mock.adapt(self.mock.value, ())
        }
    }
}
```
</details>

#### Composition with static requirements

Static members cannot reach an instance property, so a composed protocol with static requirements gets a *second* `Mock` for them. It carries the mock's own type name as its scoped storage key, so those spies land in `MockScope` — isolated by `.mocking` exactly like an inheriting mock's static spies, and reachable by `MockProviding`'s static `clear()`.

```swift
@Mockable([.composition])
protocol MyService: SampleBase {
    static func reset()
}
```
<details>
<summary>Generated Code</summary>

```swift
class MockMyService: SampleBase, MyService, MockProviding, @unchecked Sendable {
    let mock = Mock()

    static let staticMock = Mock(scopedStorageKey: "MockMyService")

    static func reset() -> Interaction<Void, None, Void> {
        Interaction(.any, spy: staticMock.reset)
    }

    static func reset() {
        return Mock.adapt(staticMock.reset, ())
    }
}
```
</details>

### Actor-inheriting protocols

A protocol inheriting `Actor` is mocked as an `actor` — no option required. No class can conform to such a protocol (`non-actor type 'MockSession' cannot conform to the 'Actor' protocol`), and an actor cannot inherit `Mock`, so the composed strategy is used automatically.

`Actor` is dropped from the restated inheritance clause and no `Sendable` conformance is emitted: an actor conforms to `Actor` by being one and is implicitly `Sendable`. `final` is absent because an actor cannot be `final`.

Every instance member is `nonisolated`. Without it the witness is actor-isolated, which compiles at the declaration and then fails at every synchronous call site (`call to actor-isolated instance method 'ping' in a synchronous nonisolated context`), making `when`/`verify` `await`-only.

```swift
@Mockable()
protocol Session: Actor {
    func ping() -> Bool
}
```
<details>
<summary>Generated Code</summary>

```swift
actor MockSession: Session, MockProviding {
    nonisolated let mock = Mock()

    nonisolated func ping() -> Interaction<Void, None, Bool> {
        Interaction(.any, spy: self.mock.ping)
    }

    nonisolated func ping() -> Bool {
        return Mock.adapt(self.mock.ping, ())
    }
}
```
</details>

#### Actor with static requirements

Members of an actor's type are already nonisolated, so static members carry no added modifier — and neither does `staticMock`.

```swift
@Mockable()
protocol Session: Actor {
    static func reset()
}
```
<details>
<summary>Generated Code</summary>

```swift
actor MockSession: Session, MockProviding {
    nonisolated let mock = Mock()

    static let staticMock = Mock(scopedStorageKey: "MockSession")

    static func reset() -> Interaction<Void, None, Void> {
        Interaction(.any, spy: staticMock.reset)
    }

    static func reset() {
        return Mock.adapt(staticMock.reset, ())
    }
}
```
</details>

#### Actor with an initializer requirement

Initializers omit `required` (`'required' initializer in non-class type`) and chain to no superclass, since an actor is a root type. The synthesized zero-argument `init()` is still emitted.

```swift
@Mockable()
protocol Session: Actor {
    init(value: Int)
}
```
<details>
<summary>Generated Code</summary>

```swift
actor MockSession: Session, MockProviding {
    nonisolated let mock = Mock()

    static let staticMock = Mock(scopedStorageKey: "MockSession")

    static func `init`(value: ArgMatcher<Int>) -> Interaction<Int, None, Void> {
        Interaction(value, spy: staticMock.`init`)
    }

    init(value: Int) {
        let spy: Spy<Int, None, Void> = MockSession.staticMock.`init`
        Mock.adapt(spy, value)
    }

    init() {
    }
}
```
</details>

## Advanced Protocol Features

### Protocol with Associated Type

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
        return adapt(super.item, ())
    }
    func item() -> Interaction<Void, None, Item> {
        Interaction(.any, spy: super.item)
    }
}
```
</details>

### Protocol with Property

```swift
@Mockable
protocol MyService {
    var value: Int { get }
}
```
<details>
<summary>Generated Code</summary>

```swift
class MockMyService: Mock, @unchecked Sendable, MyService {
    func value(_ void: Void = ()) -> Interaction<Void, None, Int > {
        Interaction(.any, spy: super.value)
    }

        var value: Int {
        get {
            adapt(super.value, ())
        }
    }
}
```
</details>

### Protocol with Settable Property

A settable requirement records reads and writes on two spies (`value` and `setValue`) — their input packs differ, since a write is the read pack plus the written value. One interaction member returns a `SettableInteraction` carrying both.

```swift
@Mockable
protocol MyService {
    var value: Int { get set }
}
```
<details>
<summary>Generated Code</summary>

```swift
class MockMyService: Mock, @unchecked Sendable, MyService {
    func value(_ void: Void = ()) -> SettableInteraction<Void, None, Int > {
        SettableInteraction(
            get: Interaction(.any, spy: super.value),
            setInteraction: { newValue in
                let writeSpy: Spy<Void, Int, None, Void> = super.setValue
                let writeInteraction: Interaction<Void, Int, None, Void> = Interaction(.any, newValue, spy: writeSpy)
                return writeInteraction
            }
        )
    }

        var value: Int {
        set {
            return adapt(super.setValue, (), newValue)
        }
        get {
            adapt(super.value, ())
        }
    }
}
```
</details>

Usage: `when(mock.value).thenReturn(7)` stubs reads, `verify(mock.value <- 7).called(1)` verifies writes.

### Protocol with Subscript

The spy name is `subscript` followed by the parameter names in camelCase — `subscript(index:)` → `subscriptIndex`, `subscript(row:column:)` → `subscriptRowColumn`. The prefix keeps subscript spies from colliding with a method or variable of the same name.

```swift
@Mockable
protocol MyService {
    subscript(index: Int) -> String { get }
}
```
<details>
<summary>Generated Code</summary>

```swift
class MockMyService: Mock, @unchecked Sendable, MyService {
    subscript(index: ArgMatcher<Int>) -> Interaction<Int, None, String > {
        get {
            Interaction(index, spy: super.subscriptIndex)
        }
    }
    subscript(index: Int) -> String {
        get {
            return adapt(super.subscriptIndex, index)
        }
    }
}
```
</details>

### Protocol with Settable Subscript

```swift
@Mockable
protocol MyService {
    subscript(index: Int) -> String { get set }
}
```
<details>
<summary>Generated Code</summary>

```swift
class MockMyService: Mock, @unchecked Sendable, MyService {
    subscript(index: ArgMatcher<Int>) -> SettableInteraction<Int, None, String > {
        get {
            SettableInteraction(
                get: Interaction(index, spy: super.subscriptIndex),
                setInteraction: { newValue in
                    Interaction(index, newValue, spy: super.setSubscriptIndex)
                }
            )
        }
    }
    subscript(index: Int) -> String {
        set {
            return adapt(super.setSubscriptIndex, index, newValue)
        }
        get {
            return adapt(super.subscriptIndex, index)
        }
    }
}
```
</details>

Usage: `when(mock[.any]).thenReturn("v")` stubs reads, `verify(mock[.equal(1)] <- "v").called(1)` verifies writes.

### Public Protocol

```swift
@Mockable
public protocol Service {
    func doSomething()
}
```
<details>
<summary>Generated Code</summary>

```swift
class ServiceMock: Mock, @unchecked Sendable, Service {
    func doSomething() {
        return adapt(super.doSomething, ())
    }
    func doSomething() -> Interaction<Void, None, Void> {
        Interaction(.any, spy: super.doSomething)
    }
}
```
</details>
