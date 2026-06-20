import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: LayoutCoordinator
    @StateObject private var screenRecordingPermissionManager = ScreenRecordingPermissionManager()

    var body: some View {
        TabView {
            GeneralSettingsPane(
                settings: coordinator.settings,
                layouts: coordinator.layouts
            )
            .tabItem {
                Label(L10n.tr("General"), systemImage: "gearshape")
            }

            PermissionsSettingsPane(
                screenRecordingPermissionManager: screenRecordingPermissionManager
            )
                .environmentObject(coordinator)
                .tabItem {
                    Label(L10n.tr("Permissions"), systemImage: "hand.raised")
                }
        }
        .frame(width: 520, height: 420)
        .onAppear {
            refreshSettingsState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshSettingsState()
        }
    }

    private func refreshSettingsState() {
        coordinator.settings.refreshLaunchAtLoginState()
        coordinator.settings.reconcileDefaultLayout(
            availableLayoutIDs: Set(coordinator.layouts.map(\.id))
        )
        coordinator.refreshPermissions()
        screenRecordingPermissionManager.refresh()
    }
}

private struct GeneralSettingsPane: View {
    @ObservedObject var settings: AppSettings
    let layouts: [Layout]

    var body: some View {
        Form {
            Section(L10n.tr("Startup")) {
                Toggle(
                    L10n.tr("Launch at Login"),
                    isOn: Binding(
                        get: { settings.isLaunchAtLoginRequested },
                        set: { settings.setLaunchAtLoginEnabled($0) }
                    )
                )

                LabeledContent(
                    L10n.tr("Login Item Status"),
                    value: launchAtLoginStatusText
                )

                if settings.launchAtLoginState == .requiresApproval {
                    Button(L10n.tr("Open Login Items Settings")) {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                }

                if let launchAtLoginError = settings.launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text(L10n.tr("Launch Settle automatically when you log in to macOS."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.tr("Automatic Restore")) {
                Picker(
                    L10n.tr("Default Layout"),
                    selection: Binding(
                        get: { settings.defaultLayoutID },
                        set: { settings.setDefaultLayoutID($0) }
                    )
                ) {
                    Text(L10n.tr("None"))
                        .tag(UUID?.none)
                    ForEach(layouts) { layout in
                        Text(layout.name)
                            .tag(Optional(layout.id))
                    }
                }

                Text(
                    layouts.isEmpty
                        ? L10n.tr("Save a layout before choosing an automatic restore.")
                        : L10n.tr("Restore the selected layout when Settle starts automatically at login.")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section(L10n.tr("Behavior")) {
                LabeledContent(L10n.tr("Spaces"), value: L10n.tr("Current desktop only"))
                LabeledContent(L10n.tr("Extra windows"), value: L10n.tr("Leave untouched"))
                Text(L10n.tr("By default, restoring a layout leaves unrelated windows untouched. Use the menu actions when you explicitly want to close or minimize other windows."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var launchAtLoginStatusText: String {
        switch settings.launchAtLoginState {
        case .notRegistered:
            return L10n.tr("Disabled")
        case .enabled:
            return L10n.tr("Enabled")
        case .requiresApproval:
            return L10n.tr("Requires Approval")
        case .unavailable:
            return L10n.tr("Unavailable")
        }
    }
}

private struct PermissionsSettingsPane: View {
    @EnvironmentObject private var coordinator: LayoutCoordinator
    @ObservedObject var screenRecordingPermissionManager: ScreenRecordingPermissionManager

    var body: some View {
        Form {
            Section(L10n.tr("Accessibility")) {
                LabeledContent(
                    L10n.tr("Status"),
                    value: coordinator.permissionManager.isTrusted
                        ? L10n.tr("Granted")
                        : L10n.tr("Not Granted")
                )
                Text(L10n.tr("Settle uses the macOS Accessibility API to inspect visible windows and restore their frames."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(L10n.tr("Request Accessibility Access")) {
                    coordinator.requestAccessibilityPermission()
                }
                .disabled(coordinator.permissionManager.isTrusted)
            }

            Section(L10n.tr("Screen Recording")) {
                LabeledContent(
                    L10n.tr("Status"),
                    value: screenRecordingPermissionManager.isGranted
                        ? L10n.tr("Granted")
                        : L10n.tr("Not Granted")
                )
                Text(L10n.tr("Settle uses screen recording access only to create layout preview thumbnails. It does not record audio."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(L10n.tr("Request Screen Recording Access")) {
                    screenRecordingPermissionManager.requestIfNeeded()
                }
                .disabled(screenRecordingPermissionManager.isGranted)
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
