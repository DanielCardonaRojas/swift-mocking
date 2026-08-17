func testFetchUserDeliversSuccess() {
    let mock = MockNetworkService()
    let received = expectation(description: "completion invoked")

    // .any is the only matcher that makes sense for a closure parameter.
    when(mock.fetchUser(id: .equal("42"), completion: .any)).thenReturn { id, completion in
        completion(.success(User(id: id, name: "Test User")))
    }
