# Settable Interaction Syntax Design

Date: 2026-08-20
Status: Approved (pending implementation plan)
Scope: `@Mockable` setter verification/stubbing surface for settable subscripts and variables.

## Summary

Replace the generated `setValue(newValue:)` / `setSubscript(index:newValue:)`
interaction functions with a single read/write surface. Settable requirements
expose a `SettableInteraction` value carrying both spy bindings, and the test
operators grow `assigned:` variants so writes read like assignments:

```swift
verify(mock[.equal(1)], assigned: "one").called(1)
verify(mock.value, assigned: 7).called(1)
verifyNever(mock[.any], assigned: "deleted")
when(mock[.any], assigned: "logged").thenReturn { index, value in … }
verifyInOrder([mock[.any].set(.equal("one")), mock.fetch(.any)])
```

Get-only members are unchanged: they keep returning `Interaction`, and
`verify(getOnlyMember, assigned: x)` is a compile-time error.

## Goals

- Setter syntax that reads like assignment, for subscripts and variables.
- Compile-time rejection of `assigned:` against get-only members.
- `verifyInOrder`, `captured`, `until`, and matcher literals compose with writes.
- One concept for settable members; `setValue`/`setSubscript` functions are
  deleted (clean cutover, decided 2026-08-20).

## Non-goals

- New matcher kinds.
- Async/throws settable members (Swift has no async or throwing subscripts;
  settable protocol variables are synchronous).
- Changing the two-spy model or spy names.

## Background and constraints

- Reads and writes record on different spies because their input packs differ
  (`(indices…)` vs `(indices…, newValue)`); a `Spy` has one pack type. The
  interaction surface for a settable member must therefore carry both spy
  bindings — this is why a wrapper type is required rather than a plain
  `Interaction`.
