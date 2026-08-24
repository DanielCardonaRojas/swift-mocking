import SwiftMocking
import Testing

// `.withDefaults` injects values for unstubbed requirements,
// matched by type. Here every unstubbed String returns "Guest".
@Test(.withDefaults("Guest", 5, true))
func customDefaultsPerTest() {
    let mock = MockUserProfile()
    let profile: any UserProfile = mock

    #expect(profile.displayName() == "Guest")
    #expect(profile.retryLimit() == 5)
    #expect(profile.isPremium() == true)
}
