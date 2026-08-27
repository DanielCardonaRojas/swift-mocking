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
