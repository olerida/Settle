import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: LayoutCoordinator

    var body: some View {
        Form {
            Section(L10n.tr("Accessibility")) {
                LabeledContent(L10n.tr("Status"), value: coordinator.permissionManager.isTrusted ? L10n.tr("Granted") : L10n.tr("Not Granted"))
                Text(L10n.tr("Settle uses the macOS Accessibility API to inspect visible windows and restore their frames."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(L10n.tr("Request Accessibility Access")) {
                    coordinator.requestAccessibilityPermission()
                }
            }

            Section(L10n.tr("Behavior")) {
                LabeledContent(L10n.tr("Spaces"), value: L10n.tr("Current desktop only"))
                LabeledContent(L10n.tr("Extra windows"), value: L10n.tr("Leave untouched"))
                Text(L10n.tr("By default, restoring a layout leaves unrelated windows untouched. Use the menu actions when you explicitly want to close or minimize other windows."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.tr("Notes")) {
                Text(L10n.tr("Some apps do not expose every window reliably through Accessibility. In those cases Settle restores as much as macOS allows and reports unresolved windows."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
