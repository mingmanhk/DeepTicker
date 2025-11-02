import Foundation
import Combine
import SwiftUI

@MainActor
final class DataRefreshManager: ObservableObject {
    var objectWillChange: ObservableObjectPublisher
    
    @Published var preloadingEnabled: Bool = true

    func scheduleBackgroundRefresh() {
        print("Background refresh scheduled")
    }

    func preloadData() async {
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        print("Data preloaded")
    }
    
    static let shared = DataRefreshManager()
    
    private init() {
        self.objectWillChange = ObservableObjectPublisher()
    }
}
