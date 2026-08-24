import SwiftMocking
import Testing

@Suite
struct ClockTests {
    // `.mocking` gives this test its own spy storage, so static
    // state can't leak in from — or out to — tests running in parallel.
    @Test(.mocking)
    func stubsAStaticMethod() {
        when(MockClock.now()).thenReturn(42)

        #expect(MockClock.now() == 42)

        verify(MockClock.now()).called(1)
    }

    // A second test in the same suite. Without `.mocking` these two
    // would share static storage and race when run in parallel.
    @Test(.mocking)
    func startsFromACleanSlate() {
        // The other test's calls are invisible here.
        verify(MockClock.now()).neverCalled()

        when(MockClock.now()).thenReturn(7)
        #expect(MockClock.now() == 7)
        verify(MockClock.now()).called(1)
    }
}
