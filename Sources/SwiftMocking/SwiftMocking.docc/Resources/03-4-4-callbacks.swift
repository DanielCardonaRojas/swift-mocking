func testFetchUserDeliversSuccess() {
    let mock = MockNetworkService()
    let received = expectation(description: "completion invoked")

    // .any is the only matcher that makes sense for a closure parameter.
    when(mock.fetchUser(id: .equal("42"), completion: .any)).thenReturn { id, completion in
        completion(.success(User(id: id, name: "Test User")))
    }

    mock.fetchUser(id: "42") { result in
        XCTAssertEqual(try result.get(), User(id: "42", name: "Test User"))
        received.fulfill()
    }

    wait(for: [received], timeout: 1.0)
}
