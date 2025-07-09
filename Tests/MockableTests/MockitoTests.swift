//
//  MockitoTests.swift
//  Mockable
//
//  Created by Daniel Cardona on 7/07/25.
//

import Mockable
import MockableTypes
import XCTest

final class MockitoTests: XCTestCase {
    func testMock() {
        let mock = MockPricingService.new()
        let spy = mock.context
        let store = Store(pricingService: mock)
        spy.price.when(calledWith:.equal("apple")).thenReturn(100)
        spy.price.when(calledWith:.equal("banana")).thenReturn(100)
        store.items = ["apple", "banana"]
        store.tagPrices()
        when(spy.price(.any)).thenReturn(100)
        XCTAssert(spy.price.verify(calledWith: .any, count: .equal(2)))
    }

    func testMockitoBuilder() {
        let mock = MockPricingService.new()
        let spy = mock.context
        let store = Store(pricingService: mock)
        when(spy.price("apple")).thenReturn(13)
        when(spy.price("banana")).thenReturn(17)

        store.register("apple")
        store.register("banana")
        verify(spy.price(.any)).called(2)
        XCTAssertEqual(store.prices["apple"], 13)
        XCTAssertEqual(store.prices["banana"], 17)
    }

    func test_verifyInOrder() {
        let mock = MockPricingService.new()
        let spy = mock.context
        let store = Store(pricingService: mock)
        when(spy.price(.any)).thenReturn(13)

        store.register("apple")
        store.register("banana")
        verifyInOrder([
            spy.price("apple"),
            spy.price("banana")
        ])
    }

    func test_verifyThrows() {
        let mock = MockPricingService.new()
        let spy = mock.context
        let store = Store(pricingService: mock)
        when(spy.price(.any)).thenReturn(13)
        when(spy.price("rotten")).thenThrow(TestError.example)

        store.register("apple")
        store.register("banana")
        store.register("rotten")

        verify(spy.price("rotten")).throws()
    }

    func test_asyncDataFetcher() async throws {
        let mock = MockDataFetcherService.new()
        let spy = mock.context

        // Stub async method
        when(spy.fetchData(id: .any)).thenReturn("async_data_1")
        let data1 = await mock.fetchData(id: "id1")
        XCTAssertEqual(data1, "async_data_1")
        verify(spy.fetchData(id: .equal("id1"))).called(1)

        // Stub async throws method
        when(spy.fetchDataThrows(id: .equal("error_id"))).thenThrow(TestError.example)
        do {
            _ = try await mock.fetchDataThrows(id: "error_id")
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssert(error is TestError)
        }
        verify(spy.fetchDataThrows(id: .equal("error_id"))).throws()

        // Stub async throws method with success
        when(spy.fetchDataThrows(id: .equal("success_id"))).thenReturn("async_data_2")
        let data2 = try await mock.fetchDataThrows(id: "success_id")
        XCTAssertEqual(data2, "async_data_2")
        verify(spy.fetchDataThrows(id: .equal("success_id"))).called(1)
    }
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

@Mockable([.includeWitness, .prefixMock])
protocol PricingService {
    func price(_ item: String) throws -> Int
}

@Mockable([.includeWitness, .prefixMock])
protocol DataFetcherService {
    func fetchData(id: String) async -> String
    func fetchDataThrows(id: String) async throws -> String
}
