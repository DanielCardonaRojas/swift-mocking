import Foundation

// A concrete class from a dependency you don't own. There's no protocol to
// annotate, and @Mockable only accepts protocols.
class ImageLoader {
    func load(_ name: String) throws -> Data { Data() }
    var cacheSize: Int { 0 }
}
