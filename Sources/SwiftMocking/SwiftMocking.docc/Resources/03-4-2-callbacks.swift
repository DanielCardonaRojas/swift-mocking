@Test
func fetchUserDeliversSuccess() async {
    let mock = MockNetworkService()

    // Swift Testing replaces XCTestExpectation with `confirmation`.
    // The body must call `received()` exactly once before it returns.
    await confirmation("completion invoked") { received in
    }
}
