// DeepTickerApp.swift
// Minimal runnable app wiring StoreManager into environment.

import SwiftUI

@main
struct DeepTickerApp: App {
    @StateObject private var store = StoreManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
