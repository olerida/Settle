import Combine
import Foundation

@MainActor
final class LayoutCoordinator: ObservableObject {
    @Published var statusMessage = "Ready"
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

    func requestAccessibilityPermission() {
        permissionManager.requestIfNeeded()
        statusMessage = permissionManager.isTrusted ? "Accessibility access enabled" : "Grant Accessibility access in System Settings"
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
                statusMessage = "Name required"
                return
            }
            statusMessage = "Capturing windows..."
            let layout = try windowManager.captureCurrentLayout(name: normalized)
            try store.save(layout)
            statusMessage = "Saved \(layout.apps.count) apps"
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
                statusMessage = "Updating layout..."
                let captured = try windowManager.captureCurrentLayout(name: layout.name)
                let updatedLayout = Layout(
                    id: layout.id,
                    name: layout.name,
                    createdAt: layout.createdAt,
                    updatedAt: .now,
                    pinned: layout.pinned,
                    spacePolicy: layout.spacePolicy,
                    extraWindowsBehaviorDefault: layout.extraWindowsBehaviorDefault,
                    apps: captured.apps
                )
                try store.save(updatedLayout)
                statusMessage = "Updated \(layout.name)"
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
            statusMessage = "Launching apps..."
            let report = await windowManager.restoreLayout(layout, appLauncher: appLauncher)
            latestReport = report

            if !report.failures.isEmpty {
                statusMessage = report.failures.first?.message ?? "Restore failed"
            } else if !report.unreconciledWindows.isEmpty {
                statusMessage = "Restored with \(report.unreconciledWindows.count) unresolved windows"
            } else {
                statusMessage = "Done"
            }
        }
    }

    func delete(_ layout: Layout) {
        do {
            try store.deleteLayout(id: layout.id)
            statusMessage = "Deleted \(layout.name)"
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
            statusMessage = "Renamed layout"
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
            statusMessage = layout.pinned ? "Unpinned \(layout.name)" : "Pinned \(layout.name)"
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
