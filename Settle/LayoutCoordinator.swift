import AppKit
import Combine
import Foundation

enum RestorePanelState: Equatable {
    case idle
    case restoring
    case completedSuccessfully
    case completedWithIncidents
}

@MainActor
final class LayoutCoordinator: ObservableObject {
    @Published var statusMessage = L10n.tr("Ready")
    @Published var saveName = ""
    @Published var shouldSaveBrowserTabs = false
    @Published private(set) var canSaveBrowserTabs = false
    @Published private(set) var saveErrorMessage: String?
    @Published private(set) var isBrowserAutomationDenied = false
    @Published var renameName = ""
    @Published var isSaveSheetPresented = false
    @Published var renamingLayout: Layout?
    @Published var isCloseAllConfirmationPresented = false
    @Published var isAboutPresented = false
    @Published var previewedLayoutID: UUID?
    @Published var latestReport: RestoreReport?
    @Published private(set) var restorePanelState: RestorePanelState = .idle
    @Published private(set) var layoutSwitcherShortcutError: String?

    let permissionManager: AccessibilityPermissionManager
    let store: LayoutStore
    let settings: AppSettings

    private let windowManager: WindowManager
    private let appLauncher: AppLauncher
    private let hudController: LayoutHUDController
    private let layoutSwitcherHotKeyManager: LayoutSwitcherHotKeyManager
    private let layoutSwitcherController: LayoutSwitcherController
    private var cancellables = Set<AnyCancellable>()
    private var restoredLayoutIDs = Set<UUID>()
    private var layoutNavigationMemory = LayoutNavigationMemory<WindowManager.LayoutNavigationTarget>()
    private var recentlyActiveLayoutIDs: [UUID] = []
    private var selectedSwitcherLayoutID: UUID?
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
    private var layoutBeingUpdated: Layout?

    init(
        permissionManager: AccessibilityPermissionManager = AccessibilityPermissionManager(),
        store: LayoutStore = LayoutStore(),
        settings: AppSettings = AppSettings(),
        windowManager: WindowManager = WindowManager(),
        appLauncher: AppLauncher = AppLauncher(),
        hudController: LayoutHUDController = LayoutHUDController(),
        layoutSwitcherHotKeyManager: LayoutSwitcherHotKeyManager = LayoutSwitcherHotKeyManager(),
        layoutSwitcherController: LayoutSwitcherController = LayoutSwitcherController()
    ) {
        self.permissionManager = permissionManager
        self.store = store
        self.settings = settings
        self.windowManager = windowManager
        self.appLauncher = appLauncher
        self.hudController = hudController
        self.layoutSwitcherHotKeyManager = layoutSwitcherHotKeyManager
        self.layoutSwitcherController = layoutSwitcherController
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

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            do {
                try layoutSwitcherHotKeyManager.start(
                    shortcut: settings.layoutSwitcherShortcut
                ) { [weak self] event in
                    self?.handleLayoutSwitcherHotKeyEvent(event)
                }
            } catch {
                layoutSwitcherShortcutError = L10n.tr("The shortcut is already in use by Settle or another app.")
            }
        }
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

    var isSnapshotPreviewPresented: Bool {
        previewedLayoutID != nil
    }

