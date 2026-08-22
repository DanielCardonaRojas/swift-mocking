# SwiftMocking Sendable & Swift 6 Concurrency

SwiftMocking (post-`#87`/`#92`/`#94`, 2026) is fully Swift 6 data-race safe. This is the contract.

## What is Sendable now

| Type | Status | Why it's honest |
|---|---|---|
| `Mock` | `@unchecked Sendable` | All state behind `NSLock` (spy storage, config) |
| `Spy` | `@unchecked Sendable` | Invocations/stubs/actions fully locked |
| `AnySpy` | `Sendable` | Sound once `Spy` is |
| Generated mocks | `Sendable` | Inherit from `Mock`; **restate `@unchecked Sendable`** in the inheritance clause (since `#94`) |
| Manual mocks | `Sendable` | Same: `class FooMock: Mock, @unchecked Sendable, Foo` |
| `Recorded` | **not** `Sendable` | Type-erased `arguments: [Any]`; consume `InvocationRecorder.snapshot()` in one isolation domain |

Consequences you can rely on:
- Mocks cross isolation domains freely; share them into `@Sendable` closures and task groups.
- A mock satisfies a `: Sendable` protocol requirement (`protocol P: Sendable`).
- The library itself compiles in Swift 6 language mode; your Swift 5-mode module can import it unchanged (toolchain floor is Swift 6.0 / Xcode 16+, unchanged).

## Mandatory `@Sendable` — the constraint table

Every closure the library stores and later invokes (possibly across isolation domains) is compiler-proven `@Sendable`. Value APIs constrain their values instead.

| API | Requirement | Enforced |
|---|---|---|
| `thenReturn(value)` | `Output: Sendable` | All modes (type-system constraint) |
| `thenThrow(error)` | `E: Error & Sendable` | All modes |
| `thenReturn { args in ... }` (handler) | closure is `@Sendable` — **captures** must be Sendable | Caller's module: Swift 6 = error, Swift 5 = warning |
| `.do { ... }` (side-effect handler) | same | same |
| Value-capturing matchers (`.equal`, `.identical`, `.contains`, `.in`, `.approximately`, key-path `any(where:)`) | argument type `: Sendable` | All modes |
| Deferred handler overloads for async/throwing spies where **arguments** are non-Sendable | `each I: Sendable` | All modes |
| Default-value fallback for unstubbed returns | unconstrained (values stored directly, no closure capture) | — |
| Sync, non-throwing handler stubbing with non-Sendable args | works (runs inline) | — |

## Workarounds for non-Sendable types

From `NonSendableFixturesTests` / audit §4 — locked in by tests:

**Stub a non-Sendable return**: don't capture it — construct it inside the handler. A `@Sendable` closure may *return* a non-Sendable type; it just can't *capture* one.
```swift
when(mock.send(.any)).thenReturn { _ in NonSendableReceipt(code: 42) }
```

**Throw a non-Sendable error**: same trick.
```swift
when(mock.validate(.any)).thenReturn { _ in throw NonSendableValidationError(reason: "invalid") }
```

⚠️ **Boundary:** the handler overloads for `throws`/`async`/`async throws` spies are
declared `where repeat each I: Sendable` (they defer the invocation), so the
*arguments* must be Sendable as well. The two workarounds above compile as written
only for **synchronous, non-throwing** requirements. A requirement that both throws
(or is async) *and* takes a non-Sendable parameter has no working handler form —
make the parameter `Sendable`, or have it take an ID instead of the object.

**Match a non-Sendable argument**: `.any` and `.any(that:)` are fine — the predicate may *take* non-Sendable params; only its *captures* must be Sendable. Compare identity by capturing a Sendable stand-in:
```swift
let targetID = target.id  // UUID is Sendable
when(mock.send(.any(that: { $0.id == targetID }))).thenReturn { _ in ... }
```

**Default values for non-Sendable returns**: register a provider; still unconstrained.
```swift
var registry = DefaultProvidableRegistry.default
registry.register(DefaultProviding(NonSendableMessage.self, create: { NonSendableMessage() }))
mock.defaultProviderRegistry = registry
```

## Migration notes (from pre-Sendable versions)

1. Handler closures capturing non-Sendable state no longer compile in Swift 6 mode. Wrap shared state in a locked box or actor, or construct values inside the handler.
2. `thenReturn(value)`/`thenThrow` on non-Sendable types: switch to handler form (above).
3. `.any(that: { ... })` may need an explicit `@Sendable` in some positions — inference doesn't always propagate through the member chain.
4. Hand-written mocks predating `#94`: add `@unchecked Sendable` back to the inheritance clause or Swift 6 warns about the redundant/missing restatement.

## Thread-safety in tests

- Static mocks use lock-backed static storage; safe under `withTaskGroup` concurrency (see `MockLogger.clear()` between tests).
- Ten `race_condition` regression tests ship in the suite; they only bite under Thread Sanitizer (`swift test --sanitize=thread --filter race_condition`).
