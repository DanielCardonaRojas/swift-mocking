# Manual Mock Generation Reference

How to hand-write what `@Mockable` generates — without the macro. Required when the macro can't help:

- **Protocol inheritance** (`protocol B: A`): the macro only walks the protocol's own member list; inherited requirements are dropped and the mock fails to build (`error: type 'BMock' does not conform to protocol 'A'`). This is the primary manual case.
- Macro plugin unavailable (locked-down toolchains, codegen restrictions).
- One-off customization inside a mock.

Hand-writing is always a valid option, with or without the `mockable` CLI. For protocols **without** inheritance, generating the base with the CLI (see SKILL.md) is faster and byte-exact — use it when available, then hand-adjust.

Everything below mirrors `MockableGenerator` — with one deliberate improvement: zero-parameter members and property getters use the pinned-spy form so `when`/`verify` actually reach them (the macro-generated form silently mis-stubs those; see the pinned-spy section).

## The two-member rule

For every protocol requirement, write **two** members:

1. **Runtime member** — fulfills the protocol; forwards to the spy via `adapt`/`adaptThrowing`.
2. **Interaction member** — same name, every parameter wrapped in `ArgMatcher<T>`, returns `Interaction<Inputs..., Effect, Output>`; this is what `when(...)`/`verify(...)` consume.

