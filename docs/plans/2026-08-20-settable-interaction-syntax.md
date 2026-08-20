# Settable Interaction Syntax Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace generated `setValue`/`setSubscript` functions with a `SettableInteraction` wrapper and `assigned:` operator variants so writes verify as `verify(mock[.equal(1)], assigned: "one").called(1)`.

**Architecture:** A public `SettableInteraction<each Input, Output>` value carries both spy bindings (read spy + write spy); `when`/`verify`/`verifyNever` gain value-form, function-form, and `assigned:` overloads delegating to `w.get` / `w.set(...)`. The generator emits the wrapper for settable requirements only; variable conformance setters record on the `(Void, T)` pack so "writes = reads' pack + newValue" holds uniformly. Spec: `docs/superpowers/specs/2026-08-20-settable-interaction-syntax-design.md`.

**Tech Stack:** Swift 5.9 parameter packs, SwiftSyntax (generator), MacroTesting (`assertMacro`), XCTest.

**Execution note:** User commanded in-session implementation. SwiftSyntax trivia output is pinned by running fixtures and pasting actual output rather than hand-guessing (established workflow this branch).

---

### Task 1: `SettableInteraction` runtime type

**Files:**
- Create: `Sources/SwiftMocking/SettableInteraction.swift`

**Step 1:** Write the type. `Interaction`'s `init(invocationMatcher:spy:)` is internal — same module, usable directly.

```swift
public struct SettableInteraction<each Input, Output> {
    public let get: Interaction<repeat each Input, None, Output>
    private let setter: Spy<repeat each Input, Output, None, Void>

    public init(
        get: Interaction<repeat each Input, None, Output>,
        setter: Spy<repeat each Input, Output, None, Void>
    ) {
        self.get = get
        self.setter = setter
    }

    public func set(_ newValue: ArgMatcher<Output>)
        -> Interaction<repeat each Input, Output, None, Void>
    {
        Interaction(
            invocationMatcher: InvocationMatcher(
                matchers: repeat each get.invocationMatcher.matchers, newValue
            ),
            spy: setter
        )
    }
}

extension SettableInteraction: Sendable where repeat each Input: Sendable, Output: Sendable { }
```

DocC comment per repo convention, referencing `verify(_:assigned:)` examples.

**Step 2:** `swift build --target SwiftMocking` — expect success. Pack-append syntax (`repeat each … , newValue` in call position, `repeat each Input, Output` in generic args) is spike-verified; this is the compile smoke test from the spec's risk section.

**Step 3:** Commit: `Add SettableInteraction wrapper type`.

### Task 2: Operator overloads

**Files:**
- Modify: `Sources/SwiftMocking/TestSupport.swift` (append after existing `when`/`verify`/`verifyNever` overloads)

**Step 1:** Add 12 delegates:

```swift
public func when<each Input, Output>(
    _ interaction: SettableInteraction<repeat each Input, Output>
) -> Arrange<repeat each Input, None, Output> {
    when(interaction.get)
}

public func when<each Input, Output>(
    _ interaction: (()) -> SettableInteraction<repeat each Input, Output>
) -> Arrange<repeat each Input, None, Output> {
    when(interaction().get)
}

public func when<each Input, Output>(
    _ interaction: SettableInteraction<repeat each Input, Output>,
    assigned newValue: ArgMatcher<Output>
) -> Arrange<repeat each Input, Output, None, Void> {
    when(interaction.set(newValue))
}

public func when<each Input, Output>(
    _ interaction: (()) -> SettableInteraction<repeat each Input, Output>,
    assigned newValue: ArgMatcher<Output>
) -> Arrange<repeat each Input, Output, None, Void> {
    when(interaction().set(newValue))
}
```

…and the same four shapes for `verify` (returning `Assert`) and `verifyNever` (with `file:`/`line:`). Each `assigned:` overload delegates to `.set(assigned)`.

**Step 2:** `swift build --target SwiftMocking` — success. (Runtime behavior is exercised end-to-end in Task 5 via generated mocks; hand-building spies adds no signal over that.)

**Step 3:** Commit: `Add assigned: operator variants for settable interactions`.

### Task 3: Generator — settable subscripts emit the wrapper

**Files:**
- Modify: `Tests/SwiftMockingMacrosTests/ProtocolFeaturesTests.swift` (fixture first)
- Modify: `Sources/MockableGenerator/MockableGenerator+Interactions.swift`

**Step 1 (failing test):** Rewrite `testProtocolWithSettableSubscript`'s expected expansion: interaction subscript returns `SettableInteraction<Int, String >`, body `SettableInteraction(get: Interaction(index, spy: super.subscript), setter: super.setSubscript)`; no `func setSubscript`. Run `swift test --filter ProtocolFeaturesTests` — expect exactly that fixture to FAIL.