    var isUpdatingLayout: Bool {
        layoutBeingUpdated != nil
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

    func setLayoutSwitcherShortcut(_ shortcut: LayoutSwitcherShortcut?) {
        let previousShortcut = settings.layoutSwitcherShortcut
        do {
            try layoutSwitcherHotKeyManager.resume()
            try layoutSwitcherHotKeyManager.apply(shortcut)
            settings.setLayoutSwitcherShortcut(shortcut)
            layoutSwitcherShortcutError = nil
        } catch {
            try? layoutSwitcherHotKeyManager.apply(previousShortcut)
            layoutSwitcherShortcutError = L10n.tr("The shortcut is already in use by Settle or another app.")
        }
    }

    func resetLayoutSwitcherShortcut() {
        setLayoutSwitcherShortcut(.defaultShortcut)
    }

    func reportInvalidLayoutSwitcherShortcut() {
        layoutSwitcherShortcutError = L10n.tr("Use exactly one modifier and one key. Shift is reserved for moving backward.")
    }

    func setLayoutSwitcherShortcutRecording(_ isRecording: Bool) {
        if isRecording {
            layoutSwitcherShortcutError = nil
            layoutSwitcherHotKeyManager.suspend()
        } else {
            do {
                try layoutSwitcherHotKeyManager.resume()
            } catch {
                layoutSwitcherShortcutError = L10n.tr("The shortcut is already in use by Settle or another app.")
            }
        }
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
        saveErrorMessage = nil
        isBrowserAutomationDenied = false
        let fallback = Self.defaultLayoutName()
        do {
            let apps = try windowManager.captureVisibleAppSnapshots()
            canSaveBrowserTabs = apps.contains { BrowserTabManager.supports(bundleIdentifier: $0.bundleIdentifier) }
            shouldSaveBrowserTabs = false
            layoutBeingUpdated = nil
            saveName = Self.suggestedLayoutName(
                for: apps.map(\.appDisplayName),
                fallback: fallback
            )
        } catch {
            saveName = fallback
            canSaveBrowserTabs = false
            shouldSaveBrowserTabs = false
            layoutBeingUpdated = nil
        }
        isSaveSheetPresented = true
    }

    func cancelSave() {
        isSaveSheetPresented = false
        layoutBeingUpdated = nil
        saveErrorMessage = nil
        isBrowserAutomationDenied = false
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

    func setSnapshotPreview(_ layoutID: UUID, isPresented: Bool) {
        if isPresented {
            previewedLayoutID = layoutID
        } else if previewedLayoutID == layoutID {
            previewedLayoutID = nil
        }
    }

    func dismissSnapshotPreview() {
        previewedLayoutID = nil
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
            saveErrorMessage = nil
            isBrowserAutomationDenied = false
            let normalized = layoutBeingUpdated?.name
                ?? name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else {
                statusMessage = L10n.tr("Name required")
                return
            }
            statusMessage = L10n.tr("Capturing windows...")
            let captured = try windowManager.captureCurrentLayout(name: normalized, includingBrowserTabs: shouldSaveBrowserTabs)
            let layout = makeSavedLayout(from: captured.layout, name: normalized)
            let snapshotPNGData = windowManager.captureDesktopSnapshotPNGData(
                for: layout,
                previewWindows: captured.previewWindows
            )
            try store.save(layout, snapshotPNGData: snapshotPNGData)
            statusMessage = L10n.format("Saved %d apps", layout.apps.count)
            isSaveSheetPresented = false
            layoutBeingUpdated = nil
            presentHUD(for: layout)
            registerCapturedLayoutAsActive(layout)
        } catch {
            statusMessage = error.localizedDescription
            saveErrorMessage = error.localizedDescription
            if case BrowserTabManagerError.automationPermissionDenied = error {
                isBrowserAutomationDenied = true
            }
            if !permissionManager.isTrusted {
                permissionManager.refresh()
            }
        }
    }

    func prepareOverwrite(_ layout: Layout) {
        do {
            saveErrorMessage = nil
            isBrowserAutomationDenied = false
            layoutBeingUpdated = layout
            canSaveBrowserTabs = try windowManager.captureVisibleAppSnapshots().contains {
                BrowserTabManager.supports(bundleIdentifier: $0.bundleIdentifier)
            }
            shouldSaveBrowserTabs = layout.restoresBrowserTabs
            saveName = layout.name
            if canSaveBrowserTabs {
                isSaveSheetPresented = true
            } else {
                Task {
                    await saveCurrentLayout(named: layout.name)
                }
            }
        } catch {
            layoutBeingUpdated = nil
            statusMessage = error.localizedDescription
        }
    }

    func openBrowserAutomationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") else { return }
        NSWorkspace.shared.open(url)
    }

    var savePanelTitle: String { L10n.tr(layoutBeingUpdated == nil ? "Save Current Layout" : "Update Layout") }
    var savePanelActionTitle: String { L10n.tr(layoutBeingUpdated == nil ? "Save" : "Update") }

    private func makeSavedLayout(from captured: Layout, name: String) -> Layout {
        guard let existing = layoutBeingUpdated else { return captured }
        return Layout(
            id: existing.id,
            name: existing.name,
            createdAt: existing.createdAt,
            updatedAt: .now,
            pinned: existing.pinned,
            pinnedOrder: existing.pinnedOrder,
            snapshotFileName: existing.snapshotFileName,
            spacePolicy: existing.spacePolicy,
            extraWindowsBehaviorDefault: existing.extraWindowsBehaviorDefault,
            restoresBrowserTabs: captured.restoresBrowserTabs,
            apps: captured.apps
        )
    }

