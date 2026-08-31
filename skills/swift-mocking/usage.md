# SwiftMocking Usage Reference

API reference for `import SwiftMocking` tests (pair with swift-testing `import Testing` or `import XCTest`). For hand-written mocks see manual-mocking.md; for concurrency rules see sendable.md.

## Mock lifecycle

```swift
let mock = MyServiceMock()                    // generated: @Mockable protocol MyService
when(mock.fetch(id: .any)).thenReturn(value)  // arrange — stub BEFORE use
let out = try await sut.fetch(id: "1")        // act — direct call routes through the spy
verify(mock.fetch(id: .equal("1"))).called(1) // assert
```

- Stub **before** the call; later `when(...)` on the same matcher overwrites.
- `mock.clear()` (instance) / `MyMock.clear()` (static) in `tearDown` — mandatory for static mocks.
- Unstubbed calls fall back to the default-value registry (below). Only when the return type has **no** registered provider does the call fail: throwing members throw `MockingError.unStubbed`, non-throwing members trap (`fatalError` surfaced at the call site).

## Default values for unstubbed calls

`DefaultProvidableRegistry.default` is pre-populated, so a member returning one of these types **needs no stub at all** to be callable:

| Return type | Default |
|---|---|
| `Void` | returns (no stub ever needed) |
| `Bool` | `false` |
| `String` | `""` |
| `Int`, `Double`, `Float` | `0` |
| `Array`, `Set`, `Dictionary` | empty |
| `Optional` | `nil` |

Providers match the *generic* type, not the element: `[CustomType]` → `[]` and `CustomType?` → `nil` both resolve even though `CustomType` itself has no provider.

**Never write `.thenReturn(())`.** `Void` is registered, so an unstubbed `-> Void` member already does the right thing — just call it and verify:

```swift
let svc: MyService = mock
svc.log("hi")                          // no when(...) needed
verify(mock.log(.equal("hi"))).called(1)
```

Stub a `Void` member only to attach behavior — `when(mock.log(.any)).thenThrow(...)` for the failure path, or `.do { ... }` for a side effect. `thenReturn(())` adds nothing over the default.

Bare `Int`/`String`/`Bool`/collection returns still usually deserve an explicit `thenReturn` — the default is a silent `0`/`""`/`false`, which passes assertions for the wrong reason. Lean on the defaults for members the test doesn't care about; stub the ones it does.

Custom defaults, when a type isn't registered or the zero value is wrong:

```swift
// Per test / suite (swift-testing, Swift 6.1+) — values inferred from what you pass
@Suite(.withDefaults("Default Name"))
struct UserServiceTests {
    @Test(.withDefaults("Override", 42))   // nested traits override the suite's
    func example() { ... }
}

// Per mock, no trait needed
var registry = DefaultProvidableRegistry.default
registry.register(.valueProvider(User(id: "seed")))
mock.defaultProviderRegistry = registry
```

`.withDefaults` is scoped to the test — it never leaks into others. Assigning `mock.defaultProviderRegistry` propagates to every spy the mock owns, including ones created later.

## Argument matchers (`ArgMatcher<T>`)

| Matcher | Matches |
|---|---|
| `.any`, `.equal(v)`, `.nil()`, `.notNil()` | any / exact / nil / non-nil |
| `.contains`, `.startsWith`, `.endsWith`, `.matches(regex)` | `String` (also `Array` for contains) |
| `.in(10...20)`, `.in(50...)`, `.in(...5)` | `Comparable` ranges |
| `.lessThan`, `.greaterThan`, `.lessThanOrEqual`, `.greaterThanOrEqual` | numeric comparisons |
| `.identical(obj)` | object identity |
| `.approximately(x, accuracy:)` | floating point |
| `.any(where: \.name, equals: "Ada")` | key-path projection |
| `.any(that: { $0.count > 3 })` | arbitrary predicate — last resort, see below |

Plain values coerce: `when(mock.log("hi"))` ≡ `.equal("hi")`.

**Reach for `.any(where:equals:)` before `.any(that:)`.** `.any(that:)` takes a
`@Sendable` closure, and Swift's inference doesn't always propagate `@Sendable` through
the member chain — a bare `.any(that: { $0.id == x })` can produce *"Converting
non-Sendable function value to '@Sendable (T) -> Bool' may introduce data races"*. The
key-path form captures a value instead of a closure, so it never can:

