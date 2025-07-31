//
//  ExampleXCTests.swift
//  Examples
//
//  Created by Daniel Cardona on 25/07/25.
//
import XCTest
import SwiftMocking
@testable import Examples



final class MockitoTests: XCTestCase {

    func testMockitoBuilder() {
        let mock = MockPricingService()
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
        let mock = MockPricingService()
        let store = Store(pricingService: mock)
        store.register("apple")
        XCTAssertEqual(store.prices["apple"], .zero)
    }

    func test_verifyInOrder() {
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

    func test_verifyThrows() {
        let mock = MockPricingService()
        let store = Store(pricingService: mock)
        when(mock.price(.any)).thenReturn(13)
        when(mock.price("rotten")).thenThrow(TestError.example)

        store.register("apple")
        store.register("banana")
        store.register("rotten")

        verify(mock.price("rotten")).throws()
    }

    func test_inspect_arguments() {
        let mock = MockPricingService()

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
        let mockCalculator = MockCalculator()
        let even = ArgMatcher<Int>.any(that: { $0 % 2 == 0 })
        let odd = ArgMatcher<Int>.any(that: { $0 % 2 == 1 })
        when(mockCalculator.calculate(odd, odd)).then(*)
        when(mockCalculator.calculate(even, even)).then(-)
        when(mockCalculator.calculate(.any, .any)).then(+)

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
        let mock = MockAnalyticsProtocol()
        let event = TestEvent()
        mock.logEvent(event)
        verify(mock.logEvent(.any(TestEvent.self))).called()
    }

    func testStatic() {
        MockLogger.log("hello")
        MockLogger.log("hello")
        verify(MockLogger.log("hello")).called(2)
    }

    func testSubscript() {
        let mock = MockSubscriptService()
        when(mock[.any]).thenReturn("hello")
        XCTAssertEqual(mock[3], "hello")
        verify(mock[3]).called()
    }

    func testVariadic() {
        let mock = MockPrinter()
        (mock as Printer).print("hello", "___", "world")
        verify(mock.print("hello", .any, "world")).called()
    }

    func testNetworkService() async throws {
        let mock = MockNetworkService()
        let url = URL(string: "https://example.com/data")!
        let downloadURL = URL(string: "https://example.com/download")!
        let uploadURL = URL(string: "https://example.com/upload")!

        // Stub request
        when(mock.request(url: .any, method: .any, headers: .any))
            .thenReturn("{}".data(using: .utf8)!)
        let data = try await mock.request(url: url, method: "GET", headers: nil)
        XCTAssertEqual(data, "{}".data(using: .utf8)!)
        verify(mock.request(url: .equal(url), method: .equal("GET"), headers: .nil())).called(1)

        // Stub download
        when(mock.download(from: .any)).thenReturn(downloadURL)
        let downloadedUrl = try await mock.download(from: downloadURL)
        XCTAssertEqual(downloadedUrl, downloadURL)
        verify(mock.download(from: .equal(downloadURL))).called(1)

        // Stub upload
        let uploadResponseData = "Upload Success".data(using: .utf8)!
        let uploadResponse = HTTPURLResponse(url: uploadURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        when(mock.upload(to: .any, data: .any)).thenReturn((uploadResponseData, uploadResponse))
        let (responseData, response) = try await mock.upload(to: uploadURL, data: Data())
        XCTAssertEqual(responseData, uploadResponseData)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        verify(mock.upload(to: .equal(uploadURL), data: .equal(Data()))).called(1)
    }

    func testPersistenceService() throws {
        let mock = MockPersistenceService()

        // Stub save
        when(mock.save(key: .equal("myKey"), value: .any(String.self)))
        try mock.save(key: "myKey", value: "myValue")
        verify(mock.save(key: .equal("myKey"), value: .equal("myValue"))).called(1)

        // Stub load
        when(mock.load(key: "anotherKey")).thenReturn("loadedValue")
        let loadedValue: String? = try mock.load(key: "anotherKey")
        XCTAssertEqual(loadedValue, "loadedValue")
        verify(mock.load(key: .equal("anotherKey")) as Interaction<String, Throws, String?>).called(1)

        // Stub delete
        when(mock.delete(key: "deleteKey")).thenThrow(Examples.TestError.example)
        do {
            try mock.delete(key: "deleteKey")
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssert(error is TestError)
        }
        verify(mock.delete(key: "deleteKey")).throws()
    }
}
