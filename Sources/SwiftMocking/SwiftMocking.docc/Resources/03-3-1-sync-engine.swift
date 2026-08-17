import SwiftMocking

@Mockable
protocol SyncEngine {
    func refresh(id: String) -> Void
}
