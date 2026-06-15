import Combine
import Foundation

@MainActor
final class LayoutCoordinator: ObservableObject {
    @Published var statusMessage = L10n.tr("Ready")
    @Published var saveName = ""
    @Published var renameName = ""
    @Published var isSaveSheetPresented = false
    @Published var renamingLayout: Layout?
    @Published var latestReport: RestoreReport?

    let permissionManager: AccessibilityPermissionManager
    let store: LayoutStore

    private let windowManager: WindowManager
    private let appLauncher: AppLauncher
    private var cancellables = Set<AnyCancellable>()

    init(
        permissionManager: AccessibilityPermissionManager = AccessibilityPermissionManager(),
        store: LayoutStore = LayoutStore(),
        windowManager: WindowManager = WindowManager(),
        appLauncher: AppLauncher = AppLauncher()
    ) {
        self.permissionManager = permissionManager
        self.store = store
        self.windowManager = windowManager
        self.appLauncher = appLauncher
        self.saveName = Self.defaultLayoutName()

        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var layouts: [Layout] {
        store.layouts
    }

    func snapshotURL(for layout: Layout) -> URL? {
        store.snapshotURL(for: layout)
    }

    func requestAccessibilityPermission() {
        permissionManager.requestIfNeeded()
        statusMessage = permissionManager.isTrusted
            ? L10n.tr("Accessibility access enabled")
            : L10n.tr("Grant Accessibility access in System Settings")
    }

    func refreshPermissions() {
        permissionManager.refresh()
    }

    func prepareSave() {
        saveName = Self.defaultLayoutName()
        isSaveSheetPresented = true
    }

    func quickSave() {
        Task {
            await saveCurrentLayout(named: Self.defaultLayoutName())
        }
    }

    func saveCurrentLayout(named name: String) async {
        do {
            let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else {
                statusMessage = L10n.tr("Name required")
                return
            }
            statusMessage = L10n.tr("Capturing windows...")
            let captured = try windowManager.captureCurrentLayout(name: normalized)
            let snapshotPNGData = windowManager.captureDesktopSnapshotPNGData(
                for: captured.layout,
                previewWindows: captured.previewWindows
            )
            try store.save(captured.layout, snapshotPNGData: snapshotPNGData)
            statusMessage = L10n.format("Saved %d apps", captured.layout.apps.count)
            isSaveSheetPresented = false
        } catch {
            statusMessage = error.localizedDescription
            if !permissionManager.isTrusted {
                permissionManager.refresh()
            }
        }
    }

    func overwrite(_ layout: Layout) {
        Task {
            do {
                statusMessage = L10n.tr("Updated layout...")
                let captured = try windowManager.captureCurrentLayout(name: layout.name)
                let updatedLayout = Layout(
                    id: layout.id,
                    name: layout.name,
                    createdAt: layout.createdAt,
                    updatedAt: .now,
                    pinned: layout.pinned,
                    snapshotFileName: layout.snapshotFileName,
                    spacePolicy: layout.spacePolicy,
                    extraWindowsBehaviorDefault: layout.extraWindowsBehaviorDefault,
                    apps: captured.layout.apps
                )
                let snapshotPNGData = windowManager.captureDesktopSnapshotPNGData(
                    for: updatedLayout,
                    previewWindows: captured.previewWindows
                )
                try store.save(updatedLayout, snapshotPNGData: snapshotPNGData)
                statusMessage = L10n.format("Updated %@", layout.name)
            } catch {
                statusMessage = error.localizedDescription
                if !permissionManager.isTrusted {
                    permissionManager.refresh()
                }
            }
        }
    }

    func restore(_ layout: Layout) {
        Task {
            statusMessage = L10n.tr("Launching apps...")
            let report = await windowManager.restoreLayout(layout, appLauncher: appLauncher)
            latestReport = report

            if !report.failures.isEmpty {
                statusMessage = report.failures.first?.message ?? L10n.tr("Restore failed")
            } else if !report.unreconciledWindows.isEmpty {
                statusMessage = L10n.format("Restored with %d unresolved windows", report.unreconciledWindows.count)
            } else {
                statusMessage = L10n.tr("Done")
            }
        }
    }

    func delete(_ layout: Layout) {
        do {
            try store.deleteLayout(id: layout.id)
            statusMessage = L10n.format("Deleted %@", layout.name)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func beginRename(_ layout: Layout) {
        renamingLayout = layout
        renameName = layout.name
    }

    func commitRename() {
        guard let layout = renamingLayout else { return }
        do {
            try store.renameLayout(id: layout.id, name: renameName)
            statusMessage = L10n.tr("Renamed layout")
            renamingLayout = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func cancelRename() {
        renamingLayout = nil
    }

    func togglePinned(_ layout: Layout) {
        do {
            try store.togglePinned(id: layout.id)
            statusMessage = layout.pinned ? L10n.format("Unpinned %@", layout.name) : L10n.format("Pinned %@", layout.name)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    static func defaultLayoutName() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: .now)
    }
}
