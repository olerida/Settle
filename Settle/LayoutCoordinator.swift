import AppKit
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
    private let hudController: LayoutHUDController
    private var cancellables = Set<AnyCancellable>()
    private var restoredLayoutIDs = Set<UUID>()
    private var lastDetectedLayoutID: UUID?
    private var lastPresentedLayoutID: UUID?
    private var lastPresentedAt: Date = .distantPast
    private var activeSpaceTask: Task<Void, Never>?

    init(
        permissionManager: AccessibilityPermissionManager = AccessibilityPermissionManager(),
        store: LayoutStore = LayoutStore(),
        windowManager: WindowManager = WindowManager(),
        appLauncher: AppLauncher = AppLauncher(),
        hudController: LayoutHUDController = LayoutHUDController()
    ) {
        self.permissionManager = permissionManager
        self.store = store
        self.windowManager = windowManager
        self.appLauncher = appLauncher
        self.hudController = hudController
        self.saveName = Self.defaultLayoutName()

        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleActiveSpaceDetection()
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

    func cancelSave() {
        isSaveSheetPresented = false
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
            presentHUD(for: captured.layout)
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
                presentHUD(for: updatedLayout)
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

            let restoreDidMeaningfullyRun = !report.restoredWindows.isEmpty || !report.launchedApps.isEmpty || report.failures.isEmpty
            if restoreDidMeaningfullyRun {
                restoredLayoutIDs.insert(layout.id)
                lastDetectedLayoutID = layout.id
                presentHUD(for: layout)
            }
        }
    }

    func delete(_ layout: Layout) {
        do {
            try store.deleteLayout(id: layout.id)
            restoredLayoutIDs.remove(layout.id)
            if lastDetectedLayoutID == layout.id {
                lastDetectedLayoutID = nil
            }
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

    private func scheduleActiveSpaceDetection() {
        activeSpaceTask?.cancel()
        activeSpaceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await self?.handleActiveSpaceChange()
        }
    }

    private func handleActiveSpaceChange() async {
        guard permissionManager.isTrusted else { return }

        let restoredLayouts = store.layouts.filter { restoredLayoutIDs.contains($0.id) }
        guard !restoredLayouts.isEmpty else { return }

        do {
            let currentApps = try windowManager.captureVisibleAppSnapshots()
            guard let matchedLayout = LayoutVisibilityMatcher.bestMatch(currentApps: currentApps, among: restoredLayouts) else {
                lastDetectedLayoutID = nil
                return
            }

            guard matchedLayout.id != lastDetectedLayoutID || shouldRedisplayHUD(for: matchedLayout.id) else {
                return
            }

            lastDetectedLayoutID = matchedLayout.id
            presentHUD(for: matchedLayout)
        } catch {
            lastDetectedLayoutID = nil
        }
    }

    private func presentHUD(for layout: Layout) {
        guard shouldRedisplayHUD(for: layout.id) else { return }
        lastPresentedLayoutID = layout.id
        lastPresentedAt = .now
        hudController.show(layoutName: layout.name)
    }

    private func shouldRedisplayHUD(for layoutID: UUID) -> Bool {
        guard lastPresentedLayoutID == layoutID else { return true }
        return Date.now.timeIntervalSince(lastPresentedAt) > 2
    }
}
