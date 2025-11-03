import Testing
import SwiftMocking
import Foundation
@testable import Examples


@Suite(.serialized)
struct ExampleTests {
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

    @Test func test_crossSpyVerifyInOrder_sameMockDifferentMethods() async throws {
        let mock = MockNetworkService()
        let requestURL = URL(string: "https://example.com/request")!
        let downloadURL = URL(string: "https://example.com/download")!
        let uploadURL = URL(string: "https://example.com/upload")!
        let uploadPayload = Data()
        let uploadResponse = HTTPURLResponse(
            url: uploadURL,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )!

        when(mock.request(url: .equal(requestURL), method: .equal("GET"), headers: .nil()))
            .thenReturn(Data("{}".utf8))
        when(mock.download(from: .equal(downloadURL)))
            .thenReturn(downloadURL)
        when(mock.upload(to: .equal(uploadURL), data: .equal(uploadPayload)))
            .thenReturn((Data("uploaded".utf8), uploadResponse))

        _ = try await mock.request(url: requestURL, method: "GET", headers: nil)
        _ = try await mock.download(from: downloadURL)
        _ = try await mock.upload(to: uploadURL, data: uploadPayload)

        let verifiables: [any CrossSpyVerifiable] = [
            mock.request(url: .equal(requestURL), method: .equal("GET"), headers: .nil()),
            mock.download(from: .equal(downloadURL)),
            mock.upload(to: .equal(uploadURL), data: .equal(uploadPayload))
        ]
        verifyInOrder(verifiables)
    }

    @Test func test_crossSpyVerifyInOrder_differentMocks() throws {
        struct PurchaseEvent: Identifiable {
            let id = UUID()
            let item: String
        }

        let pricing = MockPricingService()
        let analytics = MockAnalyticsProtocol()

        when(pricing.price("apple")).thenReturn(13)
        when(pricing.price("banana")).thenReturn(21)

        _ = try pricing.price("apple")
        let event = PurchaseEvent(item: "apple")
        analytics.logEvent(event)
        _ = try pricing.price("banana")

        let verifiables: [any CrossSpyVerifiable] = [
            pricing.price("apple"),
            analytics.logEvent(.any(PurchaseEvent.self)),
            pricing.price("banana")
        ]
        verifyInOrder(verifiables)
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
        await verify(mock.fetchDataThrows(id: "error_id")).throws()

        // Stub async throws method with success
        when(mock.fetchDataThrows(id: "success_id")).thenReturn("async_data_2")
        let data2 = try await mock.fetchDataThrows(id: "success_id")
        #expect(data2 == "async_data_2")
        verify(mock.fetchDataThrows(id: "success_id")).called(1)
    }

