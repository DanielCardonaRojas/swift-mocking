# Spies Directly & Composition Over Inheritance

Two escape hatches for everything `@Mockable` cannot reach. Both are fully supported, not workarounds of last resort:

1. **Use `Spy` directly** — no `Mock` subclass, no macro. Mock **classes**, closures, or anything else that isn't a protocol.
2. **Compose instead of inherit** — hold a `let mock = Mock()` property rather than subclassing `Mock`, for types that already have a superclass or that aren't classes at all (structs, actors).

Every example below was compiled and executed against this package.

## Decision table

| Situation | Technique |
|---|---|
| Protocol, no inheritance | `@Mockable` (nothing here needed) |
| Protocol inheritance chain | manual-mocking.md (subclass `Mock`) |
| **Mocking a class** (`class RemoteLoader`, no protocol) | Subclass it, back overrides with raw `Spy` — §Raw spies |
| **Type already has a superclass** (`UIViewController`, `RemoteLoader`) | Composition — §Composition |
| **Struct or actor conforming to a protocol** | Composition (can't inherit at all) |
| Closure / TCA-style dependency | Raw `Spy` + `adapt(spy)` — usage.md also covers this |
| Final class you can't subclass | Extract a protocol, or wrap it — §Limits |

---

## Part 1 — Using `Spy` directly

A `Spy` is a standalone, fully functional recorder. It needs no `Mock` parent:

```swift
let spy = Spy<String, Throws, Int>()   // <Input..., Effect, Output>
when(spy(.any)).thenReturn(7)
XCTAssertEqual(try spy("a"), 7)        // callAsFunction with a VALUE calls through
verify(spy(.equal("a"))).called(1)     // callAsFunction with a MATCHER makes an Interaction
verifyNever(spy(.equal("zzz")))
```

The generic parameters are exactly the ones in `Interaction`: **input types in order, then the effect marker (`None`/`Throws`/`Async`/`AsyncThrows`), then the output** (`Void` if none). The global `when` / `verify` / `verifyNever` / `verifyInOrder` all accept a spy's `Interaction`, so the entire matcher and stubbing vocabulary from usage.md applies unchanged.

`spy(...)` is overloaded on argument type — pass real values to invoke, pass `ArgMatcher`s to build an `Interaction`. That is the same duality as a generated mock's two members, collapsed into one object.

### Effects and zero-argument spies

```swift
let async = Spy<Int, AsyncThrows, String>()
when(async(.any)).thenReturn("ok")
let v = try await async(1)                 // await for Async/AsyncThrows

let void = Spy<Void, None, Void>()
void(())                                   // pass () explicitly — never a bare void()
verify(void(.any)).called(1)
```

The `()` rule from manual-mocking.md holds here for the same reason: a `Spy<Void, …>` has a one-element `(Void)` pack, and an empty argument list infers a *different*, empty pack.

### Mocking a class the macro cannot touch

`@Mockable` only accepts protocols. To fake a non-final class, subclass it and route each override to a spy you own:

```swift
class RemoteLoader {                    // third-party / legacy, no protocol
    func load(_ id: String) throws -> String { "real" }
    func ping() -> Bool { true }
    var name: String { "real" }
}

final class SpyBackedLoader: RemoteLoader, @unchecked Sendable {
    let loadSpy = Spy<String, Throws, String>()
    let pingSpy = Spy<Void, None, Bool>()
    let nameSpy = Spy<Void, None, String>()

    override func load(_ id: String) throws -> String { try loadSpy(id) }
    override func ping() -> Bool { pingSpy(()) }
    override var name: String { nameSpy(()) }
}
```

```swift
let loader = SpyBackedLoader()
when(loader.loadSpy(.any)).thenReturn("stubbed")
when(loader.nameSpy(.any)).thenReturn("stubbedName")

let base: RemoteLoader = loader          // exercise through the real class type
XCTAssertEqual(try base.load("1"), "stubbed")
XCTAssertEqual(base.name, "stubbedName")
verify(loader.loadSpy(.equal("1"))).called(1)
```

Why this shape:

- **Distinct property names** (`loadSpy`, not `load`) sidestep every overload trap in the SKILL's sharp-edges list — there is no matcher overload competing with the override, so literals and zero-arg calls are unambiguous even on the concrete type.
- **`override var name`** works because a spy call is just an expression; property getters take `(())`.
- Only **overridable** members can be faked: non-`final` methods on a non-`final` class. See §Limits.
- Restate `@unchecked Sendable` if the base class is `Sendable`; `Spy` is internally locked.

### Closure dependencies

`adapt(spy)` turns a spy into a `@Sendable` function value — the TCA/struct-of-closures pattern:

```swift
let fetchSpy = Spy<String, Throws, Int>()
when(fetchSpy(.any)).thenReturn(3)
let client = Client(fetch: adapt(fetchSpy))     // (String) throws -> Int
verify(fetchSpy(.any)).called(1)
```

### Direct spy methods

Besides the global functions, `Spy` exposes its own API (`references/interface/SwiftMocking.swiftinterface` has exact signatures):

```swift
spy.when(calledWith: .any).thenReturn(7)
spy.verify(calledWith: .equal("a"), count: .equal(1))   // -> Bool, no issue reported
spy.invocations                                          // [Invocation<…>]
spy.invocationCount
spy.clear()                                              // reset stubs + recorded calls
```

Prefer the global `when`/`verify` in tests: they report failures through IssueReporting at the caller's source location. The `Bool`-returning `spy.verify(...)` reports nothing — wrap it in `#expect`/`XCTAssert` yourself.

---

## Part 2 — Composition instead of inheritance

`Mock`'s power comes from its `@dynamicMemberLookup` subscript, and **that subscript is `public`**. So `mock.someName` resolves a lazily-created spy from *outside* the class too — you do not have to be a subclass:

```swift
final class ComposedLoaderMock: RemoteLoader, Loading, @unchecked Sendable {
    let mock = Mock()                       // composition: a property, not a superclass

    override func load(_ id: String) throws -> String {
        try Mock.adaptThrowing(mock.load, id)
    }
    func load(_ id: ArgMatcher<String>) -> Interaction<String, Throws, String> {
        Interaction(id, spy: mock.load)
    }
    override func ping() -> Bool {
        Mock.adapt(mock.ping, ())
    }
    func ping(_ void: Void = ()) -> Interaction<Void, None, Bool> {
        Interaction(.any, spy: mock.ping)
    }
}
```

This is the manual-mocking.md recipe with exactly **two mechanical substitutions**:

| Subclassing `Mock` | Composing a `Mock` |
|---|---|
| `super.load` | `mock.load` |
| `adapt(...)` / `adaptThrowing(...)` (instance method) | `Mock.adapt(...)` / `Mock.adaptThrowing(...)` (static) |

**The `Mock.` prefix is required, and it is the one thing that catches people out.** `adapt` is an instance method on `Mock`; a composing type does not inherit it. Use the static overloads — they take the spy as their first argument and behave identically. (A file-scope `func adapt` shadow also works, but the static form is clearer.)

Everything else is unchanged: the two-member rule, the effect→adapter table, the explicit `()` for zero-arg members, `Interaction` generic ordering, settable properties' two-spy structure, subscript spy naming.

### Usage is identical to a generated mock

```swift
let loader = ComposedLoaderMock()
when(loader.load(.any)).thenReturn("composed")
when(loader.ping()).thenReturn(false)

let base: RemoteLoader = loader
XCTAssertEqual(try base.load("42"), "composed")
verify(loader.load(.equal("42"))).called(1)

loader.mock.clear()                 // clear() lives on the property now
verify(loader.load(.any)).neverCalled()
```

Note `loader.mock.clear()` rather than `loader.clear()` — the composing type doesn't inherit `clear()`. Re-expose it if tests expect the usual shape:

```swift
func clear() { mock.clear() }
```

### Structs and actors

Composition is the *only* option when there's no class to inherit from. Both compile and record correctly:

```swift
struct StructMock: Sizing {
    let mock = Mock()
    func size(_ s: String) -> Int { Mock.adapt(mock.size, s) }
    func size(_ s: ArgMatcher<String>) -> Interaction<String, None, Int> {
        Interaction(s, spy: mock.size)
    }
}

actor ActorMock {
    nonisolated let mock = Mock()
    nonisolated func size(_ s: String) -> Int { Mock.adapt(mock.size, s) }
    nonisolated func size(_ s: ArgMatcher<String>) -> Interaction<String, None, Int> {
        Interaction(s, spy: mock.size)
    }
}
```

- **Struct**: no `mutating` needed — `Mock` is a reference type, so recording mutates through the `let`. Beware that copying the struct shares one spy store.
- **Actor**: mark the property and both members `nonisolated`, otherwise `when`/`verify` become `await`-only and the runtime member can't satisfy a synchronous protocol requirement. `Mock` is `@unchecked Sendable` and lock-guarded, so this is sound.

### Composition vs. raw spies — which one

Both fake a class; they differ in the API tests see.

- **Raw spies** (`loader.loadSpy(.any)`): less code, zero overload ambiguity, but a non-standard call site. Good for a couple of members or a quick local fake.
- **Composition** (`loader.load(.any)`): reproduces the exact generated-mock API, so tests read the same as everywhere else and members port cleanly if a protocol appears later. Costs two members per requirement. Good for shared fixtures.

Composition also gives one thing raw spies don't: a **single `clear()`** across all members, and static-storage support via `Mock`'s static subscript.

---

## Limits

- **`final` classes and `final` members can't be overridden** by either technique. Extract a protocol (then `@Mockable` applies), or wrap the type behind one.
- **No `super` calls to real behavior after stubbing** — an override forwards to the spy or to `super`, not both. Partial mocks aren't supported; branch inside the override if you need one.
- **Non-overridable storage**: a stored `var` on the base class can't be turned into a spy-backed property in a subclass. Override a computed property, or compose.
- **Class initializers** must still satisfy the superclass — call a real `super.init(...)`; `Mock`'s empty-init convention doesn't apply.
- **Composition doesn't inherit `Mock`'s conveniences**: `clear()`, `adapt`, and `DefaultProvider` conformance are all on `Mock`. Forward them explicitly if needed.

## Sanity check

Any of these fakes should round-trip:

```swift
let mock = ComposedLoaderMock()
when(mock.load(.any)).thenReturn("stubbed")
let svc: Loading = mock                   // protocol- or base-typed reference
_ = try svc.load("1")
verify(mock.load(.equal("1"))).called(1)
```
