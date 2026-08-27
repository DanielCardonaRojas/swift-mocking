---
name: swift-mocking
description: Use when writing Swift tests with the SwiftMocking library — creating @Mockable mocks, stubbing with when/verify, matching arguments, class-constrained protocols (@Mockable([.composition])), or hand-writing mocks (protocol inheritance chains, mocking classes).
---

# SwiftMocking

Mocking for Swift protocols: `@Mockable` generates mock classes; `when(...)` stubs, `verify(...)` asserts calls. When the macro can't generate a mock — most notably **protocol inheritance** (`protocol B: A` — the macro drops inherited requirements and the mock fails to conform) — hand-write the mock following the exact generated-code shape.

The macro is not the only entry point. Two escape hatches cover everything it can't reach, and both are fully supported (see **spies-and-composition.md**):

- **`Spy` used directly** — a standalone recorder needing no `Mock` subclass and no macro. This is how you mock **classes**, which `@Mockable` cannot touch at all: subclass the class and back each override with a `Spy`.
- **Composition over inheritance** — hold a `let mock = Mock()` property instead of inheriting from `Mock`. `Mock`'s `@dynamicMemberLookup` subscript is `public`, so `mock.name` resolves spies from outside the class. Required when the type already has a superclass (`UIViewController`, a legacy base class) or isn't a class at all (**struct**, **actor**). Substitute `super.name` → `self.mock.name` and `adapt(...)` → `Mock.adapt(...)`; everything else in manual-mocking.md is unchanged.

**The macro generates the composed form itself** with `@Mockable([.composition])` — no hand-writing — when the blocker is a protocol whose conformers must inherit a class:

```swift
@Mockable([.composition])
protocol ViewControllerService: SampleBase { ... }
```

Hand-write composition only for what the macro still can't express: **structs**, **actors**, and mocking a **concrete class**.

## When to use what

| Situation | Read |
|---|---|
| Protocol has no inheritance; need a mock | `@Mockable protocol P {...}` → use `PMock()` |
| Protocol inherits another protocol with members | **manual-mocking.md** (macro cannot do this) |
| **Protocol constrained to a class** (`protocol P: SomeClass`) | `@Mockable([.composition])` — the macro handles it |
| **Mocking a class** (no protocol available) | **spies-and-composition.md** — subclass + raw `Spy` |
| **Can't inherit `Mock`** (struct, actor, or a hand-written type with a superclass) | **spies-and-composition.md** — `let mock = Mock()` |
| Mocking without any protocol (closure/TCA dependencies) | usage.md / spies-and-composition.md — `Spy` + `adapt` |
| Stubbing/verifying settable properties or subscripts (`{ get set }`) | usage.md — *Properties & subscripts*; hand-written shape in manual-mocking.md |
| Need mock source without the macro (plugin unavailable, codegen, review) | `mockable` CLI (below) when available; hand-writing per manual-mocking.md is always valid |
| `@Sendable`/Swift 6 concurrency errors when stubbing | sendable.md |
| Stubbing / matching / verifying API reference | usage.md |
| Exact signature of a public API (overloads, constraints, defaults) | `references/interface/` (below) |

## API interface

Machine-generated from the compiled modules — the authoritative signature
reference. Check these before guessing at an overload or a generic constraint:

* Core library: `references/interface/SwiftMocking.swiftinterface`
* XCTest/swift-testing helpers: `references/interface/SwiftMockingTestSupport.swiftinterface`

One caveat: `Sendable` is a marker protocol and the compiler **elides it from
`where` clauses** in emitted interfaces — `thenThrow<E: Error & Sendable>` prints
as `where E : Error`. The constraint is still enforced. For Sendable questions
trust sendable.md, not these files.


## Deterministic generation: the `mockable` CLI

When a mock must exist as written source (macro plugin unavailable, codegen pipeline, review), the `mockable` CLI is the fastest exact path. Hand-writing per manual-mocking.md is equally correct and needs nothing; use the CLI when it's available, hand-write when it isn't or when you're already customizing.

```bash
echo 'protocol P { func price(_ item: String) throws -> Int }' | mockable
```

Invoke as `mockable` when it is on `PATH`; otherwise `.build/release/mockable` inside a swift-mocking checkout (build once with `swift build -c release --product mockable`, then optionally copy the binary onto `PATH`).

- Options ride the input: `@Mockable([.suffixMock]) protocol P {...}` on stdin. `[.composition]` works here too — the fastest way to see the composed shape for a given protocol.
- Default output keeps the macro's `#if DEBUG` wrapper; pass `--no-debug-wrap` when pasting into a test target (DEBUG is per build configuration — a wrapped mock vanishes under `swift test -c release`).
- A stderr warning about inherited requirements means the output will not conform — hand-write per manual-mocking.md instead.
- Output keeps the macro's zero-arg/property-getter shape: `when(...)` silently stubs a disconnected spy, and `verify(...)` reports zero calls for those members — apply the pinned-spy fix from manual-mocking.md before relying on them.

