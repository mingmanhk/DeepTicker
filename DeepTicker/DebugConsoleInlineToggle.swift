// DebugConsoleInlineToggle.swift
// Small reusable toggle for enabling/disabling the debug console from Settings.

import SwiftUI

struct DebugConsoleInlineToggle: View {
    @StateObject private var debugSettings = DebugSettings.load()

    var body: some View {
        Toggle("Enable Debug Console", isOn: $debugSettings.debugConsoleEnabled)
            .onChange(of: debugSettings.debugConsoleEnabled) { debugSettings.save() }
    }
}

#Preview {
    Form { DebugConsoleInlineToggle() }
}