    func restore(_ layout: Layout) {
        restorePanelState = .restoring
        Task {
            statusMessage = L10n.tr("Launching apps...")
            var report = await windowManager.restoreLayout(layout, appLauncher: appLauncher)

            if report.completedSuccessfully, let action = automaticExtraWindowsAction {
                do {
                    statusMessage = action == .close
                        ? L10n.tr("Closing other windows...")
                        : L10n.tr("Minimizing other windows...")
                    try? await Task.sleep(for: .milliseconds(150))
                    let affectedWindows = try await windowManager.mutateVisibleWindowsOutsideLayoutInCurrentSpace(
                        layout,
                        action: action
                    )
                    if affectedWindows > 0 {
                        statusMessage = action == .close
                            ? L10n.format("Closed %d extra windows", affectedWindows)
                            : L10n.format("Minimized %d extra windows", affectedWindows)
                    }
                } catch {
                    report.failures.append(
                        RestoreFailure(appName: "Settle", message: error.localizedDescription)
                    )
                    if !permissionManager.isTrusted {
                        permissionManager.refresh()
                    }
                }
            }

            latestReport = report

            if !report.missingApps.isEmpty {
                statusMessage = L10n.format("Missing apps: %@", report.missingApps.joined(separator: ", "))
            } else if !report.failures.isEmpty {
                statusMessage = report.failures.first?.message ?? L10n.tr("Restore failed")
            } else if !report.unreconciledWindows.isEmpty {
                statusMessage = L10n.format("Unresolved apps: %@", report.unreconciledApps.joined(separator: ", "))
            } else {
                statusMessage = L10n.tr("Done")
            }
            restorePanelState = report.completedSuccessfully
                ? .completedSuccessfully
                : .completedWithIncidents

            let restoreDidMeaningfullyRun = !report.restoredWindows.isEmpty || !report.launchedApps.isEmpty || report.failures.isEmpty
            if restoreDidMeaningfullyRun {
                restoredLayoutIDs.insert(layout.id)
                try? await Task.sleep(for: .milliseconds(150))
                await handleActiveSpaceChange()
            }
        }
    }

