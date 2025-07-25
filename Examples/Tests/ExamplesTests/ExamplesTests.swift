import Testing
import SwiftMocking
import Foundation
@testable import Examples

@Test func example() async throws {
    MockLogger.clear()
    MockLogger.log("hello")
    MockLogger.log("hello")
    verify(MockLogger.log("hello")).called(2)
}
@Test func testMockitoBuilder() {
    let mock = MockPricingService()
    let store = Store(pricingService: mock)
    when(mock.price("apple")).thenReturn(13)
    when(mock.price("banana")).thenReturn(17)

    store.register("apple")
    store.register("banana")
    verify(mock.price(.any)).called(2)
    #expect(store.prices["apple"] == 13)
    #expect(store.prices["banana"] == 17)
}

@Test func test_default_provider() {
    let mock = MockPricingService()
    let store = Store(pricingService: mock)
    store.register("apple")
    #expect(store.prices["apple"] == .zero)
}

@Test func test_verifyInOrder() {
    let mock = MockPricingService()
    let store = Store(pricingService: mock)
    when(mock.price(.any)).thenReturn(13)

    store.register("apple")
    store.register("banana")
    verifyInOrder([
        mock.price("apple"),
        mock.price("banana")
    ])
}

@Test func test_verifyThrows() {
    let mock = MockPricingService()
    let store = Store(pricingService: mock)
    when(mock.price(.any)).thenReturn(13)
    when(mock.price("rotten")).thenThrow(TestError.example)

    store.register("apple")
    store.register("banana")
    store.register("rotten")

    verify(mock.price("rotten")).throws()
}

@Test func test_inspect_arguments() throws {
    let mock = MockPricingService()

    when(mock.price(.any)).thenReturn { item in
        let priceDict = ["apple": 13, "banana": 5]
        return priceDict[item] ?? .zero
    }

    #expect(try mock.price("apple") == 13)
    #expect(try mock.price("banana") == 5)
}

@Test func test_asyncDataFetcher() async throws {
    let mock = MockDataFetcherService()

    // Stub async method
    when(mock.fetchData(id: .any)).thenReturn("async_data_1")
    let data1 = await mock.fetchData(id: "id1")
    #expect(data1 == "async_data_1")
    verify(mock.fetchData(id: "id1")).called(1)

    // Stub async throws method
    when(mock.fetchDataThrows(id: "error_id")).thenThrow(TestError.example)
    do {
        _ = try await mock.fetchDataThrows(id: "error_id")
        Issue.record("Should have thrown an error")
    } catch {
        #expect(error is TestError)
    }
    verify(mock.fetchDataThrows(id: "error_id")).throws()

    // Stub async throws method with success
    when(mock.fetchDataThrows(id: "success_id")).thenReturn("async_data_2")
    let data2 = try await mock.fetchDataThrows(id: "success_id")
    #expect(data2 == "async_data_2")
    verify(mock.fetchDataThrows(id: "success_id")).called(1)
}

@Test func testCalculate() {
    let mockCalculator = MockCalculator()
    let even = ArgMatcher<Int>.any(that: { $0 % 2 == 0 })
    let odd = ArgMatcher<Int>.any(that: { $0 % 2 == 1 })
    when(mockCalculator.calculate(odd, odd)).thenReturn(*)
    when(mockCalculator.calculate(even, even)).thenReturn(-)
    when(mockCalculator.calculate(.any, .any)).thenReturn(+)

    #expect(mockCalculator.calculate(3, 3) == 9, "Multiplies because both are odd")
    #expect(mockCalculator.calculate(3, 4) == 7, "Sums because one is odd the other even")
    #expect(mockCalculator.calculate(18, 4) == 14, "Subtracts because both are even")
}

@Test func testAnalyticsEvent() {
    struct TestEvent: Identifiable {
        let id: UUID = UUID()
    }

    struct OtherEvent: Identifiable {
        let id: UUID = UUID()
    }
    let mock = MockAnalyticsProtocol()
    let event = TestEvent()
    mock.logEvent(event)
    verify(mock.logEvent(.any(TestEvent.self))).called()
}

@Test func testStatic() {
    MockLogger.clear()
    MockLogger.log("hello")
    MockLogger.log("hello")
    verify(MockLogger.log(.any)).called(2)
}

@Test func testSubscript() {
    let mock = MockSubscriptService()
    when(mock[.any]).thenReturn("hello")
    #expect(mock[3] == "hello")
    verify(mock[3]).called()
}
