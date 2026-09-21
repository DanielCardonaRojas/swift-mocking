import Foundation
import SwiftMocking

final class SpyBackedImageLoader: ImageLoader, @unchecked Sendable {
    // Name the spies distinctly (loadSpy, not load) so no matcher overload
    // competes with the override.
    let loadSpy = Spy<String, Throws, Data>()
    let cacheSizeSpy = Spy<Void, None, Int>()

    override func load(_ name: String) throws -> Data { try loadSpy(name) }

    // A property getter is just an expression — pass () explicitly.
    override var cacheSize: Int { cacheSizeSpy(()) }
}
