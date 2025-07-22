//
//  MockitoTests.swift
//  Mockable
//
//  Created by Daniel Cardona on 7/07/25.
//

import SwiftMocking
import SwiftMockingTestSupport
import MockableTypes
import XCTest

final class MockitoTests: XCTestCase {
    func testMockitoBuilder() {
        let mock = PricingServiceMock()
        let store = Store(pricingService: mock)
        when(mock.price("apple")).thenReturn(13)
        when(mock.price("banana")).thenReturn(17)

        store.register("apple")
        store.register("banana")
        verify(mock.price(.any)).called(2)
        XCTAssertEqual(store.prices["apple"], 13)
        XCTAssertEqual(store.prices["banana"], 17)
    }

    func test_default_provider() {
        let registry = DefaultProvidableRegistry([Int.self])
        let mock = PricingServiceMock()
        mock.defaultProviderRegistry = registry
        let store = Store(pricingService: mock)
        store.register("apple")
        XCTAssertEqual(store.prices["apple"], .zero)
    }

    func test_verifyInOrder() {
        let mock = PricingServiceMock()
        let store = Store(pricingService: mock)
        when(mock.price(.any)).thenReturn(13)

        store.register("apple")
        store.register("banana")
        verifyInOrder([
            mock.price("apple"),
            mock.price("banana")
        ])
    }

    func test_verifyThrows() {
        let mock = PricingServiceMock()
        let store = Store(pricingService: mock)
        when(mock.price(.any)).thenReturn(13)
        when(mock.price("rotten")).thenThrow(TestError.example)

        store.register("apple")
        store.register("banana")
        store.register("rotten")

        verify(mock.price("rotten")).throws()
    }

    func test_inspect_arguments() {
        let mock = PricingServiceMock()

        when(mock.price(.any)).thenReturn { item in
            let priceDict = ["apple": 13, "banana": 5]
            return priceDict[item] ?? .zero
        }

        XCTAssertEqual(try mock.price("apple"), 13)
        XCTAssertEqual(try mock.price("banana"), 5)
    }

    func test_asyncDataFetcher() async throws {
        let mock = MockDataFetcherService()

        // Stub async method
        when(mock.fetchData(id: .any)).thenReturn("async_data_1")
        let data1 = await mock.fetchData(id: "id1")
        XCTAssertEqual(data1, "async_data_1")
        verify(mock.fetchData(id: "id1")).called(1)

        // Stub async throws method
        when(mock.fetchDataThrows(id: "error_id")).thenThrow(TestError.example)
        do {
            _ = try await mock.fetchDataThrows(id: "error_id")
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssert(error is TestError)
        }
        verify(mock.fetchDataThrows(id: "error_id")).throws()

        // Stub async throws method with success
        when(mock.fetchDataThrows(id: "success_id")).thenReturn("async_data_2")
        let data2 = try await mock.fetchDataThrows(id: "success_id")
        XCTAssertEqual(data2, "async_data_2")
        verify(mock.fetchDataThrows(id: "success_id")).called(1)
    }

    func testCalculate() {
        let mockCalculator = CalculatorMock()
        let even = ArgMatcher<Int>.any(that: { $0 % 2 == 0 })
        let odd = ArgMatcher<Int>.any(that: { $0 % 2 == 1 })
        when(mockCalculator.calculate(odd, odd)).thenReturn(*)
        when(mockCalculator.calculate(even, even)).thenReturn(-)
        when(mockCalculator.calculate(.any, .any)).thenReturn(+)

        XCTAssertEqual(mockCalculator.calculate(3, 3), 9, "Multiplies because both are odd")
        XCTAssertEqual(mockCalculator.calculate(3, 4), 7, "Sums because one is odd the other even")
        XCTAssertEqual(mockCalculator.calculate(18, 4), 14, "Subtracts because both are even")
    }

    func testAnalyticsEvent() {
        struct TestEvent: Identifiable {
            let id: UUID = UUID()
        }

        struct OtherEvent: Identifiable {
            let id: UUID = UUID()
        }
        let mock = AnalyticsProtocolMock()
        let event = TestEvent()
        mock.logEvent(event)
        verify(mock.logEvent(.any(TestEvent.self))).called()
    }

    func testStatic() {
        LoggerMock.log("hello")
        LoggerMock.log("hello")
        verify(LoggerMock.log("hello")).called(2)
    }

    func testSubscript() {
        let mock = SubscriptServiceMock()
        when(mock[.any]).thenReturn("hello")
        XCTAssertEqual(mock[3], "hello")
        verify(mock[3]).called()
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

@Mockable
protocol PricingService {
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