**Step 2:** In `MockableGenerator+Interactions.swift`:
- `processSubscript`: if `hasSetter`, generate a settable interaction subscript instead of the getter subscript; delete `subscriptSetterInteraction` entirely.
- New `createSettableInteractionReturnType(inputTypes:outputType:genericParameterClause:)` producing `SettableInteraction<I1, …, Output >` (reuse `removeAttributes`; same trailing-space trivia as `Interaction` return types so fixtures stay consistent).
- New `createSettableFunctionBody(getterSpy:setterSpy:parameterNames:)` producing `SettableInteraction(get: Interaction(params…, spy: super.<getter>), setter: super.<setter>)`.

**Step 3:** Re-run fixture — pass. `swift build --build-tests` — success (old runtime tests using `setSubscript(index:newValue:)` will now fail to compile; that's Task 5's rewrite — if so, temporarily expect compile failure here and fix in Task 5, OR fold Task 5's subscript-test rewrite into this commit. Preferred: keep suites green per commit → rewrite the four setter runtime tests in the same commit).

**Step 4:** Commit: `Emit SettableInteraction for settable subscripts` (generator + fixtures + SubscriptInteractionTests setter rewrite to `assigned:`).

### Task 4: Generator — settable variables emit the wrapper; writes record `(Void, T)`

**Files:**
- Modify: `Tests/SwiftMockingMacrosTests/ProtocolFeaturesTests.swift` (new `testProtocolWithSettableProperty`)
- Modify: `Sources/MockableGenerator/MockableGenerator+Interactions.swift`, `MockableGenerator+ProtocolConformance.swift`

**Step 1 (failing test):** Add fixture `var value: Int { get set }` expecting: `func value(_ void: Void) -> SettableInteraction<Void, Int >` with body `SettableInteraction(get: Interaction(.any, spy: super.value), setter: super.setValue)`; conformance `set { return adapt(super.setValue, (), newValue) }`. Run — expect FAIL.

**Step 2:**
- `processVar`: settable → getter-interaction func returns `SettableInteraction<Void, T >`; delete `createSetterInteraction` and its call.
- `variableRequirement`: setter body parameters become `()` + `newValue`. Refactor `adaptCall` to take `[ExprSyntax]` (call sites: `baseFunctionRequirementBody`, `subscriptRequirement` build `DeclReferenceExprSyntax` from tokens) so the tuple `()` can be passed as `TupleExprSyntax(elements: [])`.

**Step 3:** Fixture pass + `swift build --build-tests` (Examples still references `mock.setValue` — fixed in Task 6; root suite must be green here).

**Step 4:** Commit: `Emit SettableInteraction for settable variables`.

### Task 5: Runtime tests for the new surface

**Files:**
- Modify: `Tests/SwiftMockingTests/SubscriptInteractionTests.swift` (add settable-var protocol + tests)

**Step 1:** Add `@Mockable protocol MutableService { var flag: Bool { get set } }` (or similar) and tests: wrapper getter stubbing (`when(mock.value).thenReturn(…)` — regression for function-form overload), `verify(mock.value, assigned: true).called(1)`, literal matchers, `verifyNever(_, assigned:)`, `when(_, assigned:).thenReturn(handler:)` write side effect, `verifyInOrder([mock.value.set(.equal(7)), …])`, `captured { _, newValue in }`, get/set independence. Subscript-side `assigned:` tests landed in Task 3.

**Step 2:** `swift test --filter SubscriptInteractionTests` — pass.

**Step 3:** Commit: `Cover assigned: interactions at runtime`.

### Task 6: Migrate Examples

**Files:**
- Modify: `Examples/Tests/ExampleXCTests.swift:259`, `Examples/Tests/ExamplesTests.swift:211` (paths per earlier grep)

**Step 1:** Replace `verify(mock.setValue(newValue: .equal(7))).called(1)` with `verify(mock.value, assigned: .equal(7)).called(1)`; update adjacent comments.

**Step 2:** `cd Examples && swift test` — 26 tests pass.

**Step 3:** Commit: `Migrate Examples to assigned: setter verification`.

### Task 7: Final verification

- `swift test --parallel` at root — exit 0.
- `cd Examples && swift test` — exit 0.
- Spot-check (scratch file, not committed): `verify(mock.counter, assigned: 5)` against a get-only var → expect compile error `extra argument 'assigned'`; delete scratch.
- Grep guard: no `setValue(`/`setSubscript(` generation or usage remains: `grep -rn "setSubscript\|setValue" Sources Examples Tests` — only conformance-internal `super.setValue`/`super.setSubscript` spy references and generator name literals remain.
