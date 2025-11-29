#if canImport(XCTest)
import XCTest
import SwiftMocking

/// Convenience base case that installs a fresh ``SpyStorageProvider`` and ``InvocationRecorder`` for each test invocation.
///
/// Subclass ``MockingTestCase`` instead of `XCTestCase` so static spies and invocation recordings
/// remain isolated across concurrently running tests.
open class MockingTestCase: XCTestCase {
    open override func invokeTest() {
        let provider = SpyStorageProvider()
        let recorder = InvocationRecorder()
        MockScope.withStorage(provider) {
            MockScope.withInvocationRecorder(recorder) {
                super.invokeTest()
            }
        }
    }
}

#endif
