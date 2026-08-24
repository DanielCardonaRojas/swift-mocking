import SwiftMocking
import Testing

@Test
func unstubbedRequirementsFallBackToZeroValues() {
    let mock = MockUserProfile()
    let profile: any UserProfile = mock

    // Nothing is stubbed. Rather than trapping, each requirement
    // returns the registered default for its type.
    #expect(profile.displayName() == "")
    #expect(profile.retryLimit() == 0)
    #expect(profile.isPremium() == false)
}
