//
//  GitFitApp.swift
//  GitFit
//
//  Main entry point for Git-Fit - A developer fitness app for the "Vibe Coding" era.
//  Menu bar app with automatic workout prompts when idle in AI tools.
//

import SwiftUI
import AppKit

@main
struct GitFitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @AppStorage("workoutDuration") private var workoutDuration: Double = 30
    var body: some View {
        Form {
            Section("Workout Settings") {
                            Slider(value: $workoutDuration, in: 15...120, step: 15) {
                                Text("Trigger after: \(Int(workoutDuration))s of waiting")
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
            Section("About") {
                Text("Git-Fit v1.0")
                    .font(.system(.body, design: .monospaced))
                Text("Developer fitness for the vibe coding era")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 350, height: 180)
    }
}

