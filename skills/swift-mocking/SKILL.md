---
name: swift-mocking
description: Use when writing Swift tests with the SwiftMocking library — creating @Mockable mocks, stubbing with when/verify, matching arguments, or hand-writing mock classes (e.g. for protocol inheritance chains the @Mockable macro cannot generate).
---

# SwiftMocking

Mocking for Swift protocols: `@Mockable` generates mock classes; `when(...)` stubs, `verify(...)` asserts calls. When the macro can't generate a mock — most notably **protocol inheritance** (`protocol B: A` — the macro drops inherited requirements and the mock fails to conform) — hand-write the mock following the exact generated-code shape.

## When to use what

| Situation | Read |
|---|---|
| Protocol has no inheritance; need a mock | `@Mockable protocol P {...}` → use `PMock()` |
| Protocol inherits another protocol with members | **manual-mocking.md** (macro cannot do this) |
| Mocking without any protocol (closure/TCA dependencies) | usage.md — `Spy` + `adapt` |
| Hand-writing any mock (macro-free, or macro plugin unavailable) | manual-mocking.md |
| `@Sendable`/Swift 6 concurrency errors when stubbing | sendable.md |
| Stubbing / matching / verifying API reference | usage.md |

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

Class shell: inherit `Mock` **first**, restate `@unchecked Sendable`, conform to the most-derived protocol only, match access levels.

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
- Zero-arg members (`func start()`, property getters): `when(mock.getX()).thenReturn(v)` does not reach the runtime member in macro-generated mocks. Manual mocks fix this with the pinned-spy pattern.
- Stub API is `thenReturn` / `thenThrow` / `do` — there is no `.then`.
- Bare `mock.start()` (zero-arg) is ambiguous on the mock type — call via a protocol-typed reference.
- **Literal arguments on the mock type dispatch to the interaction member** (`mock.fetchUser(id: "1")` returns an `Interaction` instead of calling through) — call the mock via a protocol-typed reference.

## References

- `manual-mocking.md` — hand-writing mock classes; inheritance chains; pinned-spy pattern
- `usage.md` — when/verify/matchers/stubbing reference
- `sendable.md` — Swift 6 concurrency contract and non-Sendable workarounds