```swift
when(mock.getUser(.any(where: \.id, equals: "123"))).thenReturn(user)   // ✅ preferred
when(mock.getUser(.any(that: { $0.id == "123" }))).thenReturn(user)     // ⚠️ may warn
```

Use `.any(that:)` only for logic a key-path comparison can't express (ranges over a
projection, multi-field conditions, negation). When you do, annotate the closure
explicitly to silence the warning:

```swift
when(mock.process(.any(that: { @Sendable in $0.retries > 3 && $0.isStale }))).thenReturn(true)
```

`.any(where:)` also accepts the value unlabeled (`.any(where: \.id, "123")`) for
backward compatibility; prefer the `equals:` label in new code.

## Stubbing

```swift
when(mock.price(.any)).thenReturn(100)
when(mock.validate("bad")).thenThrow(ValidationError.invalid)
when(mock.execute(completion: .any)).do { completion in completion("ok") }     // side effect / callbacks
when(mock.calculatePrice(.any)).thenReturn { item in prices[item] ?? 0 }      // dynamic return
when(mock.fetch(.equal(url))).thenReturn { _ in callCount == 1 ? throw Timeout : data } // stateful
```

- Ordering: most specific matcher first; later stubs for the **same** matcher win.
- `do` = side-effect invocation (returns nothing); `thenReturn { }` = compute return value; `thenThrow` = error.
- `Void`-returning members need no stub — see *Default values* above. `thenReturn(())` is never necessary.
- Handler closures are `@Sendable` — construct non-Sendable values inside, don't capture them (see sendable.md).

## Verification

```swift
verify(mock.process(.any)).called()             // ≥ 1 (default)
verify(mock.process(.any)).called(3)            // exactly 3
verify(mock.process(.any)).neverCalled()        // or verifyNever(mock.process(.any))
verify(mock.validate("bad")).throws()           // any error (Throws effect)
verify(mock.validate("bad")).throws(ValidationError.self)
await verify(mock.upload(.any)).throws()        // async spies: await the throws() form
verifyInOrder([mock.auth(.any), mock.data(.any)])  // call order across spies
`called(n)` is synchronous for all effect types; only `.throws()` on async spies needs `await`. Verification failures are reported through [IssueReporting](https://github.com/pointfreeco/swift-issue-reporting) — they record issues inside XCTest/swift-testing runs and are **silent in plain executables**, so validate mocks in a real test context.

## Properties & subscripts

Read-only members expose a plain `Interaction`. **Settable** members (`{ get set }`) expose a `SettableInteraction`: the same expression stubs/verifies reads, and `<- value` turns it into the write interaction.

```swift
let mock = MyServiceMock()
let svc: MyService = mock                    // protocol-typed reference, for subscript reads

// Reads — unchanged by settability
when(mock.isEnabled).thenReturn(true)        // property getter
when(mock[.any]).thenReturn("cached")        // subscript getter
verify(mock.isEnabled).called(1)
verify(mock[.equal("key")]).called(1)