    @Test func test_until_waitsForBackgroundInteraction() async throws {
        let spy = Spy<URL, AsyncThrows, Data>()
        let url = URL(string: "https://example.com/feed")!
        let response = Data("feed".utf8)

        when(spy(.equal(url))).thenReturn { _ in
            try await Task.sleep(for: .milliseconds(15))
            return response
        }

        let controller = FeedController(fetch: adapt(spy))
        controller.load(url: url)

        try await until(spy(.equal(url)))
        verify(spy(.equal(url))).called()
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

    @Test func testSubscript() {
        let mock = MockSubscriptService()
        when(mock[.any]).thenReturn("hello")
        #expect(mock[3] == "hello")
        verify(mock[3]).called()
    }

    @Test func testNetworkService() async throws {
        let mock = MockNetworkService()
        let url = URL(string: "https://example.com/data")!
        let downloadURL = URL(string: "https://example.com/download")!
        let uploadURL = URL(string: "https://example.com/upload")!

        // Stub request
        when(mock.request(url: .any, method: .any, headers: .any))
            .thenReturn("{}".data(using: .utf8)!)
        let data = try await mock.request(url: url, method: "GET", headers: nil)
        #expect(data == "{}".data(using: .utf8)!)
        verify(mock.request(url: .equal(url), method: .equal("GET"), headers: .nil())).called(1)

        // Stub download
        when(mock.download(from: .any)).thenReturn(downloadURL)
        let downloadedUrl = try await mock.download(from: downloadURL)
        #expect(downloadedUrl == downloadURL)
        verify(mock.download(from: .equal(downloadURL))).called(1)

        // Stub upload
        let uploadResponseData = "Upload Success".data(using: .utf8)!
        let uploadResponse = HTTPURLResponse(url: uploadURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        when(mock.upload(to: .any, data: .any)).thenReturn((uploadResponseData, uploadResponse))
        let (responseData, response) = try await mock.upload(to: uploadURL, data: Data())
        #expect(responseData == uploadResponseData)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        verify(mock.upload(to: .equal(uploadURL), data: .equal(Data()))).called(1)
    }

    @Test func testPersistenceService() throws {
        let mock = MockPersistenceService()

        // Stub save
        when(mock.save(key: .equal("myKey"), value: .any(String.self)))
        try mock.save(key: "myKey", value: "myValue")
        verify(mock.save(key: .equal("myKey"), value: .equal("myValue"))).called(1)

        // Stub load
        when(mock.load(key: "anotherKey")).thenReturn("loadedValue")
        let loadedValue: String? = try mock.load(key: "anotherKey")
        #expect(loadedValue == "loadedValue")
        verify(mock.load(key: .equal("anotherKey")) as Interaction<String, Throws, String?>).called(1)

        // Stub delete
        when(mock.delete(key: "deleteKey")).thenThrow(Examples.TestError.example)
        do {
            try mock.delete(key: "deleteKey")
            Issue.record("Should have thrown an error")
        } catch {
            #expect(error is TestError)
        }
        verify(mock.delete(key: "deleteKey")).throws()
    }

    @Test func testCallbackService() {
        let mock = MockCallbackService()
        let expectation = "test"

        var capturedValue: String?
        when(mock.execute(completion: .any)).thenReturn { completion in
            completion(expectation)
        }

        mock.execute { value in
            capturedValue = value
        }

        #expect(capturedValue == expectation)
        verify(mock.execute(completion: .any)).called()
    }

    @Test func testNeverCalledSucceedsWhenMethodNotCalled() {
        let mock = MockPricingService()
        verify(mock.price(.any)).neverCalled()
    }

    @Test func testNeverCalledWithSpecificArguments() {
        let mock = MockPricingService()
        when(mock.price("apple")).thenReturn(13)

        let _ = try? mock.price("apple")

        verify(mock.price("banana")).neverCalled()
        verify(mock.price("apple")).called(1)
    }

    @Test func testVerifyNeverSucceedsWhenMethodNotCalled() {
        let mock = MockPricingService()
        verifyNever(mock.price(.any))
    }

    @Test func testVerifyNeverWithSpecificArguments() {
        let mock = MockPricingService()
        when(mock.price("apple")).thenReturn(13)

        let _ = try? mock.price("apple")

        verifyNever(mock.price("banana"))
        verify(mock.price("apple")).called(1)
    }

    @Test func testVerifyNeverEquivalentToVerifyNeverCalled() {
        let mock = MockPricingService()

        verifyNever(mock.price(.any))
        verify(mock.price(.any)).neverCalled()
    }

    @Test func testVerifyNeverWithComplexScenario() async {
        let mock = MockNetworkService()
        let url1 = URL(string: "https://api.example.com/users")!
        let url2 = URL(string: "https://api.example.com/posts")!

        when(mock.request(url: .equal(url1), method: .any, headers: .any))
            .thenReturn("users data".data(using: .utf8)!)

        let _ = try? await mock.request(url: url1, method: "GET", headers: nil)

        verify(mock.request(url: .equal(url1), method: .equal("GET"), headers: .nil())).called(1)
        verifyNever(mock.request(url: .equal(url2), method: .any, headers: .any))
        verifyNever(mock.download(from: .any))
        verifyNever(mock.upload(to: .any, data: .any))
    }

    @Test func testNewMatchers() throws {
        let mock = MockPricingService()

        // Test string matchers
        when(mock.price(.contains("apple"))).thenReturn(100)
        when(mock.price(.startsWith("banana"))).thenReturn(50)
        when(mock.price(.endsWith("_premium"))).thenReturn(200)
        when(mock.price(.matches(#"^\d+$"#))).thenReturn(999)

        #expect(try mock.price("green_apple") == 100)
        #expect(try mock.price("banana_split") == 50)
        #expect(try mock.price("gold_premium") == 200)
        #expect(try mock.price("12345") == 999)

        verify(mock.price(.contains("apple"))).called(1)
        verify(mock.price(.startsWith("banana"))).called(1)
        verify(mock.price(.endsWith("_premium"))).called(1)
        verify(mock.price(.matches(#"^\d+$"#))).called(1)

        verifyNever(mock.price(.contains("cherry")))
        verifyNever(mock.price(.startsWith("grape")))
    }

    @Test func testRangeBasedMatchers() throws {
        let calculator = MockCalculator()
        let returnlessService = MockReturnlessService()

        // Test range-based numeric matchers with Calculator
        when(calculator.calculate(.in(10...20), .any)).thenReturn(100)  // ClosedRange
        when(calculator.calculate(.in(50...), .any)).thenReturn(200)    // PartialRangeFrom
        when(calculator.calculate(.in(...5), .any)).thenReturn(50)      // PartialRangeThrough

        #expect(calculator.calculate(15, 0) == 100)  // 15 is in 10...20
        #expect(calculator.calculate(75, 0) == 200)  // 75 is in 50...
        #expect(calculator.calculate(3, 0) == 50)    // 3 is in ...5

        verify(calculator.calculate(.in(10...20), .any)).called(1)
        verify(calculator.calculate(.in(50...), .any)).called(1)
        verify(calculator.calculate(.in(...5), .any)).called(1)

        // Test with ReturnlessService to show different numeric ranges
        returnlessService.doSomething(with: 25)
        returnlessService.doSomething(with: 100)
        returnlessService.doSomething(with: 2)

        verify(returnlessService.doSomething(with: .in(20...30))).called(1)  // 25
        verify(returnlessService.doSomething(with: .in(90...))).called(1)    // 100
        verify(returnlessService.doSomething(with: .in(...10))).called(1)    // 2

        verifyNever(returnlessService.doSomething(with: .in(40...49)))
    }

    @Test func testVerifyZeroInteractionsWithUnusedMocks() {
        let unusedPricingMock = MockPricingService()
        let unusedNetworkMock = MockNetworkService()
        let unusedCalculatorMock = MockCalculator()

        // None of these mocks should have any interactions
        verifyZeroInteractions(unusedPricingMock)
        verifyZeroInteractions(unusedNetworkMock)
        verifyZeroInteractions(unusedCalculatorMock)
    }

    @Test func testVerifyZeroInteractionsInComplexScenario() async throws {
        let primaryMock = MockNetworkService()
        let fallbackMock = MockNetworkService()
        let cacheMock = MockPersistenceService()

        let url = URL(string: "https://api.example.com/data")!

        // Setup stubs for primary mock
        when(primaryMock.request(url: .any, method: .any, headers: .any))
            .thenReturn("primary_data".data(using: .utf8)!)

        // Use only the primary mock in this scenario
        let data = try await primaryMock.request(url: url, method: "GET", headers: nil)
        #expect(data == "primary_data".data(using: .utf8)!)

        // Verify the primary mock was used
        verify(primaryMock.request(url: .equal(url), method: .equal("GET"), headers: .nil())).called(1)

        // Verify the fallback and cache mocks were never touched
        verifyZeroInteractions(fallbackMock)
        verifyZeroInteractions(cacheMock)
    }
}
