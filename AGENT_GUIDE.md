# SwiftMocking Agent Guide

This guide provides essential knowledge for AI agents to effectively write unit tests using SwiftMocking. Examples progress from simple to complex scenarios.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Framework Fundamentals](#framework-fundamentals)
3. [Basic Mock Operations](#basic-mock-operations)
4. [Method Signature Variations](#method-signature-variations)
5. [Argument Matching](#argument-matching)
6. [Stubbing Strategies](#stubbing-strategies)
7. [Verification Patterns](#verification-patterns)
8. [Advanced Features](#advanced-features)
9. [Closure-Based Testing](#closure-based-testing-tca-pattern)
10. [Testing Framework Integration](#testing-framework-integration)
11. [Common Testing Scenarios](#common-testing-scenarios)
12. [Best Practices](#best-practices)

## Quick Start

### Basic Setup
```swift
import SwiftMocking
import Testing  // or XCTest

// 1. Define protocol with @Mockable
@Mockable
protocol UserService {
    func getUser(id: String) throws -> User
}

// 2. Create mock in test
let mockUserService = MockUserService()

// 3. Stub behavior
when(mockUserService.getUser(id: .any)).thenReturn(User(id: "123", name: "John"))

// 4. Use in system under test
let userManager = UserManager(userService: mockUserService)
let user = try userManager.fetchUser(id: "123")

// 5. Verify interactions
verify(mockUserService.getUser(id: .equal("123"))).called(1)
```

## Framework Fundamentals

### @Mockable Macro
The `@Mockable` macro generates mock implementations from protocols:

```swift
@Mockable
protocol PricingService {
    func price(_ item: String) throws -> Int
}

// Generates: MockPricingService class
```

### Mock Class Generation
- Mock classes inherit from `Mock` base class
- Implement the original protocol
- Provide interaction methods for stubbing/verification
- Use naming convention: `Mock{ProtocolName}` (or `{ProtocolName}Mock` with `.prefixMock`)

### Required Imports
```swift
import SwiftMocking
import Testing      // For swift-testing
// or
import XCTest       // For XCTest
```

## Basic Mock Operations

### 1. Creating Mocks
```swift
let mock = MockPricingService()
```

### 2. Basic Stubbing
```swift
// Simple return value
when(mock.price("apple")).thenReturn(100)

// Any argument
when(mock.price(.any)).thenReturn(50)
```

### 3. Basic Verification
```swift
// Verify specific call
verify(mock.price("apple")).called(1)

// Verify any call
verify(mock.price(.any)).called()
```

## Method Signature Variations

### Synchronous Methods
```swift
@Mockable
protocol SyncService {
    func process(_ data: String) -> Int
}

// Usage
when(mock.process(.any)).thenReturn(42)
let result = mock.process("data")
verify(mock.process("data")).called(1)
```

### Async Methods
```swift
@Mockable
protocol AsyncService {
    func fetchData(id: String) async -> Data
}

// Usage
when(mock.fetchData(id: .any)).thenReturn(Data())
let data = await mock.fetchData(id: "123")
verify(mock.fetchData(id: "123")).called(1)
```

### Throwing Methods
```swift
@Mockable
protocol ThrowingService {
    func validate(_ input: String) throws -> Bool
}

// Stub success
when(mock.validate(.any)).thenReturn(true)

// Stub failure
when(mock.validate("invalid")).thenThrow(ValidationError.invalid)

// Verify throws
verify(mock.validate("invalid")).throws()
```

### Async Throwing Methods
```swift
@Mockable
protocol AsyncThrowingService {
    func upload(_ data: Data) async throws -> String
}

// Stub success
when(mock.upload(.any)).thenReturn("upload-id")

// Stub failure
when(mock.upload(.any)).thenThrow(NetworkError.timeout)

// Usage
let uploadId = try await mock.upload(data)
verify(mock.upload(.any)).called(1)
```

### Methods with No Parameters/Returns
```swift
@Mockable
protocol ActionService {
    func start()                    // No parameters, no return
    func getStatus() -> String      // No parameters, has return
    func configure(_ setting: Int)  // Has parameters, no return
}

// Usage
mock.start()
when(mock.getStatus()).thenReturn("running")
mock.configure(5)

verify(mock.start()).called()
verify(mock.getStatus()).called()
verify(mock.configure(5)).called()
```

## Argument Matching

### Basic Matchers
```swift
// Any value
verify(mock.process(.any)).called()

// Specific value
verify(mock.process(.equal("value"))).called()

// Nil/NotNil
verify(mock.process(.nil())).called()
verify(mock.process(.notNil())).called()
```

### String Matchers
```swift
// Contains substring
when(mock.process(.contains("apple"))).thenReturn(100)

// Starts with
when(mock.process(.startsWith("prefix"))).thenReturn(200)

// Ends with
when(mock.process(.endsWith("suffix"))).thenReturn(300)

// Regex pattern
when(mock.process(.matches(#"^\d+$"#))).thenReturn(999)
```

### Numeric Range Matchers
```swift
// Closed range
when(calculator.calculate(.in(10...20), .any)).thenReturn(100)

// Partial range from
when(calculator.calculate(.in(50...), .any)).thenReturn(200)

// Partial range through
when(calculator.calculate(.in(...5), .any)).thenReturn(50)
```

### Custom Predicate Matchers
```swift
// Even numbers
let even = ArgMatcher<Int>.any(that: { $0 % 2 == 0 })
when(calculator.calculate(even, .any)).thenReturn(0)

// Specific conditions
let longStrings = ArgMatcher<String>.any(that: { $0.count > 10 })
when(mock.process(longStrings)).thenReturn(1000)
```

### Type Matchers
```swift
// Specific type
verify(mock.logEvent(.any(UserEvent.self))).called()

// Metatype matching
when(mock.fakeData(.type(Person.self))).thenReturn(personData)
```

## Stubbing Strategies

### Simple Return Values
```swift
when(mock.getPrice(.any)).thenReturn(100)
when(mock.getName(.any)).thenReturn("John")
when(mock.isValid(.any)).thenReturn(true)
```

### Error Throwing
```swift
when(mock.validate("invalid")).thenThrow(ValidationError.invalid)
when(mock.connect(.any)).thenThrow(NetworkError.connectionFailed)
```


### Dynamic Responses with Closures
```swift
// Inspect arguments and return dynamic values
when(mock.calculatePrice(.any)).thenReturn { item in
    let prices = ["apple": 100, "banana": 50]
    return prices[item] ?? 0
}

// Multiple parameters
when(mock.processData(.any, .any)).thenReturn { (data, config) in
    return "\(data)-processed-\(config)"
}
```

### Conditional Stubbing
```swift
// Different responses for different arguments
when(mock.getDiscount(.contains("premium"))).thenReturn(0.2)
when(mock.getDiscount(.contains("basic"))).thenReturn(0.1)
when(mock.getDiscount(.any)).thenReturn(0.0)
```

### Callback/Closure Handling
```swift
@Mockable
protocol CallbackService {
    func execute(completion: @escaping (String) -> Void)
}

// Stub callback execution
when(mock.execute(completion: .any)).then { completion in
    completion("success")
}

// Test
var result: String?
mock.execute { value in
    result = value
}
verify(mock.execute(completion: .any)).called()
```

### Closure-Based Dependencies (TCA Pattern)
For projects using The Composable Architecture (TCA) from Point-Free or closure-based dependency injection:

```swift
// Define dependency structure
struct NetworkClient {
    var fetchData: (URL) async throws -> Data
    var uploadData: (Data, URL) async throws -> String
}

// Create spies for each closure
let fetchSpy = Spy<URL, AsyncThrows, Data>()
let uploadSpy = Spy<(Data, URL), AsyncThrows, String>()

// Stub behaviors
when(fetchSpy(.any)).thenReturn("response".data(using: .utf8)!)
when(uploadSpy(.any, .any)).thenReturn("upload-id-123")

// Create client with adapted spies
let client = NetworkClient(
    fetchData: adapt(fetchSpy),
    uploadData: adapt(uploadSpy)
)

// Use and verify
let data = try await client.fetchData(url)
let uploadId = try await client.uploadData(data, url)

verify(fetchSpy(.equal(url))).called(1)
verify(uploadSpy(.any, .equal(url))).called(1)
```

## Verification Patterns

### Call Count Verification
```swift
// Called once (default)
verify(mock.process(.any)).called()

// Called specific number of times
verify(mock.process(.any)).called(3)

// Never called
verify(mock.process(.any)).neverCalled()
verifyNever(mock.process(.any))  // Equivalent
```

### Argument-Specific Verification
```swift
// Verify with specific arguments
verify(mock.process(.equal("input"))).called(1)

// Verify with argument matchers
verify(mock.process(.contains("test"))).called()

// Verify multiple parameters
verify(mock.upload(.any, .equal(data))).called()
```

### Exception Verification
```swift
// Verify method threw any error
verify(mock.validate("invalid")).throws()

// Verify method threw specific error type
verify(mock.validate("invalid")).throws(ValidationError.self)
```

### Order Verification
```swift
// Verify methods called in specific order
verifyInOrder([
    mock.authenticate(.any),
    mock.fetchData(.any),
    mock.logout()
])
```

### Zero Interactions Verification
```swift
// Verify mock was never used
verifyZeroInteractions(unusedMock)

// Useful for testing fallback scenarios
verifyZeroInteractions(fallbackService)
```

## Advanced Features

### Properties
```swift
@Mockable
protocol ConfigService {
    var isEnabled: Bool { get set }
    var timeout: TimeInterval { get }
}

// Stub property getters
when(mock.getIsEnabled()).thenReturn(true)
when(mock.getTimeout()).thenReturn(30.0)

// Verify property access
verify(mock.getIsEnabled()).called()
```

### Subscripts
```swift
@Mockable
protocol CacheService {
    subscript(key: String) -> String? { get }
}

// Stub subscript
when(mock[.any]).thenReturn("cached_value")

// Use and verify
let value = mock["key"]
verify(mock["key"]).called()
```

### Associated Types and Generics
```swift
@Mockable
protocol Repository {
    associatedtype Entity
    func save(_ entity: Entity) throws
    func find(id: String) throws -> Entity?
}

// Mock with concrete type
let mockUserRepo = MockRepository<User>()
when(mockUserRepo.find(id: .any)).thenReturn(user)
```

### Static Methods
```swift
@Mockable
protocol Logger {
    static func log(_ message: String)
}

// Use static mock
MockLogger.log("test message")
verify(MockLogger.log(.any)).called()

// Thread-safe for concurrent testing
MockLogger.clear()  // Reset between tests
```

### Variadic Parameters
```swift
@Mockable
protocol Printer {
    func print(_ values: String...)
}

// Use with variadic parameters
mock.print("hello", "world", "!")
verify(mock.print("hello", .any, "!")).called()
```

## Testing Framework Integration

### Swift Testing Framework
```swift
import Testing
import SwiftMocking

@Test func userServiceFetchesUser() throws {
    let mock = MockUserService()
    when(mock.getUser(id: .any)).thenReturn(User(id: "123"))

    let service = UserManager(userService: mock)
    let user = try service.fetchUser(id: "123")

    #expect(user.id == "123")
    verify(mock.getUser(id: "123")).called(1)
}

@Test func userServiceHandlesError() async throws {
    let mock = MockUserService()
    when(mock.getUser(id: "invalid")).thenThrow(UserError.notFound)

    let service = UserManager(userService: mock)

    await #expect(throws: UserError.notFound) {
        try await service.fetchUser(id: "invalid")
    }

    verify(mock.getUser(id: "invalid")).throws()
}
```

### XCTest Framework
```swift
import XCTest
import SwiftMocking

class UserServiceTests: XCTestCase {
    func testUserServiceFetchesUser() throws {
        let mock = MockUserService()
        when(mock.getUser(id: .any)).thenReturn(User(id: "123"))

        let service = UserManager(userService: mock)
        let user = try service.fetchUser(id: "123")

        XCTAssertEqual(user.id, "123")
        verify(mock.getUser(id: "123")).called(1)
    }

    func testUserServiceHandlesError() {
        let mock = MockUserService()
        when(mock.getUser(id: "invalid")).thenThrow(UserError.notFound)

        let service = UserManager(userService: mock)

        XCTAssertThrowsError(try service.fetchUser(id: "invalid")) { error in
            XCTAssert(error is UserError)
        }

        verify(mock.getUser(id: "invalid")).throws()
    }
}
```

## Common Testing Scenarios

### 1. Service Layer Testing
```swift
// Test business logic with mocked dependencies
@Test func orderProcessingCalculatesTotalCorrectly() throws {
    let mockPricing = MockPricingService()
    let mockTax = MockTaxService()

    when(mockPricing.getPrice(.any)).thenReturn(100)
    when(mockTax.calculateTax(.any)).thenReturn(10)

    let processor = OrderProcessor(
        pricingService: mockPricing,
        taxService: mockTax
    )

    let total = try processor.calculateTotal(for: "item")

    #expect(total == 110)
    verify(mockPricing.getPrice("item")).called(1)
    verify(mockTax.calculateTax(100)).called(1)
}
```

### 2. Network Layer Testing
```swift
@Test func networkServiceHandlesRetry() async throws {
    let mock = MockNetworkService()
    let url = URL(string: "https://api.example.com/data")!

    // For retry testing, use dynamic stubbing to simulate first failure, then success
    var callCount = 0
    when(mock.fetch(.equal(url))).thenReturn { _ in
        callCount += 1
        if callCount == 1 {
            throw NetworkError.timeout  // First call fails
        } else {
            return "success".data(using: .utf8)!  // Second call succeeds
        }
    }

    let client = APIClient(networkService: mock)
    let data = try await client.fetchWithRetry(url: url)

    #expect(data != nil)
    verify(mock.fetch(.equal(url))).called(2)  // Called twice due to retry
}
```

### 3. Repository Pattern Testing
```swift
@Test func repositoryCachesResults() throws {
    let mockCache = MockCacheService()
    let mockAPI = MockAPIService()

    when(mockCache.get(.any)).thenReturn(nil)  // Cache miss
    when(mockAPI.fetchUser(.any)).thenReturn(user)

    let repo = UserRepository(cache: mockCache, api: mockAPI)
    let result = try repo.getUser(id: "123")

    verify(mockCache.get("123")).called(1)
    verify(mockAPI.fetchUser("123")).called(1)
    verify(mockCache.set("123", .any)).called(1)
}
```

### 4. Error Handling Testing
```swift
@Test func serviceHandlesMultipleErrorTypes() async {
    let mock = MockNetworkService()

    when(mock.upload(.contains("timeout"))).thenThrow(NetworkError.timeout)
    when(mock.upload(.contains("unauthorized"))).thenThrow(NetworkError.unauthorized)
    when(mock.upload(.any)).thenReturn("success")

    let service = UploadService(network: mock)

    // Test different error scenarios
    await #expect(throws: NetworkError.timeout) {
        try await service.upload("timeout_data")
    }

    await #expect(throws: NetworkError.unauthorized) {
        try await service.upload("unauthorized_data")
    }

    let result = try await service.upload("valid_data")
    #expect(result == "success")
}
```

### 5. Closure-Based Dependency Testing (TCA Pattern)
```swift
@Test func closureBasedClientWorks() async throws {
    // Define dependency structure
    struct APIClient {
        var fetchUser: (String) async throws -> User
        var updateUser: (User) async throws -> Void
    }

    // Create spies
    let fetchSpy = Spy<String, AsyncThrows, User>()
    let updateSpy = Spy<User, AsyncThrows, Void>()

    // Stub behaviors
    let testUser = User(id: "123", name: "John")
    when(fetchSpy(.any)).thenReturn(testUser)
    when(updateSpy(.any)).then { user in
        print("Updating user: \(user.name)")
    }

    // Create client with spies
    let client = APIClient(
        fetchUser: adapt(fetchSpy),
        updateUser: adapt(updateSpy)
    )

    // Use the client
    let user = try await client.fetchUser("123")
    var updatedUser = user
    updatedUser.name = "John Updated"
    try await client.updateUser(updatedUser)

    // Verify interactions
    #expect(user.id == "123")
    verify(fetchSpy(.equal("123"))).called(1)
    verify(updateSpy(.any(where: \.name, "John Updated"))).called(1)
}
```

### 6. Complex Interaction Testing
```swift
@Test func workflowExecutesInCorrectOrder() throws {
    let mockAuth = MockAuthService()
    let mockData = MockDataService()
    let mockLogger = MockLogger()

    when(mockAuth.authenticate(.any)).thenReturn(true)
    when(mockData.process(.any)).thenReturn("result")

    let workflow = DataWorkflow(
        auth: mockAuth,
        data: mockData,
        logger: mockLogger
    )

    let result = try workflow.execute(input: "test")

    #expect(result == "result")

    // Verify correct execution order
    verifyInOrder([
        mockLogger.log(.contains("Starting")),
        mockAuth.authenticate(.any),
        mockData.process("test"),
        mockLogger.log(.contains("Completed"))
    ])
}
```

## Best Practices

### 1. Choose Appropriate Matchers
```swift
// ✅ Good: Use specific matchers when testing exact behavior
verify(userService.getUser(id: .equal("123"))).called(1)

// ✅ Good: Use .any when specific value doesn't matter
verify(logger.log(.any)).called()

// ❌ Avoid: Overly specific when not needed
verify(logger.log(.equal("User 123 logged in at 2023-10-15 14:30:00"))).called()

// ✅ Better: Use contains or predicates for partial matching
verify(logger.log(.contains("User 123 logged in"))).called()
```

### 2. Stub Setup Patterns
```swift
// ✅ Good: Set up stubs before using the mock
when(mock.getUser(.any)).thenReturn(defaultUser)
when(mock.getUser("admin")).thenReturn(adminUser)

let service = UserService(userRepo: mock)
// ... use service
```

### 3. Verification Best Practices
```swift
// ✅ Good: Verify the specific interactions you care about
verify(emailService.send(.contains("welcome"))).called(1)
verify(analyticsService.track(.equal("user_registered"))).called(1)

// ❌ Avoid: Over-verification of internal implementation details
verify(emailService.getTemplate(.any)).called(1)
verify(emailService.validateEmail(.any)).called(1)
```

### 4. Error Testing Patterns
```swift
// ✅ Good: Test both success and failure paths
@Test func handlesBothSuccessAndFailure() async throws {
    let mock = MockService()

    // Test success path
    when(mock.process("valid")).thenReturn("success")
    let result = try await service.handle("valid")
    #expect(result == "success")

    // Test failure path
    when(mock.process("invalid")).thenThrow(ServiceError.invalid)
    await #expect(throws: ServiceError.invalid) {
        try await service.handle("invalid")
    }

    verify(mock.process("valid")).called(1)
    verify(mock.process("invalid")).throws()
}
```

### 5. Mock Lifecycle Management
```swift
class ServiceTests: XCTestCase {
    var mockDependency: MockDependency!
    var serviceUnderTest: Service!

    override func setUp() {
        super.setUp()
        mockDependency = MockDependency()
        serviceUnderTest = Service(dependency: mockDependency)
    }

    override func tearDown() {
        // Clean up static mocks if used
        MockLogger.clear()
        super.tearDown()
    }
}
```

### 6. Thread Safety Considerations
```swift
// ✅ Good: For concurrent testing scenarios
@Test func concurrentAccessIsSafe() async {
    MockLogger.clear()

    await withTaskGroup(of: Void.self) { group in
        for i in 0..<100 {
            group.addTask {
                MockLogger.log("message \(i)")
            }
        }
    }

    verify(MockLogger.log(.any)).called(100)
}
```

### 7. Readable Test Structure
```swift
@Test func descriptiveTestName() throws {
    // Arrange: Set up mocks and expectations
    let mockService = MockPaymentService()
    when(mockService.charge(.any, .any)).thenReturn("transaction-123")

    let checkoutService = CheckoutService(paymentService: mockService)

    // Act: Execute the behavior being tested
    let result = try checkoutService.processPayment(
        amount: 100,
        card: testCard
    )

    // Assert: Verify results and interactions
    #expect(result.transactionId == "transaction-123")
    verify(mockService.charge(.equal(100), .equal(testCard))).called(1)
}
```

This guide covers the essential patterns and practices for effective unit testing with SwiftMocking. Use these examples as templates for creating robust, maintainable tests.