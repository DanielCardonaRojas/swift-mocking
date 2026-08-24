import SwiftMocking
import Testing

@Suite
struct ClockTests {
    @Test(.mocking)
    func stubsAStaticMethod() {
        when(MockClock.now()).thenReturn(42)
        #expect(MockClock.now() == 42)
        verify(MockClock.now()).called(1)
    }

    @Test(.mocking)
    func startsFromACleanSlate() {
        verify(MockClock.now()).neverCalled()
        when(MockClock.now()).thenReturn(7)
        #expect(MockClock.now() == 7)
        verify(MockClock.now()).called(1)
    }

    // Static *properties* work the same way.
    @Test(.mocking)
    func stubsAStaticProperty() {
        when(MockClock.timeZone).thenReturn("UTC")

        #expect(MockClock.timeZone == "UTC")

        verify(MockClock.timeZone).called(1)
    }
}
