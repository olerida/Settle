import AppKit
import SwiftUI

@main
struct SettleApp: App {
    @NSApplicationDelegateAdaptor(MenuBarAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(AppSession.coordinator)
        }
    }
}
