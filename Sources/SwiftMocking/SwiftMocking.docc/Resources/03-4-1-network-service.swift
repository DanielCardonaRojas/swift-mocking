import SwiftMocking

struct User: Equatable {
    let id: String
    let name: String
}

@Mockable
protocol NetworkService {
    func fetchUser(id: String, completion: @escaping (Result<User, Error>) -> Void)
}
