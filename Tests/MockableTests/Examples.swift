
import Foundation
import Mockable
import MockableTypes

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
protocol AssociatedTypeService {
    associatedtype Item: Equatable
    associatedtype Payload
    func item() -> Item
    func data() -> Payload
}
