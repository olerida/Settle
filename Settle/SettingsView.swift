import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: LayoutCoordinator

    var body: some View {
        Form {
            Section("Accessibility") {
                LabeledContent("Status", value: coordinator.permissionManager.isTrusted ? "Granted" : "Not Granted")
                Text("Settle uses the macOS Accessibility API to inspect visible windows and restore their frames.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Request Accessibility Access") {
                    coordinator.requestAccessibilityPermission()
                }
            }

            Section("Behavior") {
                LabeledContent("Spaces", value: "Current desktop only")
                LabeledContent("Extra windows", value: "Leave untouched")
                Text("v1 does not close, hide, or minimize windows that are not part of the selected layout.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notes") {
                Text("Some apps do not expose every window reliably through Accessibility. In those cases Settle restores as much as macOS allows and reports unresolved windows.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
