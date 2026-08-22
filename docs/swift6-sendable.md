# Swift 6 and Sendable

`SwiftMocking` is fully Swift 6 data-race safe. The library compiles in Swift 6 language mode, and every closure it stores and later invokes across isolation domains is compiler-proven `@Sendable`.

## Mocks are Sendable

`Mock` and `Spy` are `@unchecked Sendable`, backed by real `NSLock` synchronization rather than annotation alone. All spy storage, stubs, invocations, and configuration are locked on both read and write paths. Generated mocks inherit the conformance, so:

```swift
@Mockable
protocol Loader: Sendable {          // ✅ a mock satisfies a `: Sendable` requirement
    func load(_ id: Int) async -> String
}

let mock = MockLoader()
when(mock.load(.any)).thenReturn("value")

// Share the mock across isolation domains, no warnings in Swift 6 mode
await withTaskGroup(of: String.self) { group in
    for id in 0..<10 {
        group.addTask { await mock.load(id) }   // ✅ captured in a @Sendable closure
    }
}
```

Hand-written mocks should restate the conformance: `class LoaderMock: Mock, @unchecked Sendable, Loader`.

## The `@Sendable` contract

Value-based stubbing constrains its values; closure-based stubbing constrains its captures.

| API | Requirement |
| --- | --- |
| `thenReturn(value)` | `Output: Sendable` |
| `thenThrow(error)` | `E: Error & Sendable` |
| `thenReturn { ... }` / `.do { ... }` | closure is `@Sendable`, so **captures** must be Sendable |
| Value-capturing matchers (`.equal`, `.identical`, `.contains`, `.in`, `.approximately`) | argument type `: Sendable` |
| `.any`, `.any(that:)` | unconstrained; predicates may *take* non-Sendable values |
| Default values for unstubbed returns | unconstrained |

## Working with non-Sendable types

A `@Sendable` closure may *return* a non-Sendable value; it just cannot *capture* one. So construct the value inside the handler:

```swift
// ❌ requires Receipt: Sendable
when(mock.send(.any)).thenReturn(receipt)

// ✅ constructed inside the handler, no capture
when(mock.send(.any)).thenReturn { _ in Receipt(code: 42) }

// ✅ same trick for throwing a non-Sendable error
when(mock.validate(.any)).thenReturn { _ in throw ValidationError(reason: "invalid") }
```

To match a non-Sendable argument, capture a Sendable stand-in instead of the instance:

```swift
let targetID = target.id                      // UUID is Sendable
when(mock.send(.any(that: { $0.id == targetID }))).thenReturn { _ in Receipt(code: 0) }
```

**One boundary to know:** the handler overloads for `throws`, `async`, and `async throws` spies are declared `where repeat each I: Sendable`, because they defer the invocation, so the *arguments* must be Sendable too. The handler workarounds above therefore apply as written only to synchronous, non-throwing requirements. If a requirement both `throws` (or is `async`) **and** takes a non-Sendable parameter, no handler form compiles; make the parameter type `Sendable`, or restructure the requirement to take a Sendable stand-in (an ID) instead of the object.

Mocking protocols whose requirements use non-Sendable types is otherwise fully supported; the constraints above apply only to what you hand the stubbing APIs.

## Swift 5 consumers

The toolchain floor is Swift 6.0 (Xcode 16+), unchanged. Language mode is per-module, so a target building in **Swift 5 mode** can import the library unchanged: `Sendable` *constraints* still apply (they are type-system requirements), but `@Sendable` capture violations surface as warnings rather than errors. A `Swift5CompatTests` target verifies this path continuously.

## Migration notes

If you are upgrading from a pre-Sendable version:

1. Handler closures capturing non-Sendable state no longer compile in Swift 6 mode. Construct values inside the handler, or wrap shared state in a lock or actor.
2. `thenReturn(value)`/`thenThrow` on non-Sendable types: switch to the handler form above.
3. `.any(that: { ... })` may need an explicit `@Sendable` in some positions, since inference does not always propagate through the member chain.
4. `Recorded` is no longer `Sendable` (its `arguments: [Any]` payload cannot soundly claim transfer); consume `InvocationRecorder.snapshot()` within a single isolation domain.

---

See also: [Usage Reference](usage.md) · [Known Limitations](limitations.md)
