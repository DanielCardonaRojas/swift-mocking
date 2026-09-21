import Testing
import SwiftMocking

@Test
func showsNewCheckoutBanner() async throws {
    // One Spy per closure. The generics are <Input..., Effect, Output>,
    // read straight off the closure's type.
    let isEnabledSpy = Spy<String, None, Bool>()        // (String) -> Bool
    let refreshSpy = Spy<Void, AsyncThrows, Void>()     // () async throws -> Void
    let recordSpy = Spy<String, Int, Throws, Void>()    // (String, Int) throws -> Void
}
