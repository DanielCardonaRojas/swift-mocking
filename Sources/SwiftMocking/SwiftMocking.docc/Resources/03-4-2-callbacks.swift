func testFetchUserDeliversSuccess() {
    let mock = MockNetworkService()
    let received = expectation(description: "completion invoked")
