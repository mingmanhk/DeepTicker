// SettingsAlertsLink.swift
// Drop-in navigation link to Alerts & Notifications settings.

import SwiftUI

struct SettingsAlertsLink: View {
    var body: some View {
        NavigationLink {
            AlertsNotificationsView()
        } label: {
            Label("Alerts & Notifications", systemImage: "bell.badge")
        }
    }
}

#Preview {
    NavigationStack {
        Form {
            SettingsAlertsLink()
        }
    }
}
