import Foundation
import Combine

@MainActor
class DataRefreshManager: ObservableObject {
    @Published var preloadingEnabled: Bool = true

    func scheduleBackgroundRefresh() {
        print("Background refresh scheduled")
    }

    func preloadData() async {
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        print("Data preloaded")
    }
    
    static let shared = DataRefreshManager()
    
    private init() {}
}