// Writes — `<-` on the same expression
mock.isEnabled = false                       // properties: drive the mock directly
svc["key"] = "v"                             // subscripts: via the protocol-typed `svc`
verify(mock.isEnabled <- false).called(1)
verify(mock[.equal("key")] <- "v").called(1)
verifyNever(mock.isEnabled <- .any)
```

Rules that trip people up:

- **Reads and writes are separate spies.** `verify(mock.isEnabled)` counts reads only; `verify(mock.isEnabled <- .any)` counts writes only. A write does not register as a read.
- **Properties need no protocol-typed reference.** The runtime member is a `var` and the interaction member is a `func`, so `mock.isEnabled = false` and `_ = mock.isEnabled` both hit the property while `when(mock.isEnabled)` still resolves to the interaction. Tests read better driving the mock directly.
- **Subscripts do need one for reads.** `mock[key]` (values) and `mock[.any]` (matchers) are a genuine overload pair — an unannotated `let v = mock[1]` is ambiguous. Use a protocol-typed reference (`let svc: MyService = mock`) for reads; writes (`mock["k"] = 5`) disambiguate on their own.
- **Zero-arg methods always need one.** `mock.refresh()` is ambiguous between runtime and interaction members.
- **The write pack is the read pack plus the written value** — so `captured` and stub closures take the indices first, value last: `verify(mock.isEnabled <- .any).captured { _, newValue in ... }`. For a property the read pack is `(Void)`, hence the leading `_`.
- **Matchers work on both sides**: `verify(cache[.any] <- .equal("v"))`, `mock.count <- .greaterThan(8)`. Bare literals coerce to `.equal`.
- **Stub write side effects** with `when(mock.value <- 7).thenReturn { _, newValue in ... }`. Handlers are `@Sendable`, so collect what they observe in a `CaptureBox<T>` (from `SwiftMockingTestSupport`) rather than a captured local `var`: `written.append(newValue)` then assert on `written.values`.
- `<-` composes with `verifyInOrder`, since it yields an ordinary `Interaction`: `verifyInOrder([mock.value <- 7, mock.refresh()])`.
- **Multi-index subscripts must bind first** — `let w = mock[.equal(1), .equal(2)] <- "x"; verify(w).called(1)`. Forwarding the pack-rearranged result straight into `verify` does not infer on current toolchains. Single-index subscripts and properties chain fine.
- Explicit form if you prefer it over the operator: `mock.value(()).set(.equal(7))`, `mock[.any].set(.any)`.

The getter interaction is an overload on the variable name taking `Void` — the parameter is required: a niladic form would be an `invalid redeclaration` against the property's getter accessor, and it's what lets `when(mock.x)` infer its input pack. Bare zero-arg calls (`mock.f()`) on the mock type can be ambiguous between the runtime and interaction members — call through the protocol type.

## Closure-based dependencies (TCA pattern)

No protocol needed — adapt standalone spies into closures:

```swift
let fetchSpy = Spy<String, AsyncThrows, Data>()
when(fetchSpy(.any)).thenReturn(Data(...))
let client = NetworkClient(fetchData: adapt(fetchSpy))
verify(fetchSpy(.equal("1"))).called(1)
```

`adapt` is the member on `Mock` AND a standalone overload for spies; it returns a `@Sendable` closure.

A `Spy` is fully usable on its own — `spy(value)` invokes, `spy(.matcher)` builds an `Interaction` for `when`/`verify`, and `spy.clear()` resets it. That's what lets you mock **classes** (subclass, back each override with a spy) and build fakes that hold `let mock = Mock()` by composition instead of inheriting `Mock` — needed for structs, actors, and types with an existing superclass. See **spies-and-composition.md**.

## Generics, statics, variadics

```swift
let repo = MyRepositoryMock<User>()              // associatedtype → generic mock
MockLogger.log("test"); verify(MockLogger.log(.any)).called()   // static spies
mock.print("hello", "world")
verify(mock.print("hello", .any)).called()       // variadic: mix values and matchers
```

## Swift-testing / XCTest integration

```swift
@Test func fetches() async throws {
    let mock = MyServiceMock()
    when(mock.fetch(id: .any)).thenReturn(User(id: "123"))
    let user = try await SUT(mock).fetch(id: "123")
    #expect(user.id == "123")
    await verify(mock.fetch(id: .equal("123"))).called(1)
}
```

XCTest is the same shape (`XCTAssertEqual` + non-async `verify`). Per-test default values come from `.withDefaults(...)` (swift-testing only, Swift 6.1+); under XCTest set `mock.defaultProviderRegistry` instead — both in *Default values* above.

## Best practices (short list)

1. Matchers: as specific as the behavior under test requires; `.contains` over exact long strings.
2. Verify interactions you care about; don't over-verify internal call chains.
3. Test success AND failure paths (`thenReturn` / `thenThrow`).
4. Don't stub what the registry already covers — no `thenReturn(())`, and skip stubs for returns the test doesn't assert on.
4. Arrange → Act → Assert; stubs before SUT construction when readability allows.
5. Clear static mocks in `tearDown` (`MockLogger.clear()`); safe under concurrent task groups.
