import SwiftMocking
import Testing

// Applied to a @Suite, the trait covers every test inside it.
@Suite(.withDefaults("Anonymous"))
struct ProfileTests {
    @Test
    func inheritsTheSuiteDefault() {
        let profile: any UserProfile = MockUserProfile()
        #expect(profile.displayName() == "Anonymous")
    }

    // A test-level trait overrides the suite's value.
    @Test(.withDefaults("Override"))
    func overridesTheSuiteDefault() {
        let profile: any UserProfile = MockUserProfile()
        #expect(profile.displayName() == "Override")
    }

    // An explicit stub always beats any default.
    @Test
    func explicitStubStillWins() {
        let mock = MockUserProfile()
        when(mock.displayName()).thenReturn("Explicit")
        let profile: any UserProfile = mock
        #expect(profile.displayName() == "Explicit")
    }
}
