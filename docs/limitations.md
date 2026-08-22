# Known Limitations

## Protocol Inheritance

`@Mockable` does not generate inherited requirements. For `protocol B: A` where `A` declares members, the generated mock fails to conform (`error: type 'BMock' does not conform to protocol 'A'`). Workaround: hand-write the mock. The [Agent Skill](../README.md#-agent-skill) teaches the exact recipe, or see [GENERATED_CODE_EXAMPLES.md](../GENERATED_CODE_EXAMPLES.md) for the code shapes to mirror.

## Zero-Parameter Members and Property Getters

In macro-generated mocks, stubbing zero-parameter methods (`when(mock.f()).thenReturn(v)`) and property getters (`when(mock.getX()).thenReturn(v)`) is silently ignored, and verification of those members always counts 0, because a parameter-pack shape mismatch creates a second, disconnected spy. Setters and members with one or more parameters are unaffected. Workaround: hand-write those members with the pinned-spy form documented in the [Agent Skill](../README.md#-agent-skill).

## Xcode Autocomplete

Currently, Xcode's autocomplete feature may not work as expected when using the generated mock objects. This seems to be a known issue with Xcode. This limitation could be worked around by conforming to the mocked protocol within an extension. However due to limitations of Swift macros, generating this extension will result in an error.

For example, the ideal generated code would separate the protocol conformance into an extension, like this:

```swift
// Ideal generated code
public protocol PricingService {
    func price(_ item: String) throws -> Int
}

class PricingServiceMock: Mock {
    func price(_ item: ArgMatcher<String>) -> Interaction<String, Throws, Int> {
        Interaction(item, spy: super.price)
    }
}

extension PricingServiceMock: PricingService {
    func price(_ item: String) throws -> Int {
        return try adaptThrowing(super.price, item)
    }
}

```

Xcode's autocomplete will prioritize methods in the order they are declared. Since mocks are usualy not interacted with directly we opt for declaring the Interaction methods first.

---

See also: [Usage Reference](usage.md) · [Swift 6 and Sendable](swift6-sendable.md)
