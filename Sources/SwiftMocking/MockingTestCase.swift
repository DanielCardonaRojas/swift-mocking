#if canImport(XCTest)
import XCTest

/// Convenience base case that installs a fresh ``SpyStorageProvider`` for each test invocation.
///
/// Subclass ``MockingTestCase`` instead of `XCTestCase` so static spies remain isolated across
/// concurrently running tests.
open class MockingTestCase: XCTestCase {
    open override func invokeTest() {
        let provider = SpyStorageProvider()
        MockScope.withStorage(provider) {
            super.invokeTest()
        }
    }
}

#endif
