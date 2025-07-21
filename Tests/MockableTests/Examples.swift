
import Foundation
import Mockable
import MockableTypes

// MARK: - Function Signature Variations

@Mockable([.includeWitness])
protocol ThrowingService {
    func process() throws
}

@Mockable([.includeWitness])
protocol AsyncService {
    func load() async -> String
}

@Mockable([.includeWitness])
protocol AsyncThrowingService {
    func perform() async throws -> Data
}

@Mockable([.includeWitness])
protocol FeedService {
    func fetch(from url: URL) async throws -> Data
    func post(to url: URL, data: Data) async throws
}

@Mockable([.includeWitness])
protocol ParameterlessService {
    func doSomething() -> String
}

@Mockable([.includeWitness])
protocol ReturnlessService {
    func doSomething(with value: Int)
}

@Mockable([.includeWitness])
protocol SimpleService {
    func doSomething()
}

// MARK: - Macro Options

@Mockable([.includeWitness, .prefixMock])
protocol PrefixMockService {
    func doSomething()
}

@Mockable([.includeWitness, .suffixMock])
protocol SuffixMockService {
    func doSomething()
}

// MARK: - Protocol Features

@Mockable([.includeWitness])
public protocol PublicService {
    func doSomething()
}

// TODO: Missing support
/*
@Mockable([.includeWitness])
protocol PropertyService {
    var value: Int { get }
}

@Mockable([.includeWitness])
protocol InitializerService {
    init(value: Int)
}

@Mockable([.includeWitness])
protocol SubscriptService {
    subscript(index: Int) -> String { get }
}

@Mockable([.includeWitness])
protocol AssociatedTypeService {
    associatedtype Item
    func item() -> Item
}
*/
