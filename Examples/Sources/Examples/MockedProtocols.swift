import Foundation
import SwiftMocking


struct FetchClient {
    var loadNumber: () async throws -> [Int]
    var saveNumber: (Int) async throws -> Void
}

// MARK: - Function Signature Variations

@Mockable([.composition])
protocol ThrowingService {
    func process() throws
}

@Mockable([.composition])
protocol AsyncService {
    func load() async -> String
}

@Mockable([.composition])
protocol AsyncThrowingService {
    func perform() async throws -> Data
}

@Mockable([.composition])
protocol FeedService {
    func fetch(from url: URL) async throws -> Data
    func post(to url: URL, data: Data) async throws
}

@Mockable([.composition])
protocol ParameterlessService {
    func doSomething() -> String
}

@Mockable([.composition])
protocol ReturnlessService {
    func doSomething(with value: Int)
}

@Mockable([.composition])
protocol SimpleService {
    func doSomething()
}

// MARK: - Macro Options

@Mockable([.prefixMock])
protocol PrefixMockService {
    func doSomething()
}

@Mockable([.suffixMock])
protocol SuffixMockService {
    func doSomething()
}

// MARK: - Protocol Features

@Mockable([.composition])
public protocol PublicService {
    func doSomething()
}

@Mockable([.composition])
protocol PropertyService {
    var value: Int { get set }
}

@Mockable([.composition])
protocol InitializerService {
    init(value: Int)
}

@Mockable([.composition])
protocol SubscriptService {
    subscript(index: Int) -> String { get }
}

@Mockable([.composition])
protocol Printer {
    func print(_ values: String...)
}

@Mockable([.composition])
protocol AssociatedTypeService {
    associatedtype Item: Equatable
    associatedtype Payload
    func item() -> Item
    func data() -> Payload
}

@Mockable([.composition])
public protocol PricingService {
    func price(_ item: String) throws -> Int
}

@Mockable([.prefixMock, .composition])
protocol DataFetcherService {
    func fetchData(id: String) async -> String
    func fetchDataThrows(id: String) async throws -> String
}

@Mockable([.composition])
protocol Calculator {
    func calculate(_ a: Int, _ b: Int) -> Int
}

@Mockable([.composition])
protocol AnalyticsProtocol {
    func logEvent<E: Identifiable>(_ event: E)
}


@Mockable([.composition])
protocol FakeProvider {
    func fakeData<Fake: Encodable>(_ fakeType: Fake.Type) -> Data
}

@Mockable([.composition])
protocol Logger {
    static func log(_ message: String)
}

@Mockable([.composition])
protocol Countable {
    var totalCount: Int { get set }
}

@Mockable([.composition])
protocol CallbackService {
    func execute(completion: @escaping (String) -> Void)
}

// MARK: - More complex protocols

@Mockable([.composition])
protocol NetworkService {
    func request(url: URL, method: String, headers: [String: String]?) async throws -> Data
    func download(from url: URL) async throws -> URL
    func upload(to url: URL, data: Data) async throws -> (Data, URLResponse)
}

@Mockable([.composition])
protocol PersistenceService {
    func save<T: Codable>(key: String, value: T) throws
    func load<T: Codable>(key: String) throws -> T?
    func delete(key: String) throws
}

/// A non-throwing requirement whose return type has no registered default.
///
/// Used by the error-reporting tests to reach the unrecoverable path: with no stub and no
/// default to fall back on, there is nothing to return, so SwiftMocking reports and traps.
/// Types like `Int` or `String` cannot exercise this — the registry supplies a default and
/// the call succeeds.
@Mockable
protocol ProfileService {
    func profile(for id: String) -> UserProfile
}

/// A non-throwing requirement returning `Void`, which the registry supplies a default for.
///
/// Lets a test drive a non-throwing requirement without tripping the trap, so the reporting
/// behavior around that path can be observed in-process.
@Mockable
protocol ReportOnlyService {
    func record(id: String)
}

