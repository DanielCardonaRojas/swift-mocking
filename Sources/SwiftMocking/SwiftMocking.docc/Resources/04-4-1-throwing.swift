import SwiftMocking

struct PaymentError: Error, Equatable {
    let code: Int
}

@Mockable
protocol PaymentService {
    func charge(amountCents: Int) throws -> String
    func refund(id: String) async throws -> Bool
}
