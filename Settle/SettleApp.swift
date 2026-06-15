import SwiftUI

@main
struct SettleApp: App {
    @StateObject private var coordinator = LayoutCoordinator()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(coordinator)
        } label: {
            Image(systemName: "rectangle.split.2x2.fill")
                .font(.system(size: 13, weight: .semibold))
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(coordinator)
                .frame(width: 420, height: 320)
        }
    }
}
