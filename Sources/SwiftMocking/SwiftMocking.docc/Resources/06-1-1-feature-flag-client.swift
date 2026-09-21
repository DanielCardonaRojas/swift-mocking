// No protocol in sight — the dependency is a struct of closures.
struct FeatureFlagClient {
    var isEnabled: (String) -> Bool
    var refresh: () async throws -> Void
    var record: (String, Int) throws -> Void
}
