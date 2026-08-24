@Test
func fetchUserDeliversSuccess() async {
    let mock = MockNetworkService()

    // Swift Testing replaces XCTestExpectation with `confirmation`.
    // The body must call `received()` exactly once before it returns.
    await confirmation("completion invoked") { received in
        // .any is the only matcher that makes sense for a closure parameter.
        when(mock.fetchUser(id: .equal("42"), completion: .any))
            .thenReturn { id, completion in
                completion(.success(User(id: id, name: "Test User")))
            }
    }
}
