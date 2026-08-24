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

        let service: any NetworkService = mock
        service.fetchUser(id: "42") { result in
            guard case .success(let user) = result else {
                Issue.record("expected a success result")
                return
            }
            #expect(user == User(id: "42", name: "Test User"))
            received()
        }
    }

    verify(mock.fetchUser(id: .equal("42"), completion: .any)).called(1)
}