## The one rule for manual mocks

Every protocol requirement gets **two members** in the mock class:

1. **Runtime member** — fulfills the protocol, forwards to the spy: `adapt(super.method, args)`
2. **Interaction member** — same name, `ArgMatcher<T>` parameters, returns `Interaction<Inputs..., Effect, Output>` — what `when(...)`/`verify(...)` consume

```swift
class FooMock: Mock, @unchecked Sendable, Foo {
    func price(_ item: String) throws -> Int {
        return try adaptThrowing(super.price, item)
    }
    func price(_ item: ArgMatcher<String>) -> Interaction<String, Throws, Int> {
        Interaction(item, spy: super.price)
    }
}
```

Class shell: inherit `Mock` **first**, restate `@unchecked Sendable`, conform to the most-derived protocol only, match access levels. If inheriting `Mock` isn't possible, keep both members and compose instead — `let mock = Mock()`, `super.price` → `mock.price`, `adaptThrowing(...)` → `Mock.adaptThrowing(...)` (spies-and-composition.md).

**Full recipe (inheritance flattening, properties, subscripts, variadics, generics, statics, initializers): manual-mocking.md.** Zero-parameter methods and property getters need the pinned-spy pattern described there — the macro-generated form silently mis-stubs them.

## Quick verification checklist

A correct mock (manual or generated) round-trips:

```swift
let mock = FooMock()
when(mock.price(.any)).thenReturn(42)
let svc: Foo = mock                               // protocol-typed: avoids overload traps
_ = try svc.price("apple")
verify(mock.price(.equal("apple"))).called(1)
```

## Known sharp edges

- `@Mockable` on `protocol B: A` → compile error `does not conform to protocol 'A'` (inherited requirements never generated). Hand-write per manual-mocking.md.
- `@Mockable` on `protocol P: SomeClass` → `requires that 'MockP' inherit from 'SomeClass'`. This is a **class constraint**, not protocol inheritance, and no hand-edit fixes the default output — the mock needs its superclass slot for `SomeClass`, and the default strategy needs it for `Mock`. Add `[.composition]`. The option is opt-in: the macro can't tell a class from a protocol by name, so it never infers it.
- `@Mockable` only accepts **protocols** — never a class. To fake a class, subclass it and back overrides with raw `Spy` properties (spies-and-composition.md). `final` classes/members can't be faked either way; extract a protocol.
- In a **composed** mock, plain `adapt(...)` doesn't resolve — it's an instance method on `Mock` and you didn't inherit it. Use the static `Mock.adapt(...)` / `Mock.adaptThrowing(...)`. Likewise `clear()` becomes `mock.clear()`.
- Hand-written composed mocks must spell **`self.mock.name`**, not a bare `mock.name`, wherever the spy is read inside a closure — settable members do exactly that, and Swift rejects the bare form with `requires explicit use of 'self' to make capture semantics explicit`. `super` never needed the qualifier. `[.composition]` output already does this.
- Zero-arg members (`func start()`, property getters): `when(mock.getX()).thenReturn(v)` does not reach the runtime member in macro-generated mocks. Manual mocks fix this with the pinned-spy pattern.
- Stub API is `thenReturn` / `thenThrow` / `do` — there is no `.then`.
- Spy names come from the requirement, ignoring argument labels: methods use their name, subscripts are namespaced as `subscript`+ParameterNames (`subscript(row:column:)` → `subscriptRowColumn`), settable members add `set`+Name. The prefix keeps a subscript from colliding with a method or variable of the same name. The compiler already rejects most same-key cases (two subscripts differing only by argument label, or a `var x` beside a `func x()`, are both invalid redeclarations); the one that compiles but mocks incorrectly is two *methods* differing only by argument label (`fetch(id:)`/`fetch(name:)`), which silently share a spy — rename one or vary the parameter types. Same-name/different-signature overloads are fine.
- Settable members (`{ get set }`) record reads and writes on **separate spies**: `verify(mock.x)` counts reads, `verify(mock.x <- v)` counts writes. A write never registers as a read.
- Bare `mock.start()` (zero-arg) is ambiguous on the mock type — call via a protocol-typed reference.
- **Literal arguments on the mock type dispatch to the interaction member** (`mock.fetchUser(id: "1")` returns an `Interaction` instead of calling through) — call the mock via a protocol-typed reference.

## References

- `manual-mocking.md` — hand-writing mock classes; inheritance chains; pinned-spy pattern
- `spies-and-composition.md` — using `Spy` directly; mocking classes; composing `let mock = Mock()` for structs/actors/existing superclasses
- `usage.md` — when/verify/matchers/stubbing reference
- `sendable.md` — Swift 6 concurrency contract and non-Sendable workarounds
