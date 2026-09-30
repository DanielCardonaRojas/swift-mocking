struct FeatureFlagClient {
    var isEnabled: (String) -> Bool
    var refresh: () async throws -> Void
    var record: (String, Int) throws -> Void
}

@MainActor
final class RolloutModel {
    private let client: FeatureFlagClient
    private(set) var banner: String = ""

    init(client: FeatureFlagClient) { self.client = client }

    func onAppear() async throws {
        try await client.refresh()
        banner = client.isEnabled("checkout-v2") ? "New checkout" : "Classic checkout"
        try client.record("checkout-v2", 1)
    }
}