`super.<name>` (resolved through `Mock`'s `@dynamicMemberLookup` subscript) lazily creates or fetches the `Spy` keyed by that member name — instance context uses instance storage, `static` context uses lock-backed static storage. Never instantiate `Spy` yourself inside a mock.

## Class shell

```swift
import SwiftMocking

class FooMock: Mock, @unchecked Sendable, Foo {
    // members...
}
```

Non-negotiables:
- Inherit `Mock` **first**.
- **Restate `@unchecked Sendable`** in the inheritance clause (required since Swift-6 work; omitting it produces concurrency warnings and loses `Sendable`-protocol conformance). It is honest — `Mock` synchronizes all state with locks.
- Conform to the **most-derived protocol only**; parent conformances come along.
- Match the protocol's access level (`public protocol` → `public class` + `public` members) or tests in another module can't see the mock.
- The macro wraps output in `#if DEBUG`; optional for manual mocks — do it if you want release builds to drop the mock.

## Methods: effect → adapter mapping

| Protocol signature | Runtime body | Interaction effect |
|---|---|---|
| `-> Int` | `return adapt(super.f, x)` | `None` |
| `throws -> Int` | `return try adaptThrowing(super.f, x)` | `Throws` |
| `async -> Int` | `return await adapt(super.f, x)` | `Async` |
| `async throws -> Int` | `return try await adaptThrowing(super.f, x)` | `AsyncThrows` |

Interaction generic arguments: **input types in order**, then the effect marker, then the output type (`Void` if none). Zero parameters → `Interaction<Void, Eff, Out>` with `Interaction(.any, spy: super.f)` — and the runtime member must pass `()` explicitly (`adapt(super.f, ())`) to land on that same `(Void)`-pack spy.

## Zero-parameter members and property getters — pass `()` explicitly

`adapt(super.f)` with **no arguments** infers an empty parameter pack, which resolves to a *different* spy than the interaction member's `Spy<Void, Eff, Out>`. Symptom: `when(mock.f()).thenReturn(v)` is silently ignored (unstubbed default returned) and `verify(mock.f()).called(n)` always sees 0 — even though the member ran. The macro emits `adapt(super.f, ())`; a manual mock must do the same:

```swift
// protocol: func getStatus() -> String
func getStatus() -> String {
    return adapt(super.getStatus, ())
}
func getStatus() -> Interaction<Void, None, String> {
    Interaction(.any, spy: super.getStatus)
}
```

Effect variants: `return await adapt(super.getStatus, ())` (Async), `return try adaptThrowing(super.getStatus, ())` (Throws), `return try await adaptThrowing(super.getStatus, ())` (AsyncThrows). Property getters use the same form keyed by the property name (see Properties).


## Calling the mock — go through the protocol type

Two overload-resolution traps when calling the mock's concrete type directly:

- **Literal arguments dispatch to the interaction member.** `ArgMatcher` is literal-convertible, so `mock.fetchUser(id: "1")` with a *literal* resolves to the `ArgMatcher` overload (returns an `Interaction`, records nothing) instead of the runtime method. Route calls through a protocol-typed reference (`let svc: AuthorizingUserService = mock; try await svc.fetchUser(id: "1")`) — or a non-literal variable — to hit the runtime member.
- **Zero-arg members are ambiguous** (`ambiguous use of 'f()'` — both overloads match). The protocol-typed reference resolves this too.

`when(...)`/`verify(...)` are unaffected — their `Interaction` parameter type picks the interaction overload.

## Protocol inheritance — the full recipe


```swift
public protocol UserService {
    func fetchUser(id: String) async throws -> User
    var cachePolicy: String { get set }
}

public protocol AuthorizingUserService: UserService {
    func authorize(_ token: String) throws -> Bool
}

public class AuthorizingUserServiceMock: Mock, @unchecked Sendable, AuthorizingUserService {
    // Runtime — UserService requirements
    public func fetchUser(id: String) async throws -> User {
        return try await adaptThrowing(super.fetchUser, id)
    }
    public var cachePolicy: String {
        get {
            let spy: Spy<Void, None, String> = super.cachePolicy
            return spy(())
        }
        set { return adapt(super.setCachePolicy, (), newValue) }
    }
    // Runtime — AuthorizingUserService requirements
    public func authorize(_ token: String) throws -> Bool {
        return try adaptThrowing(super.authorize, token)
    }
    // Interactions — UserService
    public func fetchUser(id: ArgMatcher<String>) -> Interaction<String, AsyncThrows, User> {
        Interaction(id, spy: super.fetchUser)
    }
    // Settable → one member returning SettableInteraction (reads + writes)
    public func cachePolicy(_ void: Void) -> SettableInteraction<Void, None, String> {
        SettableInteraction(
            get: Interaction(.any, spy: super.cachePolicy),
            setInteraction: { newValue in
                Interaction(.any, newValue, spy: super.setCachePolicy)
            }
        )
    }
    // Interactions — AuthorizingUserService
    public func authorize(_ token: ArgMatcher<String>) -> Interaction<String, Throws, Bool> {
        Interaction(token, spy: super.authorize)
    }
}
```

Rules:
1. Flatten the chain: emit runtime **and** interaction members for every requirement of every protocol in the chain (the compiler will tell you about missing *runtime* members; missing *interaction* members compile silently but break stubbing).
2. Diamond chains (`C: A, B`) — same flattening; watch for requirement collisions (both parents declare `x`): implement once.
3. A requirement with a default implementation in a protocol extension still needs both members if tests stub it.

## Properties

Getter interaction overloads the variable name with a `Void` parameter. The `Void` parameter is required, not cosmetic: a niladic `func cachePolicy()` next to the `var cachePolicy` conformance is an `invalid redeclaration` (the property's getter accessor already owns that selector), and the unapplied reference `mock.cachePolicy` must have exactly type `(Void) -> Interaction<…>` for `when(mock.cachePolicy)` / `verify(mock.cachePolicy)` to infer their input pack.

**Read-only** property → runtime getter + the `x(_ void: Void)` interaction returning a plain `Interaction`:

```swift
// protocol: var readOnly: Int { get }
var readOnly: Int {
    get {
        // Pass () explicitly — a bare `adapt(super.readOnly)` hits the
        // zero-arg spy mismatch and getter stubs/verifies silently no-op.
        adapt(super.readOnly, ())
    }
}
func readOnly(_ void: Void) -> Interaction<Void, None, Int> {
    Interaction(.any, spy: super.readOnly)
}
```

**Settable** property → reads and writes record on *two* spies (`cachePolicy` and `setCachePolicy`), because their input packs differ. One interaction member returns a `SettableInteraction` carrying both:

```swift
// protocol: var cachePolicy: String { get set }
var cachePolicy: String {
    get { adapt(super.cachePolicy, ()) }
    // The `return` pins Output == Void; see the errors table.
    set { return adapt(super.setCachePolicy, (), newValue) }
}
func cachePolicy(_ void: Void) -> SettableInteraction<Void, None, String> {
    SettableInteraction(
        get: Interaction(.any, spy: super.cachePolicy),
        setInteraction: { newValue in
            Interaction(.any, newValue, spy: super.setCachePolicy)
        }
    )
}
```

Three details the compiler will not catch for you:

1. **Write spy name is `set` + the name with only its first letter uppercased** — `setCachePolicy`, not `setCachepolicy`. Read and write sides must agree; if both are wrong in the same way tests still pass, so this only shows up as a typo in your source.
2. **The write pack is the read pack plus the value**: the setter passes `(), newValue` and the write `Interaction` lists `.any, newValue`. Getting the order wrong misroutes matchers silently.
3. **`setInteraction` is a closure**, not a stored `Interaction` — appending a value after a pack expansion isn't expressible in a generic body, so generated and hand-written mocks both inject it.

## Subscripts

Spy name is `subscript` followed by the parameter names in camelCase — `subscript(key:)` → `subscriptKey`, `subscript(row:column:)` → `subscriptRowColumn`; a subscript with no named parameter is just `subscript`. Write spy is `set` + that name upper-camel-cased (`setSubscriptRowColumn`). The prefix is what keeps a subscript's spy distinct from a method or variable sharing the name.

```swift
// protocol: subscript(key: String) -> Int { get }
subscript(key: String) -> Int {
    get { return adapt(super.key, key) }
}
subscript(key: ArgMatcher<String>) -> Interaction<String, None, Int> {
    get { Interaction(key, spy: super.key) }
}
```

**Settable** subscript — same two-spy structure as a settable property, with the indices in place of the property's `(Void)` pack:

```swift
// protocol: subscript(key: String) -> Int { get set }
subscript(key: String) -> Int {
    get { return adapt(super.key, key) }
    set { return adapt(super.setKey, key, newValue) }
}
subscript(key: ArgMatcher<String>) -> SettableInteraction<String, None, Int> {
    get {
        SettableInteraction(
            get: Interaction(key, spy: super.key),
            setInteraction: { newValue in
                Interaction(key, newValue, spy: super.setKey)
            }
        )
    }
}
```

Usage: `when(mock[.any]).thenReturn(1)` stubs reads; `verify(mock[.equal("k")] <- 9).called(1)` verifies writes.

## Testing settable members

Reads and writes are **separate spies** — a write never registers as a read.

```swift
let mock = ConfigMock()
when(mock.cachePolicy).thenReturn("none")          // stub the read

XCTAssertEqual(mock.cachePolicy, "none")           // property: no indirection needed
mock.cachePolicy = "aggressive"                    // routes to the write spy

verify(mock.cachePolicy).called(1)                 // reads only
verify(mock.cachePolicy <- "aggressive").called(1) // writes only
verifyNever(mock.cachePolicy <- .equal("never"))
```

For a **property**, the runtime member is a `var` and the interaction member is a `func`, so both directions resolve unambiguously on the mock type — drive it directly. **Subscript reads** are the exception: `mock[key]` and `mock[.any]` are a real overload pair, so bind `let svc: Config = mock` and read through it (writes are fine either way). Zero-arg **methods** always need the protocol type.

- **Captured values put the written value last**, after the read pack: `verify(mock.cachePolicy <- .any).captured { _, newValue in ... }` — the `_` is the property's `(Void)` read pack.
- **Write side effects**: `when(mock.value <- 7).thenReturn { _, newValue in ... }`.
- **`verifyInOrder` composes**, since `<-` yields an ordinary `Interaction`: `verifyInOrder([mock.cachePolicy <- "aggressive", mock[.any] <- 9])`.
- **Multi-index subscripts must bind first** — `let w = mock[.equal(1), .equal(2)] <- "x"; verify(w).called(1)`. Forwarding a pack-rearranged result directly into `verify` does not infer on current toolchains; single-index subscripts and properties are fine.
- Explicit alternative to the operator: `mock.cachePolicy(()).set(.equal("aggressive"))`, `mock[.any].set(.any)`.

## Variadic parameters

Matcher parameter keeps the ellipsis; the Interaction input type is the **array** type; wrap with `.variadic(...)`.

```swift
// protocol: func print(_ values: String...)
func print(_ values: String...) {
    return adapt(super.print, values)
}
func print(_ values: ArgMatcher<String>...) -> Interaction<[String], None, Void> {
    Interaction(.variadic(values), spy: super.print)
}
```

## Associated types

Mock goes generic; alias each associated type to the generic parameter.

```swift
// protocol Repository { associatedtype Entity; func find(id: String) throws -> Entity? }
class RepositoryMock<Entity>: Mock, @unchecked Sendable, Repository {
    typealias Entity = Entity
    func find(id: String) throws -> Entity? {
        return try adaptThrowing(super.find, id)
    }
    func find(id: ArgMatcher<String>) -> Interaction<String, Throws, Entity?> {
        Interaction(id, spy: super.find)
    }
}
```

Inherit the associated type's constraints (e.g. `associatedtype E: Equatable` → `<E: Equatable>`). Instantiate: `RepositoryMock<User>()`.

## Static members

Identical shapes with `static`; `super.name` resolves through `Mock`'s static subscript (lock-backed static storage, safe for concurrent tests).

```swift
static func log(_ message: String) {
    return adapt(super.log, message)
}
static func log(_ message: ArgMatcher<String>) -> Interaction<String, None, Void> {
    Interaction(message, spy: super.log)
}
```

`MyMock.clear()` between tests.

## Initializer requirements

```swift
required init(name: String) { }
```

Empty body — mocks don't store protocol state.

## Closure parameters

Keep `@escaping` on the runtime member, strip it in the matcher:

```swift
// protocol: func execute(completion: @escaping (String) -> Void)
func execute(completion: @escaping (String) -> Void) {
    return adapt(super.execute, completion)
}
func execute(completion: ArgMatcher<(String) -> Void>) -> Interaction<(String) -> Void, None, Void> {
    Interaction(completion, spy: super.execute)
}
```

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Missing `@unchecked Sendable` restatement | Swift 6 warnings; fails `: Sendable` protocol conformance | `class FooMock: Mock, @unchecked Sendable, Foo` |
| Zero-arg runtime member written as `adapt(super.f)` | Stub ignored; `verify(...)` always 0 (silent) | Pass `()`: `adapt(super.f, ())` — the form the macro emits |
| Calling `mock.f()` bare on a zero-arg mock member | `ambiguous use of 'f()'` | Call through a protocol-typed reference |
| Getter body `adapt(super.getX)` (wrong key or bare adapt) | Getter stubs/verifies silently no-op | Pin `Spy<Void, None, T>` keyed by the **property name** |
| Setter body without `return` | `generic parameter 'Output' could not be inferred` | `set { return adapt(super.setCachePolicy, (), newValue) }` — the `return` pins `Output == Void` |
| Write verified but count is 0 | — | Read/write spy names disagree (e.g. setter uses `.capitalized` → `setCachepolicy` while the interaction uses `setCachePolicy`) |
| `verify(mock[.a, .b] <- v)` won't compile | `cannot convert value` / inference failure | Multi-index subscript: bind first (`let w = mock[.a, .b] <- v`), then `verify(w)` |
| Only implementing the derived protocol's members | Compile error (missing runtime witnesses) | Flatten the chain — runtime + interaction members for every ancestor requirement |
| Runtime members only (no `ArgMatcher` overloads) | Compiles; `when`/`verify` can't reference the method | Every requirement gets both members |
| Instantying `Spy()` manually inside the mock | Invocations not recorded where `when`/`verify` look | Always go through `super.<name>` |
| Internal mock for a public protocol | `cannot find 'XMock' in scope` from the test module | Match access levels |
| Renaming interaction members (`fetchUserInteraction`) | API mismatch with macro convention | Same name, matcher-typed parameters |
| Keeping `@escaping` inside `ArgMatcher<@escaping (String) -> Void>` | Syntax error | Strip attributes in matcher types |

## Sanity check

A correct manual mock supports the full round trip:

```swift
let mock = AuthorizingUserServiceMock()
when(mock.fetchUser(id: .any)).thenReturn(User(id: "1", name: "Ada"))
let svc: AuthorizingUserService = mock       // protocol-typed: avoids overload traps
let user = try await svc.fetchUser(id: "1")
verify(mock.fetchUser(id: .equal("1"))).called(1)
```
