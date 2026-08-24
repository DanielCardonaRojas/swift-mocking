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
}
