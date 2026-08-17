# ``SwiftMocking``

Type-safe mocking for Swift, powered by macros.

## Overview

SwiftMocking turns any protocol into a fully featured mock with a single
`@Mockable` annotation. Describe calls with matchers, arrange behavior with
``when(_:)``, assert interactions with ``verify(_:)`` — all statically typed,
all local, with no code-generation step in your build.

```swift
import SwiftMocking

@Mockable
protocol PricingService {
    func price(for item: String) -> Int
}

let mock = MockPricingService()
when(mock.price(for: "apple")).thenReturn(13)

_ = mock.price(for: "apple")

verify(mock.price(for: .any)).called(1)
```

New to the library? The interactive tutorials walk from this exact example
through argument matchers, dynamic stubbing, and cross-mock call-order
verification. Start with
[Mock Your First Protocol](/tutorials/swiftmocking/mocking-your-first-protocol).

## Topics

### Essentials

- ``Mock``
- ``when(_:)``
- ``verify(_:)``
- ``ArgMatcher``

### Stubbing

- ``Arrange``
- ``Spy``
- ``Stub``

### Verification

- ``verifyInOrder(_:file:line:)-7ca0p``
- ``verifyNever(_:file:line:)``
- ``verifyZeroInteractions(_:file:line:)``