- Swift rejects labeled subscript calls (`mock[index: 1]` → "extraneous
  argument label"), and a bare literal `mock[1]` binds to the conformance
  subscript (recording a real read). Matcher syntax is therefore mandatory:
  `mock[.equal(1)]`, `mock[.any]`.
- `ArgMatcher` is literal-expressible, so `assigned: 7` / `assigned: "one"`
  work without extra API.
- Parameter packs: appending a type after a pack expansion
  (`Interaction<repeat each Input, Output, None, Void>`) and appending a value
  after an expansion in a call are valid Swift (verified 2026-08-20 on the
  toolchain in use).

## Public API

### `SettableInteraction` (new type in `Sources/SwiftMocking/`)

```swift
/// Read/write interaction surface for a settable requirement.
/// `Input` is the read pack — the index pack for subscripts, `(Void)` for
/// variables. `Output` is the element type.
public struct SettableInteraction<each Input, Output> {
    /// Read interaction — records on the getter spy
    /// (`"subscript"` or the member name).
    public let get: Interaction<repeat each Input, None, Output>

    /// Builds the write interaction for a matched value. Injected by generated
    /// code — appending a value after a pack expansion is not expressible in a
    /// generic body on this toolchain, so the generated closure performs the
    /// append concretely.
    private let setInteraction: @Sendable (ArgMatcher<Output>) -> Interaction<repeat each Input, Output, None, Void>

    /// The write interaction for a matched value: composes with
    /// verifyInOrder, captured, until.
    public func set(_ newValue: ArgMatcher<Output>)
        -> Interaction<repeat each Input, Output, None, Void>
}

extension SettableInteraction: Sendable
where repeat each Input: Sendable, Output: Sendable
```

(Amendment during implementation, 2026-08-20: the wrapper stores a
`setInteraction` closure rather than the write `Spy` directly, for the reason
stated above; public behavior is unchanged. For variables, `mock.value` is a
function, so composing with `verifyInOrder` requires applying it first:
`mock.value(()).set(.equal(7))`.)

Instantiation packs by member kind:

| Member | `Input` | `get` type | `set` pack |
|---|---|---|---|
| `subscript(index: I) -> O { get set }` | `(I)` | `Interaction<I, None, O>` | `(I, O)` |
| `subscript(a: A, b: B) -> O { get set }` | `(A, B)` | `Interaction<A, B, None, O>` | `(A, B, O)` |
| `var value: T { get set }` | `(Void)` | `Interaction<Void, None, T>` | `(Void, T)` |

Invariant: **the write pack is the read pack plus the written value.**

### Operator overloads (`Sources/SwiftMocking/TestSupport.swift`)

Twelve thin delegates; existing `Interaction` overloads are untouched.

| Path | Value form (subscripts) | Function form (variables) |
|---|---|---|
| getter | `when/verify/verifyNever(_ w: SettableInteraction)` → `w.get` | `when/verify/verifyNever(_ f: (()) -> SettableInteraction)` → `f().get` |
| setter | same three with `assigned: ArgMatcher<Output>` → `w.set(assigned)` | same three with `assigned:` → `f().set(assigned)` |

`when(_, assigned:)` returns `Arrange<repeat each Input, Output, None, Void>`;
`thenReturn(handler:)` on it gives write side effects. `verify(_, assigned:)`
returns `Assert<repeat each Input, Output, None, Void>`, so `.called(n)`,
`.neverCalled()`, `.captured { indices…, newValue in }` work.

The function form for variables keeps `when(mock.value)`, `verify(mock.value)`,
`verifyNever(mock.value)` compiling unchanged for settable variables.

## Generator changes

### Subscripts

- Get-only requirements: interaction subscript unchanged
  (`subscript(index: ArgMatcher<Int>) -> Interaction<Int, None, String>`).
- Settable requirements: return type becomes
  `SettableInteraction<Int, String>`; body constructs
  `SettableInteraction(get: Interaction(index, spy: super.subscript),
  setter: super.setSubscript)`.
- `subscriptSetterInteraction` (the generated `setSubscript` func) is deleted.
- The conformance witness is unchanged from the 2026-08-20 settable-subscript
  work: `set { return adapt(super.setSubscript, index, newValue) }` records
  `(index, newValue)`, matching the `set` pack `(I, O)`.

### Variables

- Get-only requirements: unchanged (`func value(_ void: Void) ->
  Interaction<Void, None, T>`).
- Settable requirements: `func value(_ void: Void) ->
  SettableInteraction<Void, T>` constructing
  `SettableInteraction(get: Interaction(void, spy: super.value),
  setter: super.setValue)`.
- `createSetterInteraction` (the generated `setValue` func) is deleted.
- Conformance witness setter becomes
  `set { return adapt(super.setValue, (), newValue) }` — the write pack
  changes from `(T)` to `(Void, T)`, enforcing the invariant above. This is
  internal-only after the cutover: no user code touches the setter spy
  directly.

### Spy model (unchanged)

Two spies per settable member — `name`/`setValue`, `subscript`/`setSubscript` —
keyed by name in `Mock._spies` with distinct pack specializations. Writes and
reads verify independently.

## Migration

- `Examples/Tests/ExampleXCTests.swift` and `ExamplesTests.swift`: the two
  `verify(mock.setValue(newValue: .equal(7))).called(1)` call sites become
  `verify(mock.value, assigned: .equal(7)).called(1)`.
- `Tests/SwiftMockingTests/SubscriptInteractionTests.swift`: setter tests
  rewritten to `assigned:` syntax.
- Macro fixtures updated/added: settable subscript expansion (no
  `setSubscript` func, `SettableInteraction` return), settable variable
  expansion, get-only fixtures bit-identical to today.
- Breaking change (accepted): for settable variables, `mock.value`'s type
  changes from `(Void) -> Interaction<Void, None, T>` to
  `(Void) -> SettableInteraction<Void, T>`. Direct syntax keeps compiling via
  the new overloads; code that stores the bare function into an explicitly
  typed `(()) -> Interaction` value breaks.

## Testing

- Macro (`Tests/SwiftMockingMacrosTests/`): expansion fixtures for settable
  and get-only subscripts/variables (including static members, to cover
  modifier passthrough).
- Runtime (`Tests/SwiftMockingTests/`):
  - Getter stubbing/verification through the wrapper (`when(mock[.any])`,
    `verify(mock.value)`) — regression guard for the new overloads.
  - `verify(_, assigned:)` with explicit and literal matchers; counted calls.
  - `verifyNever(_, assigned:)`.
  - `when(_, assigned:).thenReturn(handler:)` write side effects.
  - `verifyInOrder([…, w.set(…)])` and `captured { indices, newValue in }`.
  - Get/set spy independence (reads don't count as writes, and vice versa).
  - `verify(getOnly, assigned:)` being a compile-time error is a property of
    the types (no `SettableInteraction` exists for get-only members); the repo
    has no compile-failure fixture harness, so this is spot-checked manually
    during implementation rather than automated.
- `swift test --parallel` at the repo root and the `Examples/` package suite
  must both pass.

## Risks and edge cases

- **Overload ambiguity** between `(()) -> Interaction` and
  `(()) -> SettableInteraction` forms: distinct parameter types; resolution is
  exact-match, verified by the regression tests above.
- **Pack-append expressions** (`repeat each … , Output` in generic-argument
  and call positions) are relied on by `SettableInteraction.set`; syntax was
  spike-verified; implementation includes a compile smoke test.
- **Descriptions/debug output** for variable writes now show the leading
  `()` argument — cosmetic, consistent with variable reads.
- **`until`** takes `Interaction`, not the wrapper; the getter path composes
  via `w.get`, the write path via `w.set(…)`; no new `until` overloads.

## Decisions

1. Replace (not add alongside) `setValue`/`setSubscript` — user, 2026-08-20.
2. Wrapper type over runtime name-lookup — compile-time safety preferred —
   user, 2026-08-20.
3. Type named `SettableInteraction` over `DeferredInteraction` — matches
   Swift's `{ get set }` vocabulary — user, 2026-08-20.
4. Variable write pack becomes `(Void, T)` to keep one generic wrapper shape —
   user, 2026-08-20.
