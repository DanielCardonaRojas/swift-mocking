# ``SwiftMocking``

Type-safe mocking for Swift, powered by macros.

## Overview

SwiftMocking turns any protocol into a fully featured mock with a single
`@Mockable` annotation. Describe calls with matchers, arrange behavior with
``when(_:)-1t69o``, assert interactions with ``verify(_:)-2pseu`` — all statically typed,
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
- ``when(_:)-1t69o``
- ``verify(_:)-2pseu``
- ``ArgMatcher``

### Stubbing

- ``Arrange``
- ``Spy``
- ``Stub``

### Settable Requirements

Settable properties and subscripts (`{ get set }`) record reads and writes on
separate spies. Their interaction member returns a ``SettableInteraction``,
which addresses reads directly and writes through the `<-` operator.

- ``SettableInteraction``
- ``<-(_:_:)-kz9a``
- ``<-(_:_:)-67g91``

### Verification

- ``verifyInOrder(_:file:line:)-7ca0p``
- ``verifyNever(_:file:line:)-14uw9``
- ``verifyZeroInteractions(_:file:line:)``
