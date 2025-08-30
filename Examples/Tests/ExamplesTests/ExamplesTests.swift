import Testing
import SwiftMocking
import Foundation
@testable import Examples


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
    when(mockCalculator.calculate(odd, odd)).then(*)
    when(mockCalculator.calculate(even, even)).then(-)
    when(mockCalculator.calculate(.any, .any)).then(+)

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
    when(mock.execute(completion: .any)).then { completion in
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
