import Foundation

struct FeedController {
    let fetch: @Sendable (URL) async throws -> Data

    func load(url: URL) {
        Task {
            _ = try? await fetch(url)
        }
    }
}
