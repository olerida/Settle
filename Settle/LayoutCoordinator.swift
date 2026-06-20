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
    @Published var isCloseAllConfirmationPresented = false
    @Published var isAboutPresented = false
    @Published var latestReport: RestoreReport?

    let permissionManager: AccessibilityPermissionManager
    let store: LayoutStore
    let settings: AppSettings

    private let windowManager: WindowManager
    private let appLauncher: AppLauncher
    private let hudController: LayoutHUDController
    private var cancellables = Set<AnyCancellable>()
    private var restoredLayoutIDs = Set<UUID>()
    private var layoutNavigationMemory = LayoutNavigationMemory<WindowManager.LayoutNavigationTarget>()
    private var lastDetectedLayoutID: UUID? {
        didSet {
            guard lastDetectedLayoutID != oldValue else { return }
            objectWillChange.send()
        }
    }
    private var lastPresentedLayoutID: UUID?
    private var lastPresentedAt: Date = .distantPast
    private var activeSpaceTask: Task<Void, Never>?
    private var didAttemptDefaultLayoutRestore = false

    init(
        permissionManager: AccessibilityPermissionManager = AccessibilityPermissionManager(),
        store: LayoutStore = LayoutStore(),
        settings: AppSettings = AppSettings(),
        windowManager: WindowManager = WindowManager(),
        appLauncher: AppLauncher = AppLauncher(),
        hudController: LayoutHUDController = LayoutHUDController()
    ) {
        self.permissionManager = permissionManager
        self.store = store
        self.settings = settings
        self.windowManager = windowManager
        self.appLauncher = appLauncher
        self.hudController = hudController
        self.saveName = Self.defaultLayoutName()
        settings.reconcileDefaultLayout(availableLayoutIDs: Set(store.layouts.map(\.id)))

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

    var pinnedLayouts: [Layout] {
        store.layouts.filter(\.pinned)
    }

    var unpinnedLayouts: [Layout] {
        store.layouts.filter { !$0.pinned }
    }

    var appVersionDescription: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(shortVersion) (\(buildNumber))"
    }

    var isOverlayPresented: Bool {
        isCloseAllConfirmationPresented
            || isAboutPresented
            || isSaveSheetPresented
            || renamingLayout != nil
    }

    var activeRestoredLayout: Layout? {
        guard let lastDetectedLayoutID else { return nil }
        return store.layouts.first(where: { $0.id == lastDetectedLayoutID })
    }

    func isLayoutRememberedActive(_ layout: Layout) -> Bool {
        layoutNavigationMemory.contains(layoutID: layout.id)
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

    func refreshActiveLayoutForCurrentSpace() {
        scheduleActiveSpaceDetection()
    }

    func restoreDefaultLayoutAfterLogin() {
        guard !didAttemptDefaultLayoutRestore else { return }
        didAttemptDefaultLayoutRestore = true

        settings.reconcileDefaultLayout(availableLayoutIDs: Set(store.layouts.map(\.id)))
        guard
            let defaultLayoutID = settings.defaultLayoutID,
            let layout = store.layouts.first(where: { $0.id == defaultLayoutID })
        else {
            return
        }

        permissionManager.refresh()
        guard permissionManager.isTrusted else {
            statusMessage = L10n.tr("Automatic restore skipped because Accessibility access is missing.")
            return
        }

        Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard
                settings.defaultLayoutID == layout.id,
                store.layouts.contains(where: { $0.id == layout.id })
            else {
                return
            }
            restore(layout)
        }
    }

    func prepareSave() {
        saveName = Self.defaultLayoutName()
        isSaveSheetPresented = true
    }

    func cancelSave() {
        isSaveSheetPresented = false
    }

    func presentAbout() {
        isAboutPresented = true
    }

    func dismissAbout() {
        isAboutPresented = false
    }

    func dismissOverlay() {
        if isCloseAllConfirmationPresented {
            cancelCloseAllWindows()
        } else if isAboutPresented {
            dismissAbout()
        } else if isSaveSheetPresented {
            cancelSave()
        } else if renamingLayout != nil {
            cancelRename()
        }
    }

    func askToCloseAllWindows() {
        isCloseAllConfirmationPresented = true
    }

    func cancelCloseAllWindows() {
        isCloseAllConfirmationPresented = false
    }

    func closeAllWindows() {
        isCloseAllConfirmationPresented = false

        Task {
            do {
                statusMessage = L10n.tr("Closing apps...")
                let closedWindows = try await windowManager.closeAllWindowsAcrossAllSpaces(
                    excludingBundleIdentifiers: Set([Bundle.main.bundleIdentifier].compactMap { $0 })
                )
                restoredLayoutIDs.removeAll()
                clearRememberedLayouts()
                lastDetectedLayoutID = nil

                statusMessage = closedWindows > 0
                    ? L10n.format("Closed %d apps", closedWindows)
                    : L10n.tr("No apps to close")
            } catch {
                statusMessage = error.localizedDescription
                if !permissionManager.isTrusted {
                    permissionManager.refresh()
                }
            }
        }
    }

    func closeWindowsOutsideActiveLayout() {
        mutateWindowsOutsideActiveLayout(action: .close)
    }

    func minimizeWindowsOutsideActiveLayout() {
        mutateWindowsOutsideActiveLayout(action: .minimize)
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
                    pinnedOrder: layout.pinnedOrder,
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
                forgetRememberedLayout(layout.id)
                restoredLayoutIDs.remove(layout.id)
                if lastDetectedLayoutID == layout.id {
                    lastDetectedLayoutID = nil
                }
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
                try? await Task.sleep(for: .milliseconds(150))
                await handleActiveSpaceChange()
            }
        }
    }

    func navigateToRememberedLayout(_ layout: Layout) {
        guard layoutNavigationMemory.contains(layoutID: layout.id) else { return }

        statusMessage = L10n.format("Switching to %@...", layout.name)
        attemptNavigation(to: layout)
    }

    private func attemptNavigation(to layout: Layout) {
        let targets = layoutNavigationMemory.targets(for: layout.id)
        guard !targets.isEmpty else {
            statusMessage = L10n.format("%@ is no longer active", layout.name)
            return
        }

        switch windowManager.navigate(to: targets) {
        case .requested:
            Task {
                try? await Task.sleep(for: .milliseconds(900))
                await handleActiveSpaceChange()
                if lastDetectedLayoutID == layout.id {
                    statusMessage = L10n.format("Opened Space for %@", layout.name)
                } else if !layoutNavigationMemory.contains(layoutID: layout.id) {
                    statusMessage = L10n.format("%@ is no longer active", layout.name)
                } else if !layoutNavigationMemory.contains(layoutID: layout.id, targetGroup: targets) {
                    statusMessage = L10n.format("%@ is incomplete in this Space", layout.name)
                } else {
                    statusMessage = L10n.format("Could not switch to the Space for %@", layout.name)
                }
            }
        case .noRemainingWindows:
            forgetRememberedTargets(targets, for: layout.id)
            if lastDetectedLayoutID == layout.id {
                lastDetectedLayoutID = nil
            }
            if layoutNavigationMemory.contains(layoutID: layout.id) {
                attemptNavigation(to: layout)
            } else {
                statusMessage = L10n.format("%@ is no longer active", layout.name)
            }
        case .failed:
            statusMessage = L10n.format("Could not switch to the Space for %@", layout.name)
        }
    }

    func delete(_ layout: Layout) {
        do {
            try store.deleteLayout(id: layout.id)
            settings.clearDefaultLayout(ifMatches: layout.id)
            restoredLayoutIDs.remove(layout.id)
            forgetRememberedLayout(layout.id)
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

    func movePinnedLayout(from sourceIndex: Int, to destinationIndex: Int) {
        do {
            try store.movePinnedLayout(from: sourceIndex, to: destinationIndex)
            statusMessage = L10n.tr("Updated pinned layouts")
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
        guard !restoredLayouts.isEmpty else {
            lastDetectedLayoutID = nil
            return
        }

        do {
            let inspection = try windowManager.inspectCurrentSpace(among: restoredLayouts)
            let matchedLayoutID = inspection.matchedLayout?.id

            for rememberedLayoutID in layoutNavigationMemory.rememberedLayoutIDs where rememberedLayoutID != matchedLayoutID {
                for targetGroup in layoutNavigationMemory.targetGroups(for: rememberedLayoutID) {
                    if inspection.containsAny(targetGroup) {
                        forgetRememberedTargets(targetGroup, for: rememberedLayoutID)
                    }
                }
            }

            guard let matchedLayout = inspection.matchedLayout else {
                lastDetectedLayoutID = nil
                return
            }

            rememberLayout(matchedLayout.id, targets: inspection.navigationTargets)

            guard matchedLayout.id != lastDetectedLayoutID || shouldRedisplayHUD(for: matchedLayout.id) else {
                return
            }

            lastDetectedLayoutID = matchedLayout.id
            presentHUD(for: matchedLayout)
        } catch {
            lastDetectedLayoutID = nil
        }
    }

    private func rememberLayout(
        _ layoutID: UUID,
        targets: [WindowManager.LayoutNavigationTarget]
    ) {
        objectWillChange.send()
        layoutNavigationMemory.remember(layoutID: layoutID, targets: targets)
    }

    private func forgetRememberedLayout(_ layoutID: UUID) {
        guard layoutNavigationMemory.contains(layoutID: layoutID) else { return }
        objectWillChange.send()
        layoutNavigationMemory.forget(layoutID: layoutID)
    }

    private func forgetRememberedTargets(
        _ targets: [WindowManager.LayoutNavigationTarget],
        for layoutID: UUID
    ) {
        guard layoutNavigationMemory.contains(layoutID: layoutID, targetGroup: targets) else { return }
        objectWillChange.send()
        layoutNavigationMemory.forget(layoutID: layoutID, targetGroup: targets)
    }

    private func clearRememberedLayouts() {
        guard !layoutNavigationMemory.rememberedLayoutIDs.isEmpty else { return }
        objectWillChange.send()
        layoutNavigationMemory.removeAll()
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

    private func mutateWindowsOutsideActiveLayout(action: WindowManager.WindowMutationAction) {
        guard let layout = activeRestoredLayout else {
            statusMessage = L10n.tr("Current Space does not match a restored layout.")
            return
        }

        Task {
            do {
                statusMessage = action == .close
                    ? L10n.tr("Closing other windows...")
                    : L10n.tr("Minimizing other windows...")
                let affectedWindows = try await windowManager.mutateVisibleWindowsOutsideLayoutInCurrentSpace(layout, action: action)
                statusMessage = switch action {
                case .close:
                    affectedWindows > 0
                        ? L10n.format("Closed %d extra windows", affectedWindows)
                        : L10n.tr("No extra windows found")
                case .minimize:
                    affectedWindows > 0
                        ? L10n.format("Minimized %d extra windows", affectedWindows)
                        : L10n.tr("No extra windows found")
                }
            } catch {
                statusMessage = error.localizedDescription
                if !permissionManager.isTrusted {
                    permissionManager.refresh()
                }
            }
        }
    }
}