    private var automaticExtraWindowsAction: WindowManager.WindowMutationAction? {
        switch settings.automaticExtraWindowsBehavior {
        case .leaveUntouched:
            nil
        case .minimize:
            .minimize
        case .close:
            .close
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

    func closeActiveLayout(_ layout: Layout) {
        guard lastDetectedLayoutID == layout.id else {
            statusMessage = L10n.format("%@ is no longer active", layout.name)
            return
        }

        Task {
            statusMessage = L10n.format("Closing %@...", layout.name)
            do {
                let closedWindows = try await windowManager.closeLayoutWindowsInCurrentSpace(layout)
                restoredLayoutIDs.remove(layout.id)
                forgetRememberedLayout(layout.id)
                lastDetectedLayoutID = nil
                latestReport = nil
                restorePanelState = .idle
                statusMessage = closedWindows > 0
                    ? L10n.format("Closed layout %@", layout.name)
                    : L10n.format("%@ is no longer active", layout.name)
            } catch {
                statusMessage = error.localizedDescription
                if !permissionManager.isTrusted {
                    permissionManager.refresh()
                }
            }
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

    static func suggestedLayoutName(for appNames: [String], fallback: String) -> String {
        var names: [String] = []
        for appName in appNames {
            let normalized = appName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, !names.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) else {
                continue
            }
            names.append(normalized)
        }

        switch names.count {
        case 0:
            return fallback
        case 1...3:
            return names.joined(separator: " · ")
        default:
            return "\(names[0]) · \(names[1]) +\(names.count - 2)"
        }
    }

    private func handleLayoutSwitcherHotKeyEvent(_ event: LayoutSwitcherHotKeyManager.Event) {
        switch event {
        case .cycle(let direction):
            cycleActiveLayouts(direction: direction)
        case .activate:
            activateSelectedSwitcherLayout()
        case .cancel:
            dismissLayoutSwitcher()
        }
    }

    private func cycleActiveLayouts(direction: LayoutSwitcherDirection) {
        let layouts = activeLayoutsInRecencyOrder
        guard !layouts.isEmpty else {
            statusMessage = L10n.tr("No active layouts")
            hudController.show(layoutName: L10n.tr("No active layouts"))
            layoutSwitcherHotKeyManager.cancelCycle()
            return
        }

        if layouts.count == 1, layouts[0].id == lastDetectedLayoutID {
            statusMessage = L10n.tr("You are already on the only active layout")
            hudController.show(layoutName: L10n.tr("You are already on the only active layout"))
            layoutSwitcherHotKeyManager.cancelCycle()
            return
        }

        let currentID = layoutSwitcherController.isVisible
            ? selectedSwitcherLayoutID
            : lastDetectedLayoutID
        let currentIndex = currentID.flatMap { id in layouts.firstIndex(where: { $0.id == id }) }
        guard let nextIndex = LayoutSwitcherSelection.nextIndex(
            from: currentIndex,
            count: layouts.count,
            direction: direction
        ) else {
            layoutSwitcherHotKeyManager.cancelCycle()
            return
        }

        let selectedLayout = layouts[nextIndex]
        selectedSwitcherLayoutID = selectedLayout.id
        layoutSwitcherController.show(
            items: layouts.map(layoutSwitcherItem),
            selectedID: selectedLayout.id,
            shortcut: settings.layoutSwitcherShortcut ?? .defaultShortcut
        )
    }

    private func activateSelectedSwitcherLayout() {
        let layouts = activeLayoutsInRecencyOrder
        let selectedLayout = selectedSwitcherLayoutID
            .flatMap { selectedID in layouts.first(where: { $0.id == selectedID }) }
            ?? layouts.first
        dismissLayoutSwitcher()
        guard let selectedLayout else { return }
        guard selectedLayout.id != lastDetectedLayoutID else { return }
        navigateToRememberedLayout(selectedLayout)
    }

    private func dismissLayoutSwitcher() {
        selectedSwitcherLayoutID = nil
        layoutSwitcherController.dismiss()
    }

    private var activeLayoutsInRecencyOrder: [Layout] {
        let availableLayouts = store.layouts
        let orderedIDs = LayoutSwitcherActiveOrder.orderedIDs(
            recentlyActiveIDs: recentlyActiveLayoutIDs,
            rememberedIDs: layoutNavigationMemory.rememberedLayoutIDs,
            currentID: lastDetectedLayoutID,
            availableIDs: availableLayouts.map(\.id)
        )
        return orderedIDs.compactMap { id in
            availableLayouts.first(where: { $0.id == id })
        }
    }

    private func layoutSwitcherItem(for layout: Layout) -> LayoutSwitcherItem {
        LayoutSwitcherItem(
            id: layout.id,
            name: layout.name,
            snapshotURL: store.snapshotURL(for: layout)
        )
    }

    private func refreshVisibleLayoutSwitcher() {
        guard layoutSwitcherController.isVisible else { return }
        let layouts = activeLayoutsInRecencyOrder
        guard !layouts.isEmpty else {
            layoutSwitcherHotKeyManager.cancelCycle()
            return
        }
        let selectedID = selectedSwitcherLayoutID
            .flatMap { id in layouts.contains(where: { $0.id == id }) ? id : nil }
            ?? layouts[0].id
        selectedSwitcherLayoutID = selectedID
        layoutSwitcherController.show(
            items: layouts.map(layoutSwitcherItem),
            selectedID: selectedID,
            shortcut: settings.layoutSwitcherShortcut ?? .defaultShortcut
        )
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
        guard layoutNavigationMemory.contains(layoutID: layoutID) else { return }
        recentlyActiveLayoutIDs.removeAll { $0 == layoutID }
        recentlyActiveLayoutIDs.insert(layoutID, at: 0)
        refreshVisibleLayoutSwitcher()
    }

    private func registerCapturedLayoutAsActive(_ layout: Layout) {
        restoredLayoutIDs.insert(layout.id)
        lastDetectedLayoutID = layout.id

        guard
            let inspection = try? windowManager.inspectCurrentSpace(among: [layout]),
            inspection.matchedLayout?.id == layout.id,
            !inspection.navigationTargets.isEmpty
        else {
            return
        }
        rememberLayout(layout.id, targets: inspection.navigationTargets)
    }

    private func forgetRememberedLayout(_ layoutID: UUID) {
        guard layoutNavigationMemory.contains(layoutID: layoutID) else { return }
        objectWillChange.send()
        layoutNavigationMemory.forget(layoutID: layoutID)
        recentlyActiveLayoutIDs.removeAll { $0 == layoutID }
        refreshVisibleLayoutSwitcher()
    }

    private func forgetRememberedTargets(
        _ targets: [WindowManager.LayoutNavigationTarget],
        for layoutID: UUID
    ) {
        guard layoutNavigationMemory.contains(layoutID: layoutID, targetGroup: targets) else { return }
        objectWillChange.send()
        layoutNavigationMemory.forget(layoutID: layoutID, targetGroup: targets)
        if !layoutNavigationMemory.contains(layoutID: layoutID) {
            recentlyActiveLayoutIDs.removeAll { $0 == layoutID }
        }
        refreshVisibleLayoutSwitcher()
    }

    private func clearRememberedLayouts() {
        guard !layoutNavigationMemory.rememberedLayoutIDs.isEmpty else { return }
        objectWillChange.send()
        layoutNavigationMemory.removeAll()
        recentlyActiveLayoutIDs.removeAll()
        layoutSwitcherHotKeyManager.cancelCycle()
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
