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
- Unstubbed non-throwing returns fall back to registered default values, else trap (`fatalError` surfaced at the call site). Unstubbed throwing methods throw.

## Argument matchers (`ArgMatcher<T>`)

| Matcher | Matches |
|---|---|
| `.any`, `.equal(v)`, `.nil()`, `.notNil()` | any / exact / nil / non-nil |
| `.contains`, `.startsWith`, `.endsWith`, `.matches(regex)` | `String` (also `Array` for contains) |
| `.in(10...20)`, `.in(50...)`, `.in(...5)` | `Comparable` ranges |
| `.lessThan`, `.greaterThan`, `.lessThanOrEqual`, `.greaterThanOrEqual` | numeric comparisons |
| `.identical(obj)` | object identity |
| `.approximately(x, accuracy:)` | floating point |
| `.any(where: \.name, "Ada")` | key-path projection |

Plain values coerce: `when(mock.log("hi"))` ≡ `.equal("hi")`.

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

```swift
when(mock.isEnabled).thenReturn(true)       // getter interaction — reads like the property itself
mock.isEnabled = false
verify(mock.setIsEnabled(newValue: .equal(false))).called(1)

when(cache[.any]).thenReturn("cached")       // subscript interactions via matcher subscript
verify(cache[.equal("key")]).called(1)
```

Getter verification mirrors a read too: `verify(mock.isEnabled).called(1)` (also `verifyNever(mock.isEnabled)`). The getter interaction is an overload on the variable name taking `Void`; setter interactions keep the `setX(newValue:)` form. Bare zero-arg calls (`mock.f()`) on the mock type can be ambiguous between the runtime and interaction members — call through the protocol type.

## Closure-based dependencies (TCA pattern)

No protocol needed — adapt standalone spies into closures:

```swift
let fetchSpy = Spy<String, AsyncThrows, Data>()
when(fetchSpy(.any)).thenReturn(Data(...))
let client = NetworkClient(fetchData: adapt(fetchSpy))
verify(fetchSpy(.equal("1"))).called(1)
```

`adapt` is the member on `Mock` AND a standalone overload for spies; it returns a `@Sendable` closure.

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

XCTest is the same shape (`XCTAssertEqual` + non-async `verify`). For unstubbed-default values per test, see the `DefaultValuesTrait` swift-testing trait.

## Best practices (short list)

1. Matchers: as specific as the behavior under test requires; `.contains` over exact long strings.
2. Verify interactions you care about; don't over-verify internal call chains.
3. Test success AND failure paths (`thenReturn` / `thenThrow`).
4. Arrange → Act → Assert; stubs before SUT construction when readability allows.
5. Clear static mocks in `tearDown` (`MockLogger.clear()`); safe under concurrent task groups.
