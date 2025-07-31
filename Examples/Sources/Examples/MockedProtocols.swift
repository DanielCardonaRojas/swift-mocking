import Foundation
import SwiftMocking



// MARK: - Function Signature Variations

@Mockable
protocol ThrowingService {
    func process() throws
}

@Mockable
protocol AsyncService {
    func load() async -> String
}

@Mockable
protocol AsyncThrowingService {
    func perform() async throws -> Data
}

@Mockable
protocol FeedService {
    func fetch(from url: URL) async throws -> Data
    func post(to url: URL, data: Data) async throws
}

@Mockable
protocol ParameterlessService {
    func doSomething() -> String
}

@Mockable
protocol ReturnlessService {
    func doSomething(with value: Int)
}

@Mockable
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

@Mockable
public protocol PublicService {
    func doSomething()
}

@Mockable
protocol PropertyService {
    var value: Int { get set }
}

@Mockable
protocol InitializerService {
    init(value: Int)
}

@Mockable
protocol SubscriptService {
    subscript(index: Int) -> String { get }
}

@Mockable
protocol Printer {
    func print(_ values: String...)
}

@Mockable
protocol AssociatedTypeService {
    associatedtype Item: Equatable
    associatedtype Payload
    func item() -> Item
    func data() -> Payload
}

@Mockable
public protocol PricingService {
    func price(_ item: String) throws -> Int
}

@Mockable([.prefixMock])
protocol DataFetcherService {
    func fetchData(id: String) async -> String
    func fetchDataThrows(id: String) async throws -> String
}

@Mockable
protocol Calculator {
    func calculate(_ a: Int, _ b: Int) -> Int
}

@Mockable
protocol AnalyticsProtocol {
    func logEvent<E: Identifiable>(_ event: E)
}

@Mockable
protocol Logger {
    static func log(_ message: String)
}

@Mockable
protocol Countable {
    var totalCount: Int { get set }
}

@Mockable
protocol CallbackService {
    func execute(completion: @escaping (String) -> Void)
}

// MARK: - More complex protocols

@Mockable
protocol NetworkService {
    func request(url: URL, method: String, headers: [String: String]?) async throws -> Data
    func download(from url: URL) async throws -> URL
    func upload(to url: URL, data: Data) async throws -> (Data, URLResponse)
}

@Mockable
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
