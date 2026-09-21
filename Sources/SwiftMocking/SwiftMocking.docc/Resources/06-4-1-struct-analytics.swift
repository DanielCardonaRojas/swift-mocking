import SwiftMocking

// A struct can't inherit from Mock — so hold one instead.
struct StructAnalytics: MockProviding {
    let mock = Mock()

    func track(_ event: String) {
        return Mock.adapt(self.mock.track, event)
    }

    func track(_ event: ArgMatcher<String>) -> Interaction<String, None, Void> {
        Interaction(event, spy: self.mock.track)
    }
}