/// Calls an unstubbed, non-throwing requirement through a *generated conformance*,
/// trapping the process.
///
/// Lives in this module because `@Mockable` generates an internal mock class even for a
/// `public` protocol, so the `TrapProbe` executable cannot name `MockProfileService`
/// itself.
///
/// - Important: The trap this produces is inspected by `ErrorReportingTests`, which asserts
///   on the *frame the debugger selects*. The call below must be the topmost user frame.
public func tripUnstubbedRequirementViaConformance() -> Never {
    let mock = MockProfileService()
    // No stub, and `UserProfile` has no registered default: nothing to return, so
    // SwiftMocking reports an issue and then traps.
    _ = mock.profile(for: "alice")
    fatalError("unreachable: the unstubbed call above must trap")
}

/// Calls an unstubbed, non-throwing requirement on a *directly constructed* `Spy`.
///
/// Covers the other route into the unrecoverable path: `Spy.callAsFunction` rather than a
/// generated `Mock.adapt`. Both must attribute the trap to the caller, and they reach it
/// through different frames, so a regression can appear in one and not the other.
public func tripUnstubbedRequirementViaSpy() -> Never {
    struct NoDefault {}
    let spy = Spy<Int, None, NoDefault>()
    _ = spy(3)
    fatalError("unreachable: the unstubbed call above must trap")
}

/// Calls an unstubbed, *typed-throwing* requirement on a directly constructed `Spy`.
///
/// A fourth route, and one the throwing routes do not cover: an unstubbed call raises a
/// ``MockingError``, which is by construction not the requirement's declared `Failure` and so
/// cannot cross the `throws(Failure)` boundary. `Spy.narrow` therefore traps instead of
/// rethrowing, which makes this the one throwing effect that reaches the unrecoverable path.
///
/// Covered separately because the trap sits behind an extra hop — `callAsFunction` into
/// `process` into `narrow` — and every one of those frames must be `@_transparent` for the
/// debugger to land on the call below rather than inside `Spy.swift`.
public func tripUnstubbedTypedThrowingRequirementViaSpy() -> Never {
    struct NoDefault {}
    struct Failure: Error {}
    let spy = Spy<Int, TypedThrows<Failure>, NoDefault>()
    _ = try? spy(3)
    fatalError("unreachable: the unstubbed call above must trap")
}

/// Calls an unstubbed spy through a *closure-based dependency*.
///
/// The third route, and the one with the weakest attribution available: the closure is built
/// in one place and invoked in another, so the trap can only name where the dependency was
/// wired up. `adapt` captures that at the `adapt(spy)` call below and threads it through, so
/// the message points here rather than into `Spy.swift`.
///
/// Worth covering separately because the location has to survive two hops — `adapt` into
/// `asFunction`, and `asFunction` into the escaping closure — and dropping it at either hop
/// silently falls back to SwiftMocking's own source.
public func tripUnstubbedRequirementViaClosure() -> Never {
    struct NoDefault {}
    struct Client {
        var load: (Int) -> NoDefault
    }
    let spy = Spy<Int, None, NoDefault>()
    let client = Client(load: adapt(spy))
    _ = client.load(7)
    fatalError("unreachable: the unstubbed call above must trap")
}

/// A return type with no registered default, so an unstubbed call cannot be satisfied.
public struct UserProfile: Equatable {
    public let name: String
    public init(name: String) { self.name = name }
}

class Store {
    var items: [String] = []
    var prices: [String: Int] =  [:]
    let pricingService: any PricingService
    init<Service: PricingService>(pricingService: Service) {
        self.pricingService = pricingService
    }

    func register(_ item: String) {
        items.append(item)
        do {
            let price = try pricingService.price(item)
            prices[item] = price
        } catch {

        }
    }

    func tagPrices() {
        for item in items {
            register(item)
        }
    }
}
