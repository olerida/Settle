import ApplicationServices
import CoreGraphics
import XCTest
@testable import Settle

final class SettleTests: XCTestCase {
    func testDisplayCoordinateConversionUsesAXTopLeftOrigin() {
        let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)

        XCTAssertEqual(
            DisplayPlacement.appKitRectToAX(
                CGRect(x: -1920, y: 0, width: 1920, height: 1080),
                primaryFrame: primary
            ),
            CGRect(x: -1920, y: -180, width: 1920, height: 1080)
        )
        XCTAssertEqual(
            DisplayPlacement.appKitRectToAX(
                CGRect(x: 0, y: 900, width: 1920, height: 1080),
                primaryFrame: primary
            ),
            CGRect(x: 0, y: -1080, width: 1920, height: 1080)
        )
    }

    func testCaptureChoosesDisplayWithLargestIntersection() {
        let main = display(uuid: "main", name: "Main", frame: CGRect(x: 0, y: 0, width: 1000, height: 800), isMain: true)
        let right = display(uuid: "right", name: "Right", frame: CGRect(x: 1000, y: 0, width: 1200, height: 900))

        let selected = DisplayPlacement.displayContainingLargestArea(
            of: CGRect(x: 900, y: 100, width: 400, height: 500),
            displays: [main, right]
        )

        XCTAssertEqual(selected, right)
    }

    func testDisplayMatchingUsesUUIDBeforeGeometry() {
        let captured = display(uuid: "display-b", name: "Studio Display", frame: CGRect(x: 1000, y: 0, width: 1000, height: 800))
        let moved = display(uuid: "display-b", name: "Studio Display", frame: CGRect(x: -1600, y: -200, width: 1600, height: 1000))
        let other = display(uuid: "display-a", name: "Studio Display", frame: CGRect(x: 0, y: 0, width: 1200, height: 900), isMain: true)

        let matches = DisplayPlacement.matchDisplays(captured: [captured], current: [other, moved])

        XCTAssertEqual(matches[captured], moved)
    }

    func testDisplayMatchingUsesHardwareIdentityWhenUUIDChanges() {
        let captured = display(
            uuid: "old",
            name: "External",
            frame: CGRect(x: 1000, y: 0, width: 1000, height: 800),
            hardware: (10, 20, 30)
        )
        let current = display(
            uuid: "new",
            name: "Renamed",
            frame: CGRect(x: -1200, y: 0, width: 1200, height: 900),
            hardware: (10, 20, 30)
        )

        XCTAssertEqual(
            DisplayPlacement.matchDisplays(captured: [captured], current: [current])[captured],
            current
        )
    }

    func testAmbiguousDisplayNamesDoNotReuseOneDisplay() {
        let capturedA = display(uuid: nil, name: "Display", frame: CGRect(x: 0, y: 0, width: 1000, height: 800), isMain: true)
        let capturedB = display(uuid: nil, name: "Display", frame: CGRect(x: 1000, y: 0, width: 1000, height: 800))
        let currentA = display(uuid: nil, name: "Display", frame: CGRect(x: 0, y: 0, width: 1200, height: 900), isMain: true)
        let currentB = display(uuid: nil, name: "Display", frame: CGRect(x: 1200, y: 0, width: 1200, height: 900))

        let matches = DisplayPlacement.matchDisplays(
            captured: [capturedA, capturedB],
            current: [currentA, currentB]
        )

        XCTAssertTrue(matches.isEmpty)
    }

    func testNormalizedPlacementTracksMovedAndResizedDisplay() throws {
        let captured = display(uuid: "external", name: "External", frame: CGRect(x: 1000, y: 0, width: 1000, height: 800))
        let current = display(uuid: "external", name: "External", frame: CGRect(x: -1200, y: -100, width: 1200, height: 900))
        let normalized = try XCTUnwrap(
            DisplayPlacement.normalizedFrame(
                CGRect(x: 1100, y: 80, width: 500, height: 400),
                in: captured.visibleFrame.cgRect
            )
        )
        let snapshot = window(
            frame: CGRect(x: 1100, y: 80, width: 500, height: 400),
            display: captured,
            normalizedFrame: normalized
        )

        let placement = try XCTUnwrap(
            DisplayPlacement.placement(
                for: snapshot,
                currentDisplays: [current],
                displayMatches: [captured: current]
            )
        )

        XCTAssertEqual(placement.frame, CGRect(x: -1080, y: -10, width: 600, height: 450))
        XCTAssertEqual(placement.display, current)
    }

    func testMissingDisplayFallsBackToMainUsingNormalizedGeometry() throws {
        let missing = display(uuid: "missing", name: "Missing", frame: CGRect(x: 1000, y: 0, width: 1000, height: 800))
        let main = display(uuid: "main", name: "Main", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), isMain: true)
        let snapshot = window(
            frame: CGRect(x: 1250, y: 200, width: 500, height: 400),
            display: missing,
            normalizedFrame: WindowFrame(rect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
        )

        let placement = try XCTUnwrap(
            DisplayPlacement.placement(
                for: snapshot,
                currentDisplays: [main],
                displayMatches: [:]
            )
        )

        XCTAssertEqual(placement.frame, CGRect(x: 360, y: 225, width: 720, height: 450))
        XCTAssertEqual(placement.display, main)
    }

    func testClampFitsOversizedWindowInsideVisibleFrame() {
        XCTAssertEqual(
            DisplayPlacement.clamp(
                CGRect(x: -2000, y: -200, width: 2000, height: 1200),
                to: CGRect(x: -1200, y: 0, width: 1200, height: 900)
            ),
            CGRect(x: -1200, y: 0, width: 1200, height: 900)
        )
    }

    func testLegacyAbsoluteFrameUsesIntersectingDisplayAndClamps() throws {
        let main = display(uuid: "main", name: "Main", frame: CGRect(x: 0, y: 0, width: 1000, height: 800), isMain: true)
        let left = display(uuid: "left", name: "Left", frame: CGRect(x: -1200, y: 0, width: 1200, height: 900))
        let legacy = window(frame: CGRect(x: -1300, y: 100, width: 500, height: 400))

        let placement = try XCTUnwrap(
            DisplayPlacement.placement(
                for: legacy,
                currentDisplays: [main, left],
                displayMatches: [:]
            )
        )

        XCTAssertEqual(placement.display, left)
        XCTAssertEqual(placement.frame, CGRect(x: -1200, y: 100, width: 500, height: 400))
    }

    func testPlacementValidationRequiresReachableTitleBar() {
        let display = display(uuid: "main", name: "Main", frame: CGRect(x: 0, y: 0, width: 1000, height: 800), isMain: true)

        XCTAssertTrue(
            DisplayPlacement.isUsable(CGRect(x: 100, y: 100, width: 500, height: 400), on: display)
        )
        XCTAssertFalse(
            DisplayPlacement.isUsable(CGRect(x: 100, y: -20, width: 500, height: 400), on: display)
        )
        XCTAssertFalse(
            DisplayPlacement.isUsable(CGRect(x: -450, y: 100, width: 500, height: 400), on: display)
        )
    }

    private func display(
        uuid: String?,
        name: String,
        frame: CGRect,
        isMain: Bool = false,
        hardware: (UInt32, UInt32, UInt32)? = nil
    ) -> DisplaySnapshot {
        DisplaySnapshot(
            uuid: uuid,
            vendorID: hardware?.0,
            modelID: hardware?.1,
            serialNumber: hardware?.2,
            localizedName: name,
            visibleFrame: WindowFrame(rect: frame),
            isMain: isMain
        )
    }

    private func window(
        frame: CGRect,
        display: DisplaySnapshot? = nil,
        normalizedFrame: WindowFrame? = nil
    ) -> WindowSnapshot {
        WindowSnapshot(
            windowTitleSnapshot: "Window",
            frame: WindowFrame(rect: frame),
            isMinimized: false,
            isMainWindowCandidate: true,
            orderIndex: 0,
            stackingIndex: 0,
            display: display,
            normalizedFrame: normalizedFrame
        )
    }

    func testPanelFocusPolicyKeepsProtectedPresentationsVisible() {
        XCTAssertFalse(
            MenuBarPanelFocusPolicy.shouldClosePanel(hasProtectedPresentation: true)
        )
        XCTAssertTrue(
            MenuBarPanelFocusPolicy.shouldClosePanel(hasProtectedPresentation: false)
        )
    }

    func testGlobalClickPolicyIgnoresClicksInsideVisiblePanel() {
        let panelFrame = CGRect(x: 100, y: 200, width: 430, height: 620)

        XCTAssertFalse(
            MenuBarPanelFocusPolicy.shouldClosePanelForGlobalClick(
                panelFrame: panelFrame,
                isPanelVisible: true,
                clickLocation: CGPoint(x: 150, y: 250)
            )
        )
        XCTAssertTrue(
            MenuBarPanelFocusPolicy.shouldClosePanelForGlobalClick(
                panelFrame: panelFrame,
                isPanelVisible: true,
                clickLocation: CGPoint(x: 80, y: 250)
            )
        )
        XCTAssertFalse(
            MenuBarPanelFocusPolicy.shouldClosePanelForGlobalClick(
                panelFrame: panelFrame,
                isPanelVisible: false,
                clickLocation: CGPoint(x: 80, y: 250)
            )
        )
    }

    @MainActor
    func testSuggestedLayoutNameUsesVisibleAppNames() {
        XCTAssertEqual(
            LayoutCoordinator.suggestedLayoutName(for: ["Safari", "Notes"], fallback: "Fallback"),
            "Safari · Notes"
        )
        XCTAssertEqual(
            LayoutCoordinator.suggestedLayoutName(for: ["Safari", "Notes", "Finder", "Mail"], fallback: "Fallback"),
            "Safari · Notes +2"
        )
        XCTAssertEqual(
            LayoutCoordinator.suggestedLayoutName(for: ["Safari", " safari ", ""], fallback: "Fallback"),
            "Safari"
        )
        XCTAssertEqual(
            LayoutCoordinator.suggestedLayoutName(for: [], fallback: "Fallback"),
            "Fallback"
        )
    }

    @MainActor
    func testSnapshotPreviewStateIsSharedAndDismissible() {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsName = "SettleTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        let coordinator = LayoutCoordinator(
            store: LayoutStore(
                storageURL: rootURL.appendingPathComponent("layouts.json"),
                snapshotsDirectoryURL: rootURL.appendingPathComponent("Snapshots", isDirectory: true)
            ),
            settings: AppSettings(defaults: defaults, loginItemService: FakeLoginItemService(state: .notRegistered))
        )
        let layoutID = UUID()

        coordinator.setSnapshotPreview(layoutID, isPresented: true)
        XCTAssertTrue(coordinator.isSnapshotPreviewPresented)
        XCTAssertEqual(coordinator.previewedLayoutID, layoutID)

        coordinator.dismissSnapshotPreview()
        XCTAssertFalse(coordinator.isSnapshotPreviewPresented)
        XCTAssertNil(coordinator.previewedLayoutID)
        defaults.removePersistentDomain(forName: defaultsName)
    }

    func testAppGroupedRaiseOrderRestoresAppsAndTheirWindowsBackToFront() {
        let indices = WindowManager.appGroupedRaiseIndices(entries: [
            (stackingIndex: 0, processIdentifier: 10),
            (stackingIndex: 1, processIdentifier: 20),
            (stackingIndex: 2, processIdentifier: 10),
            (stackingIndex: 3, processIdentifier: 20)
        ])

        XCTAssertEqual(indices, [3, 1, 2, 0])
    }

    func testExactWindowMatchUsesCurrentVisibleWindowIdentity() {
        XCTAssertEqual(
            WindowManager.exactWindowMatchIndex(
                visibleWindowID: 42,
                candidateWindowIDs: [7, nil, 42, 99]
            ),
            2
        )
        XCTAssertNil(
            WindowManager.exactWindowMatchIndex(
                visibleWindowID: 8,
                candidateWindowIDs: [7, 42]
            )
        )
    }

    func testNewWindowShortcutRequiresEnabledCommandNWithoutExtraModifiers() {
        XCTAssertTrue(AppLauncher.isNewWindowShortcut(character: "N", modifiers: 0, enabled: true))
        XCTAssertFalse(AppLauncher.isNewWindowShortcut(character: "N", modifiers: 1, enabled: true))
        XCTAssertFalse(AppLauncher.isNewWindowShortcut(character: "T", modifiers: 0, enabled: true))
        XCTAssertFalse(AppLauncher.isNewWindowShortcut(character: "N", modifiers: 0, enabled: false))
    }

    func testBrowserRestoreStrategyRecognizesSafariAndChromeChannels() {
        XCTAssertEqual(AppLauncher.BrowserRestoreStrategy.forBundleIdentifier("com.apple.Safari"), .safari)
        XCTAssertEqual(AppLauncher.BrowserRestoreStrategy.forBundleIdentifier("com.google.Chrome"), .chrome)
        XCTAssertEqual(AppLauncher.BrowserRestoreStrategy.forBundleIdentifier("com.google.Chrome.beta"), .chrome)
        XCTAssertNil(AppLauncher.BrowserRestoreStrategy.forBundleIdentifier("com.apple.TextEdit"))
    }

    func testBrowserTabCaptureParsesSafariOutput() {
        let windows = BrowserTabManager.parseCapturedWindows(
            "1\thttps://example.com/one\n1\thttps://example.com/two\n2\thttps://openai.com/\n"
        )

        XCTAssertEqual(windows.count, 2)
        XCTAssertEqual(windows[0].tabs.map(\.url), ["https://example.com/one", "https://example.com/two"])
        XCTAssertEqual(windows[1].tabs.map(\.url), ["https://openai.com/"])
    }

    func testBrowserNewWindowMenuItemRequiresTheWindowCommand() {
        XCTAssertTrue(
            AppLauncher.isBrowserNewWindowMenuItem(
                title: "Nueva ventana",
                character: "n",
                modifiers: 0,
                enabled: true,
                strategy: .safari
            )
        )
        XCTAssertTrue(
            AppLauncher.isBrowserNewWindowMenuItem(
                title: "Neues Fenster",
                character: "N",
                modifiers: 0,
                enabled: true,
                strategy: .chrome
            )
        )
        XCTAssertFalse(
            AppLauncher.isBrowserNewWindowMenuItem(
                title: "New Tab",
                character: "N",
                modifiers: 0,
                enabled: true,
                strategy: .chrome
            )
        )
    }

    func testRestoreReportKeepsUniqueUnresolvedAppNames() {
        var report = RestoreReport()
        report.recordUnreconciledWindow("Safari - First", appName: "Safari")
        report.recordUnreconciledWindow("Safari - Second", appName: "Safari")
        report.recordUnreconciledWindow("Terminal - shell", appName: "Terminal")

        XCTAssertEqual(report.unreconciledWindows.count, 3)
        XCTAssertEqual(report.unreconciledApps, ["Safari", "Terminal"])
    }

    func testRestoreReportKeepsUniqueMissingAppNames() {
        var report = RestoreReport()
        report.recordMissingApp("Safari")
        report.recordMissingApp("Safari")
        report.recordMissingApp("Notes")

        XCTAssertEqual(report.missingApps, ["Safari", "Notes"])
    }

    func testRestoreReportCompletionRequiresNoIncidents() {
        var report = RestoreReport()
        XCTAssertTrue(report.completedSuccessfully)

        report.recordMissingApp("Safari")
        XCTAssertFalse(report.completedSuccessfully)

        report = RestoreReport()
        report.recordUnreconciledWindow("Notes - Draft", appName: "Notes")
        XCTAssertFalse(report.completedSuccessfully)

        report = RestoreReport(failures: [RestoreFailure(appName: "Safari", message: "Failed")])
        XCTAssertFalse(report.completedSuccessfully)
    }

    func testVisualWindowMatchRequiresOneUnambiguousCandidate() {
        let frame = CGRect(x: 10, y: 20, width: 800, height: 600)
        let matching = WindowCandidate(title: "Project", frame: frame, orderIndex: 0, isMainWindowCandidate: true)
        let other = WindowCandidate(
            title: "Other",
            frame: CGRect(x: 100, y: 200, width: 500, height: 400),
            orderIndex: 1,
            isMainWindowCandidate: false
        )

        XCTAssertEqual(
            WindowManager.unambiguousVisualMatchIndex(
                visibleTitle: "Project",
                visibleFrame: frame,
                candidates: [other, matching]
            ),
            1
        )
        XCTAssertNil(
            WindowManager.unambiguousVisualMatchIndex(
                visibleTitle: "Project",
                visibleFrame: frame,
                candidates: [matching, matching]
            )
        )
    }

    func testVisibleWindowMatchingExcludesCandidatesWithoutCurrentSpaceRecords() {
        let matched = WindowManager.consumeVisibleMatches(
            records: ["Current A", "Current B"],
            candidates: ["Other Space", "Current B", "Current A"]
        ) { record, candidates in
            candidates.firstIndex(of: record)
        }

        XCTAssertEqual(matched, ["Current A", "Current B"])
        XCTAssertFalse(matched.contains("Other Space"))
    }

    func testVisibleWindowMatchingDoesNotReuseOneCandidateTwice() {
        let matched = WindowManager.consumeVisibleMatches(
            records: ["Window", "Window"],
            candidates: ["Window"]
        ) { record, candidates in
            candidates.firstIndex(of: record)
        }

        XCTAssertEqual(matched, ["Window"])
    }

    @MainActor
    func testLayoutStorePersistsAndDeletesSnapshotFile() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storageURL = rootURL.appendingPathComponent("layouts.json")
        let snapshotsURL = rootURL.appendingPathComponent("Snapshots", isDirectory: true)
        let store = LayoutStore(storageURL: storageURL, snapshotsDirectoryURL: snapshotsURL)
        let layout = Layout(
            name: "Snapshot",
            apps: [
                AppLayoutSnapshot(
                    bundleIdentifier: "com.apple.TextEdit",
                    appDisplayName: "TextEdit",
                    windows: [
                        WindowSnapshot(
                            windowTitleSnapshot: "Notes",
                            frame: WindowFrame(rect: CGRect(x: 10, y: 10, width: 300, height: 200)),
                            isMinimized: false,
                            isMainWindowCandidate: true,
                            orderIndex: 0,
                            stackingIndex: 1
                        )
                    ]
                )
            ]
        )
        let pngData = Data([0x89, 0x50, 0x4E, 0x47])

        try store.save(layout, snapshotPNGData: pngData)

        let persisted = try XCTUnwrap(store.listLayouts().first)
        let snapshotURL = try XCTUnwrap(store.snapshotURL(for: persisted))
        XCTAssertEqual(try Data(contentsOf: snapshotURL), pngData)

        try store.deleteLayout(id: persisted.id)

        XCTAssertFalse(FileManager.default.fileExists(atPath: snapshotURL.path))
    }

    @MainActor
    func testLayoutStoreReplacesSnapshotWithFreshFileNameOnOverwrite() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storageURL = rootURL.appendingPathComponent("layouts.json")
        let snapshotsURL = rootURL.appendingPathComponent("Snapshots", isDirectory: true)
        let store = LayoutStore(storageURL: storageURL, snapshotsDirectoryURL: snapshotsURL)
        let layout = Layout(
            name: "Snapshot",
            apps: [
                AppLayoutSnapshot(
                    bundleIdentifier: "com.apple.TextEdit",
                    appDisplayName: "TextEdit",
                    windows: [
                        WindowSnapshot(
                            windowTitleSnapshot: "Notes",
                            frame: WindowFrame(rect: CGRect(x: 10, y: 10, width: 300, height: 200)),
                            isMinimized: false,
                            isMainWindowCandidate: true,
                            orderIndex: 0,
                            stackingIndex: 1
                        )
                    ]
                )
            ]
        )

        try store.save(layout, snapshotPNGData: Data([0x01]))
        let firstPersisted = try XCTUnwrap(store.listLayouts().first)
        let firstSnapshotURL = try XCTUnwrap(store.snapshotURL(for: firstPersisted))

        var updatedLayout = firstPersisted
        updatedLayout.updatedAt = .now
        try store.save(updatedLayout, snapshotPNGData: Data([0x02]))

        let secondPersisted = try XCTUnwrap(store.listLayouts().first)
        let secondSnapshotURL = try XCTUnwrap(store.snapshotURL(for: secondPersisted))

        XCTAssertNotEqual(firstPersisted.snapshotFileName, secondPersisted.snapshotFileName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstSnapshotURL.path))
        XCTAssertEqual(try Data(contentsOf: secondSnapshotURL), Data([0x02]))
    }

    @MainActor
    func testPinnedLayoutsPersistManualOrder() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storageURL = rootURL.appendingPathComponent("layouts.json")
        let snapshotsURL = rootURL.appendingPathComponent("Snapshots", isDirectory: true)
        let store = LayoutStore(storageURL: storageURL, snapshotsDirectoryURL: snapshotsURL)

        let alpha = Layout(name: "Alpha", pinned: true, apps: [])
        let beta = Layout(name: "Beta", pinned: true, apps: [])
        let gamma = Layout(name: "Gamma", apps: [])

        try store.save(alpha)
        try store.save(beta)
        try store.save(gamma)
        try store.movePinnedLayout(from: 1, to: 0)

        let pinnedNames = store.listLayouts().filter(\.pinned).map(\.name)
        XCTAssertEqual(pinnedNames, ["Beta", "Alpha"])

        let reloadedStore = LayoutStore(storageURL: storageURL, snapshotsDirectoryURL: snapshotsURL)
        let reloadedPinnedNames = reloadedStore.listLayouts().filter(\.pinned).map(\.name)
        XCTAssertEqual(reloadedPinnedNames, ["Beta", "Alpha"])
        XCTAssertEqual(reloadedStore.listLayouts().first?.pinnedOrder, 0)
    }

    func testWindowMatcherPrefersExactTitleAndGeometry() {
        let target = WindowSnapshot(
            windowTitleSnapshot: "Project",
            frame: WindowFrame(rect: CGRect(x: 100, y: 100, width: 800, height: 600)),
            isMinimized: false,
            isMainWindowCandidate: true,
            orderIndex: 0,
            stackingIndex: 0
        )

        let candidates = [
            WindowCandidate(title: "Other", frame: CGRect(x: 90, y: 90, width: 800, height: 600), orderIndex: 0, isMainWindowCandidate: true),
            WindowCandidate(title: "Project", frame: CGRect(x: 100, y: 100, width: 800, height: 600), orderIndex: 0, isMainWindowCandidate: true)
        ]

        XCTAssertEqual(WindowMatcher.bestMatch(target: target, candidates: candidates), 1)
    }

    func testWindowMatcherUsesResolvedFrameAfterDisplayRearrangement() {
        let target = WindowSnapshot(
            windowTitleSnapshot: "",
            frame: WindowFrame(rect: CGRect(x: 5000, y: 100, width: 800, height: 600)),
            isMinimized: false,
            isMainWindowCandidate: true,
            orderIndex: 0,
            stackingIndex: 0
        )
        let resolvedFrame = CGRect(x: -1200, y: 100, width: 800, height: 600)
        let candidates = [
            WindowCandidate(
                title: "",
                frame: resolvedFrame,
                orderIndex: 0,
                isMainWindowCandidate: true
            )
        ]

        XCTAssertEqual(
            WindowMatcher.bestMatch(
                target: target,
                candidates: candidates,
                referenceFrame: resolvedFrame
            ),
            0
        )
    }

    func testWindowMatcherAcceptsUniqueExactTitleDespiteObsoleteGeometry() {
        let target = WindowSnapshot(
            windowTitleSnapshot: "Project",
            frame: WindowFrame(rect: CGRect(x: 5000, y: 100, width: 800, height: 600)),
            isMinimized: false,
            isMainWindowCandidate: true,
            orderIndex: 0,
            stackingIndex: 0
        )
        let candidates = [
            WindowCandidate(
                title: "Project",
                frame: CGRect(x: -1200, y: 100, width: 800, height: 600),
                orderIndex: 0,
                isMainWindowCandidate: true
            )
        ]

        XCTAssertEqual(WindowMatcher.bestMatch(target: target, candidates: candidates), 0)
    }

    func testLayoutDocumentRoundTrip() throws {
        let capturedDisplay = display(
            uuid: "display-uuid",
            name: "Studio Display",
            frame: CGRect(x: 0, y: 25, width: 1440, height: 875),
            isMain: true,
            hardware: (1, 2, 3)
        )
        let layout = Layout(name: "Work", apps: [
            AppLayoutSnapshot(bundleIdentifier: "com.apple.TextEdit", appDisplayName: "TextEdit", windows: [
                WindowSnapshot(
                    windowTitleSnapshot: "Notes",
                    frame: WindowFrame(rect: CGRect(x: 10, y: 10, width: 300, height: 200)),
                    isMinimized: false,
                    isMainWindowCandidate: true,
                    orderIndex: 0,
                    stackingIndex: 0,
                    screenHint: capturedDisplay.localizedName,
                    display: capturedDisplay,
                    normalizedFrame: WindowFrame(
                        rect: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
                    )
                )
            ])
        ])

        let document = LayoutDocument(version: LayoutDocument.currentVersion, layouts: [layout])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(document)
        let decoded = try decoder.decode(LayoutDocument.self, from: data)

        XCTAssertEqual(decoded.layouts.first?.name, "Work")
        XCTAssertEqual(decoded.layouts.first?.apps.first?.windows.first?.windowTitleSnapshot, "Notes")
        XCTAssertEqual(decoded.layouts.first?.apps.first?.windows.first?.stackingIndex, 0)
        XCTAssertEqual(decoded.layouts.first?.apps.first?.windows.first?.display, capturedDisplay)
        XCTAssertEqual(
            decoded.layouts.first?.apps.first?.windows.first?.normalizedFrame,
            WindowFrame(rect: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4))
        )
        XCTAssertFalse(decoded.layouts.first?.restoresBrowserTabs ?? true)
    }

    func testLegacyWindowSnapshotDecodesWithoutStackingIndex() throws {
        let json = """
        {
          "version": 1,
          "layouts": [
            {
              "id": "C8B0ED5A-22E6-4EFA-BF54-F6B620E2B9DF",
              "name": "Legacy",
              "createdAt": "2026-06-15T20:00:00Z",
              "updatedAt": "2026-06-15T20:00:00Z",
              "pinned": false,
              "spacePolicy": "currentSpaceOnly",
              "extraWindowsBehaviorDefault": "leaveUntouched",
              "apps": [
                {
                  "id": "64338CF7-22B3-418F-8FF4-2817D708FD22",
                  "bundleIdentifier": "com.apple.TextEdit",
                  "appDisplayName": "TextEdit",
                  "windows": [
                    {
                      "id": "47FEFF67-8F3C-4B38-9054-77C1A615C4E9",
                      "windowTitleSnapshot": "Notes",
                      "frame": { "x": 10, "y": 10, "width": 300, "height": 200 },
                      "isMinimized": false,
                      "isMainWindowCandidate": true,
                      "orderIndex": 3
                    }
                  ]
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(LayoutDocument.self, from: json)
        XCTAssertEqual(decoded.layouts.first?.apps.first?.windows.first?.orderIndex, 3)
        XCTAssertEqual(decoded.layouts.first?.apps.first?.windows.first?.stackingIndex, 3)
        XCTAssertNil(decoded.layouts.first?.apps.first?.windows.first?.display)
        XCTAssertNil(decoded.layouts.first?.apps.first?.windows.first?.normalizedFrame)
        XCTAssertFalse(decoded.layouts.first?.restoresBrowserTabs ?? true)
    }

    func testLayoutCanPersistSnapshotReference() throws {
        let layout = Layout(
            name: "Snapshot",
            snapshotFileName: "abc123.png",
            apps: [
                AppLayoutSnapshot(
                    bundleIdentifier: "com.apple.TextEdit",
                    appDisplayName: "TextEdit",
                    windows: [
                        WindowSnapshot(
                            windowTitleSnapshot: "Notes",
                            frame: WindowFrame(rect: CGRect(x: 10, y: 10, width: 300, height: 200)),
                            isMinimized: false,
                            isMainWindowCandidate: true,
                            orderIndex: 0,
                            stackingIndex: 2
                        )
                    ]
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(LayoutDocument(version: LayoutDocument.currentVersion, layouts: [layout]))
        let decoded = try decoder.decode(LayoutDocument.self, from: data)

        XCTAssertEqual(decoded.layouts.first?.snapshotFileName, "abc123.png")
        XCTAssertEqual(decoded.layouts.first?.apps.first?.windows.first?.stackingIndex, 2)
    }

    func testRaiseOrderUsesBackToFrontSequence() {
        let front = WindowSnapshot(
            windowTitleSnapshot: "Front",
            frame: WindowFrame(rect: CGRect(x: 0, y: 0, width: 100, height: 100)),
            isMinimized: false,
            isMainWindowCandidate: true,
            orderIndex: 0,
            stackingIndex: 0
        )
        let middle = WindowSnapshot(
            windowTitleSnapshot: "Middle",
            frame: WindowFrame(rect: CGRect(x: 10, y: 10, width: 100, height: 100)),
            isMinimized: false,
            isMainWindowCandidate: false,
            orderIndex: 1,
            stackingIndex: 1
        )
        let back = WindowSnapshot(
            windowTitleSnapshot: "Back",
            frame: WindowFrame(rect: CGRect(x: 20, y: 20, width: 100, height: 100)),
            isMinimized: false,
            isMainWindowCandidate: false,
            orderIndex: 2,
            stackingIndex: 2
        )

        let orderedTitles = WindowManager
            .matchesInRaiseOrder([
                (front, AXUIElementCreateApplication(1)),
                (back, AXUIElementCreateApplication(2)),
                (middle, AXUIElementCreateApplication(3))
            ])
            .map(\.0.windowTitleSnapshot)

        XCTAssertEqual(orderedTitles, ["Back", "Middle", "Front"])
    }

    func testSnapshotBoundsFitsVisibleLayoutWindows() {
        let layout = Layout(
            name: "Preview",
            apps: [
                AppLayoutSnapshot(
                    bundleIdentifier: "com.apple.Safari",
                    appDisplayName: "Safari",
                    windows: [
                        WindowSnapshot(
                            windowTitleSnapshot: "Main",
                            frame: WindowFrame(rect: CGRect(x: 100, y: 80, width: 900, height: 700)),
                            isMinimized: false,
                            isMainWindowCandidate: true,
                            orderIndex: 0,
                            stackingIndex: 0
                        ),
                        WindowSnapshot(
                            windowTitleSnapshot: "Inspector",
                            frame: WindowFrame(rect: CGRect(x: 1040, y: 140, width: 320, height: 500)),
                            isMinimized: false,
                            isMainWindowCandidate: false,
                            orderIndex: 1,
                            stackingIndex: 1
                        )
                    ]
                )
            ]
        )

        let bounds = WindowManager.snapshotBounds(for: layout, padding: 20)

        XCTAssertEqual(bounds, CGRect(x: 80, y: 60, width: 1300, height: 740))
    }

    func testLayoutVisibilityMatcherFindsRestoredLayoutForMatchingDesktop() {
        let restored = Layout(
            name: "Work",
            apps: [
                AppLayoutSnapshot(
                    bundleIdentifier: "com.apple.Safari",
                    appDisplayName: "Safari",
                    windows: [
                        WindowSnapshot(
                            windowTitleSnapshot: "Docs",
                            frame: WindowFrame(rect: CGRect(x: 40, y: 60, width: 900, height: 700)),
                            isMinimized: false,
                            isMainWindowCandidate: true,
                            orderIndex: 0,
                            stackingIndex: 0
                        )
                    ]
                ),
                AppLayoutSnapshot(
                    bundleIdentifier: "com.apple.dt.Xcode",
                    appDisplayName: "Xcode",
                    windows: [
                        WindowSnapshot(
                            windowTitleSnapshot: "Settle",
                            frame: WindowFrame(rect: CGRect(x: 960, y: 70, width: 820, height: 980)),
                            isMinimized: false,
                            isMainWindowCandidate: true,
                            orderIndex: 0,
                            stackingIndex: 1
                        )
                    ]
                )
            ]
        )

        let currentApps = [
            AppLayoutSnapshot(
                bundleIdentifier: "com.apple.Safari",
                appDisplayName: "Safari",
                windows: [
                    WindowSnapshot(
                        windowTitleSnapshot: "Docs",
                        frame: WindowFrame(rect: CGRect(x: 44, y: 63, width: 896, height: 696)),
                        isMinimized: false,
                        isMainWindowCandidate: true,
                        orderIndex: 0,
                        stackingIndex: 0
                    )
                ]
            ),
            AppLayoutSnapshot(
                bundleIdentifier: "com.apple.dt.Xcode",
                appDisplayName: "Xcode",
                windows: [
                    WindowSnapshot(
                        windowTitleSnapshot: "Settle",
                        frame: WindowFrame(rect: CGRect(x: 958, y: 72, width: 824, height: 975)),
                        isMinimized: false,
                        isMainWindowCandidate: true,
                        orderIndex: 0,
                        stackingIndex: 1
                    )
                ]
            )
        ]

        let match = LayoutVisibilityMatcher.bestMatch(currentApps: currentApps, among: [restored])
        XCTAssertEqual(match?.id, restored.id)
    }

    func testLayoutVisibilityMatcherRejectsWeakDesktopOverlap() {
        let restored = Layout(
            name: "Work",
            apps: [
                AppLayoutSnapshot(
                    bundleIdentifier: "com.apple.Safari",
                    appDisplayName: "Safari",
                    windows: [
                        WindowSnapshot(
                            windowTitleSnapshot: "Docs",
                            frame: WindowFrame(rect: CGRect(x: 40, y: 60, width: 900, height: 700)),
                            isMinimized: false,
                            isMainWindowCandidate: true,
                            orderIndex: 0,
                            stackingIndex: 0
                        )
                    ]
                )
            ]
        )

        let currentApps = [
            AppLayoutSnapshot(
                bundleIdentifier: "com.apple.Terminal",
                appDisplayName: "Terminal",
                windows: [
                    WindowSnapshot(
                        windowTitleSnapshot: "shell",
                        frame: WindowFrame(rect: CGRect(x: 300, y: 180, width: 1000, height: 700)),
                        isMinimized: false,
                        isMainWindowCandidate: true,
                        orderIndex: 0,
                        stackingIndex: 0
                    )
                ]
            )
        ]

        XCTAssertNil(LayoutVisibilityMatcher.bestMatch(currentApps: currentApps, among: [restored]))
    }

    func testCompleteLayoutMatchRejectsMissingSavedWindow() {
        let savedWindows = [
            WindowSnapshot(
                windowTitleSnapshot: "A",
                frame: WindowFrame(rect: CGRect(x: 40, y: 60, width: 800, height: 600)),
                isMinimized: false,
                isMainWindowCandidate: true,
                orderIndex: 0,
                stackingIndex: 0
            ),
            WindowSnapshot(
                windowTitleSnapshot: "B",
                frame: WindowFrame(rect: CGRect(x: 880, y: 60, width: 800, height: 600)),
                isMinimized: false,
                isMainWindowCandidate: false,
                orderIndex: 1,
                stackingIndex: 1
            )
        ]
        let layout = Layout(
            name: "Two Windows",
            apps: [
                AppLayoutSnapshot(
                    bundleIdentifier: "com.example.Editor",
                    appDisplayName: "Editor",
                    windows: savedWindows
                )
            ]
        )
        let currentApps = [
            AppLayoutSnapshot(
                bundleIdentifier: "com.example.Editor",
                appDisplayName: "Editor",
                windows: [savedWindows[1]]
            )
        ]

        XCTAssertFalse(LayoutVisibilityMatcher.isCompleteMatch(currentApps: currentApps, against: layout))
        XCTAssertNil(LayoutVisibilityMatcher.bestCompleteMatch(currentApps: currentApps, among: [layout]))
    }

    func testCompleteLayoutMatchAllowsUnrelatedVisibleWindows() {
        let expectedApp = AppLayoutSnapshot(
            bundleIdentifier: "com.example.Editor",
            appDisplayName: "Editor",
            windows: [
                WindowSnapshot(
                    windowTitleSnapshot: "Project",
                    frame: WindowFrame(rect: CGRect(x: 40, y: 60, width: 800, height: 600)),
                    isMinimized: false,
                    isMainWindowCandidate: true,
                    orderIndex: 0,
                    stackingIndex: 0
                )
            ]
        )
        let layout = Layout(name: "Work", apps: [expectedApp])
        let unrelatedApp = AppLayoutSnapshot(
            bundleIdentifier: "com.example.Chat",
            appDisplayName: "Chat",
            windows: [
                WindowSnapshot(
                    windowTitleSnapshot: "Messages",
                    frame: WindowFrame(rect: CGRect(x: 900, y: 80, width: 600, height: 500)),
                    isMinimized: false,
                    isMainWindowCandidate: true,
                    orderIndex: 0,
                    stackingIndex: 1
                )
            ]
        )

        XCTAssertTrue(
            LayoutVisibilityMatcher.isCompleteMatch(
                currentApps: [expectedApp, unrelatedApp],
                against: layout
            )
        )
    }

    func testLayoutNavigationMemoryKeepsMostRecentTargets() {
        let layoutID = UUID()
        var memory = LayoutNavigationMemory<String>()

        XCTAssertTrue(memory.rememberedLayoutIDs.isEmpty)
        memory.remember(layoutID: layoutID, targets: ["Space 1 window"])
        memory.remember(layoutID: layoutID, targets: ["Space 2 window"])

        XCTAssertTrue(memory.contains(layoutID: layoutID))
        XCTAssertEqual(memory.targetGroups(for: layoutID), [["Space 1 window"], ["Space 2 window"]])
        XCTAssertEqual(memory.targets(for: layoutID), ["Space 2 window"])

        memory.remember(layoutID: layoutID, targets: ["Space 1 window"])
        XCTAssertEqual(memory.targets(for: layoutID), ["Space 1 window"])

        memory.forget(layoutID: layoutID, targetGroup: ["Space 1 window"])
        XCTAssertEqual(memory.targets(for: layoutID), ["Space 2 window"])
    }

    func testLayoutNavigationMemoryInvalidatesRemovedLayouts() {
        let retainedLayoutID = UUID()
        let removedLayoutID = UUID()
        var memory = LayoutNavigationMemory<Int>()
        memory.remember(layoutID: retainedLayoutID, targets: [1])
        memory.remember(layoutID: removedLayoutID, targets: [2])

        memory.retainLayouts(withIDs: [retainedLayoutID])

        XCTAssertEqual(memory.rememberedLayoutIDs, [retainedLayoutID])
        XCTAssertFalse(memory.contains(layoutID: removedLayoutID))

        memory.removeAll()
        XCTAssertTrue(memory.rememberedLayoutIDs.isEmpty)
    }

    func testLayoutSwitcherSelectionCyclesAndWraps() {
        XCTAssertEqual(
            LayoutSwitcherSelection.nextIndex(from: 0, count: 3, direction: .forward),
            1
        )
        XCTAssertEqual(
            LayoutSwitcherSelection.nextIndex(from: 2, count: 3, direction: .forward),
            0
        )
        XCTAssertEqual(
            LayoutSwitcherSelection.nextIndex(from: 0, count: 3, direction: .backward),
            2
        )
        XCTAssertEqual(
            LayoutSwitcherSelection.nextIndex(from: nil, count: 3, direction: .backward),
            2
        )
        XCTAssertNil(
            LayoutSwitcherSelection.nextIndex(from: nil, count: 0, direction: .forward)
        )
    }

    func testLayoutSwitcherActiveOrderIncludesCurrentLayoutWithoutNavigationTarget() {
        let currentID = UUID()

        XCTAssertEqual(
            LayoutSwitcherActiveOrder.orderedIDs(
                recentlyActiveIDs: [],
                rememberedIDs: [],
                currentID: currentID,
                availableIDs: [currentID]
            ),
            [currentID]
        )
    }

    func testLayoutSwitcherActiveOrderKeepsCurrentLayoutFirst() {
        let currentID = UUID()
        let otherID = UUID()

        XCTAssertEqual(
            LayoutSwitcherActiveOrder.orderedIDs(
                recentlyActiveIDs: [otherID],
                rememberedIDs: [otherID],
                currentID: currentID,
                availableIDs: [currentID, otherID]
            ),
            [currentID, otherID]
        )
    }

    func testLayoutSwitcherPresentationInvalidatesPendingDismissalWhenShownAgain() {
        var state = LayoutSwitcherPresentationState()

        state.beginPresentation()
        let dismissalGeneration = state.beginDismissal()
        XCTAssertTrue(state.shouldCompleteDismissal(dismissalGeneration))

        state.beginPresentation()
        XCTAssertFalse(state.shouldCompleteDismissal(dismissalGeneration))
    }

    @MainActor
    func testLayoutSwitcherPanelFollowsActiveSpace() {
        let behavior = LayoutSwitcherController.panelCollectionBehavior

        XCTAssertTrue(behavior.contains(.moveToActiveSpace))
        XCTAssertTrue(behavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(behavior.contains(.ignoresCycle))
        XCTAssertFalse(behavior.contains(.canJoinAllSpaces))
        XCTAssertFalse(behavior.contains(.stationary))
    }

    @MainActor
    func testLayoutSwitcherRemainsVisibleWhenShownDuringDismissal() async {
        let controller = LayoutSwitcherController()
        let item = LayoutSwitcherItem(id: UUID(), name: "Layout", snapshotURL: nil)

        controller.show(
            items: [item],
            selectedID: item.id,
            shortcut: .defaultShortcut,
            actionShortcuts: .defaultShortcuts
        )
        controller.dismiss()
        controller.show(
            items: [item],
            selectedID: item.id,
            shortcut: .defaultShortcut,
            actionShortcuts: .defaultShortcuts
        )

        try? await Task.sleep(for: .milliseconds(180))
        XCTAssertTrue(controller.isVisible)

        controller.dismiss()
        try? await Task.sleep(for: .milliseconds(120))
    }

    func testDefaultLayoutSwitcherShortcutUsesOptionTab() {
        XCTAssertEqual(LayoutSwitcherShortcut.defaultShortcut.modifier, .option)
        XCTAssertEqual(LayoutSwitcherShortcut.defaultShortcut.keyCode, 48)
        XCTAssertEqual(LayoutSwitcherShortcut.defaultShortcut.displayString, "⌥Tab")
    }

    func testDefaultLayoutSwitcherActionShortcutsUseCAndKAndM() {
        let shortcuts = LayoutSwitcherActionShortcuts.defaultShortcuts

        XCTAssertEqual(shortcuts.closeActiveLayout.keyCode, 8)
        XCTAssertEqual(shortcuts.closeOtherWindows.keyCode, 40)
        XCTAssertEqual(shortcuts.minimizeOtherWindows.keyCode, 46)
        XCTAssertEqual(
            shortcuts.closeActiveLayout.displayString(with: .defaultShortcut),
            "⌥Tab+C"
        )
        XCTAssertTrue(shortcuts.isValid(primaryKeyCode: LayoutSwitcherShortcut.defaultShortcut.keyCode))
    }

    func testLayoutSwitcherActionShortcutValidationRejectsConflictingKeys() {
        var shortcuts = LayoutSwitcherActionShortcuts.defaultShortcuts
        shortcuts.closeOtherWindows = shortcuts.closeActiveLayout
        XCTAssertFalse(shortcuts.isValid(primaryKeyCode: LayoutSwitcherShortcut.defaultShortcut.keyCode))

        shortcuts = .defaultShortcuts
        shortcuts.closeActiveLayout = LayoutSwitcherActionShortcut(keyCode: 48, keyLabel: "Tab")
        XCTAssertFalse(shortcuts.isValid(primaryKeyCode: LayoutSwitcherShortcut.defaultShortcut.keyCode))
    }

    @MainActor
    func testLayoutSwitcherHotKeyRejectsDuplicateGlobalRegistration() throws {
        let shortcut = LayoutSwitcherShortcut(
            modifier: .control,
            keyCode: 80,
            keyLabel: "F19"
        )
        let firstManager = LayoutSwitcherHotKeyManager()
        let secondManager = LayoutSwitcherHotKeyManager()
        defer {
            firstManager.stop()
            secondManager.stop()
        }

        try firstManager.start(shortcut: shortcut) { _ in }
        XCTAssertThrowsError(try secondManager.start(shortcut: shortcut) { _ in })
    }

    func testUnmatchedVisibleWindowIndicesDetectExtraAppWindows() {
        let layout = Layout(
            name: "Work",
            apps: [
                AppLayoutSnapshot(
                    bundleIdentifier: "com.apple.dt.Xcode",
                    appDisplayName: "Xcode",
                    windows: [
                        WindowSnapshot(
                            windowTitleSnapshot: "Project",
                            frame: WindowFrame(rect: CGRect(x: 40, y: 40, width: 900, height: 700)),
                            isMinimized: false,
                            isMainWindowCandidate: true,
                            orderIndex: 0,
                            stackingIndex: 0
                        )
                    ]
                )
            ]
        )

        let currentApps = [
            AppLayoutSnapshot(
                bundleIdentifier: "com.apple.dt.Xcode",
                appDisplayName: "Xcode",
                windows: [
                    WindowSnapshot(
                        windowTitleSnapshot: "Project",
                        frame: WindowFrame(rect: CGRect(x: 40, y: 40, width: 900, height: 700)),
                        isMinimized: false,
                        isMainWindowCandidate: true,
                        orderIndex: 0,
                        stackingIndex: 0
                    ),
                    WindowSnapshot(
                        windowTitleSnapshot: "Welcome",
                        frame: WindowFrame(rect: CGRect(x: 980, y: 120, width: 500, height: 420)),
                        isMinimized: false,
                        isMainWindowCandidate: false,
                        orderIndex: 1,
                        stackingIndex: 1
                    )
                ]
            ),
            AppLayoutSnapshot(
                bundleIdentifier: "com.googlecode.iterm2",
                appDisplayName: "iTerm2",
                windows: [
                    WindowSnapshot(
                        windowTitleSnapshot: "shell",
                        frame: WindowFrame(rect: CGRect(x: 120, y: 120, width: 800, height: 500)),
                        isMinimized: false,
                        isMainWindowCandidate: true,
                        orderIndex: 0,
                        stackingIndex: 2
                    )
                ]
            )
        ]

        let unmatched = LayoutVisibilityMatcher.unmatchedVisibleWindowOrderIndices(
            currentApps: currentApps,
            against: layout
        )

        XCTAssertEqual(unmatched["com.apple.dt.Xcode"], [1])
        XCTAssertEqual(unmatched["com.googlecode.iterm2"], [0])
    }

    func testUnmatchedVisibleWindowIndicesReturnsEmptyWhenVisibleWindowsMatchLayout() {
        let currentApps = [
            AppLayoutSnapshot(
                bundleIdentifier: "com.apple.Safari",
                appDisplayName: "Safari",
                windows: [
                    WindowSnapshot(
                        windowTitleSnapshot: "Docs",
                        frame: WindowFrame(rect: CGRect(x: 100, y: 90, width: 1000, height: 760)),
                        isMinimized: false,
                        isMainWindowCandidate: true,
                        orderIndex: 0,
                        stackingIndex: 0
                    ),
                    WindowSnapshot(
                        windowTitleSnapshot: "Mail",
                        frame: WindowFrame(rect: CGRect(x: 1120, y: 110, width: 780, height: 700)),
                        isMinimized: false,
                        isMainWindowCandidate: false,
                        orderIndex: 1,
                        stackingIndex: 1
                    )
                ]
            )
        ]
        let layout = Layout(name: "Browsing", apps: currentApps)

        let unmatched = LayoutVisibilityMatcher.unmatchedVisibleWindowOrderIndices(
            currentApps: currentApps,
            against: layout
        )

        XCTAssertTrue(unmatched.isEmpty)
    }

    @MainActor
    func testAppSettingsPersistsDefaultLayoutSelection() throws {
        let suiteName = "SettleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let layoutID = UUID()

        let settings = AppSettings(
            defaults: defaults,
            loginItemService: FakeLoginItemService(state: .notRegistered)
        )
        settings.setDefaultLayoutID(layoutID)

        let reloadedSettings = AppSettings(
            defaults: defaults,
            loginItemService: FakeLoginItemService(state: .notRegistered)
        )
        XCTAssertEqual(reloadedSettings.defaultLayoutID, layoutID)
    }

    @MainActor
    func testAppSettingsPersistsAndDisablesLayoutSwitcherShortcut() throws {
        let suiteName = "SettleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let customShortcut = LayoutSwitcherShortcut(
            modifier: .control,
            keyCode: 49,
            keyLabel: "Space"
        )

        let settings = AppSettings(
            defaults: defaults,
            loginItemService: FakeLoginItemService(state: .notRegistered)
        )
        XCTAssertEqual(settings.layoutSwitcherShortcut, .defaultShortcut)

        settings.setLayoutSwitcherShortcut(customShortcut)
        let reloadedCustomSettings = AppSettings(
            defaults: defaults,
            loginItemService: FakeLoginItemService(state: .notRegistered)
        )
        XCTAssertEqual(reloadedCustomSettings.layoutSwitcherShortcut, customShortcut)

        reloadedCustomSettings.setLayoutSwitcherShortcut(nil)
        let reloadedDisabledSettings = AppSettings(
            defaults: defaults,
            loginItemService: FakeLoginItemService(state: .notRegistered)
        )
        XCTAssertNil(reloadedDisabledSettings.layoutSwitcherShortcut)

        reloadedDisabledSettings.resetLayoutSwitcherShortcut()
        XCTAssertEqual(reloadedDisabledSettings.layoutSwitcherShortcut, .defaultShortcut)
    }

    @MainActor
    func testAppSettingsPersistsLayoutSwitcherActionShortcuts() throws {
        let suiteName = "SettleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var customShortcuts = LayoutSwitcherActionShortcuts.defaultShortcuts
        customShortcuts.closeActiveLayout = LayoutSwitcherActionShortcut(keyCode: 38, keyLabel: "J")

        let settings = AppSettings(
            defaults: defaults,
            loginItemService: FakeLoginItemService(state: .notRegistered)
        )
        XCTAssertEqual(settings.layoutSwitcherActionShortcuts, .defaultShortcuts)

        settings.setLayoutSwitcherActionShortcuts(customShortcuts)
        let reloadedSettings = AppSettings(
            defaults: defaults,
            loginItemService: FakeLoginItemService(state: .notRegistered)
        )
        XCTAssertEqual(reloadedSettings.layoutSwitcherActionShortcuts, customShortcuts)

        reloadedSettings.resetLayoutSwitcherActionShortcuts()
        XCTAssertEqual(reloadedSettings.layoutSwitcherActionShortcuts, .defaultShortcuts)
    }

    @MainActor
    func testAppSettingsPersistsAutomaticExtraWindowsBehavior() throws {
        let suiteName = "SettleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(
            defaults: defaults,
            loginItemService: FakeLoginItemService(state: .notRegistered)
        )
        XCTAssertEqual(settings.automaticExtraWindowsBehavior, .leaveUntouched)

        settings.setAutomaticExtraWindowsBehavior(.minimize)
        let reloadedMinimizeSettings = AppSettings(
            defaults: defaults,
            loginItemService: FakeLoginItemService(state: .notRegistered)
        )
        XCTAssertEqual(reloadedMinimizeSettings.automaticExtraWindowsBehavior, .minimize)

        reloadedMinimizeSettings.setAutomaticExtraWindowsBehavior(.close)
        let reloadedCloseSettings = AppSettings(
            defaults: defaults,
            loginItemService: FakeLoginItemService(state: .notRegistered)
        )
        XCTAssertEqual(reloadedCloseSettings.automaticExtraWindowsBehavior, .close)
    }

    @MainActor
    func testAppSettingsClearsMissingDefaultLayout() throws {
        let suiteName = "SettleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(
            defaults: defaults,
            loginItemService: FakeLoginItemService(state: .notRegistered)
        )

        settings.setDefaultLayoutID(UUID())
        settings.reconcileDefaultLayout(availableLayoutIDs: [])

        XCTAssertNil(settings.defaultLayoutID)
        XCTAssertNil(defaults.string(forKey: "defaultLayoutID"))
    }

    @MainActor
    func testAppSettingsSynchronizesLaunchAtLoginState() throws {
        let suiteName = "SettleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let loginItemService = FakeLoginItemService(state: .notRegistered)
        let settings = AppSettings(defaults: defaults, loginItemService: loginItemService)

        settings.setLaunchAtLoginEnabled(true)
        XCTAssertEqual(loginItemService.registerCallCount, 1)
        XCTAssertEqual(settings.launchAtLoginState, .enabled)
        XCTAssertTrue(settings.isLaunchAtLoginRequested)

        settings.setLaunchAtLoginEnabled(false)
        XCTAssertEqual(loginItemService.unregisterCallCount, 1)
        XCTAssertEqual(settings.launchAtLoginState, .notRegistered)
        XCTAssertFalse(settings.isLaunchAtLoginRequested)
    }

    @MainActor
    func testAppSettingsTreatsPendingLoginItemApprovalAsRequested() throws {
        let suiteName = "SettleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let loginItemService = FakeLoginItemService(state: .requiresApproval)
        let settings = AppSettings(defaults: defaults, loginItemService: loginItemService)

        XCTAssertTrue(settings.isLaunchAtLoginRequested)

        settings.setLaunchAtLoginEnabled(true)
        XCTAssertEqual(loginItemService.registerCallCount, 0)
        XCTAssertEqual(settings.launchAtLoginState, .requiresApproval)
    }

    func testLoginRestoreSignalSuppressesImmediateRegistrationLaunchOnce() throws {
        let suiteName = "SettleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let signal = LoginRestoreSignal(defaults: defaults)
        let registeredAt = Date(timeIntervalSince1970: 1_000)

        signal.prepareForRegistration(at: registeredAt)

        XCTAssertTrue(
            signal.consumeRegistrationSuppression(at: registeredAt.addingTimeInterval(10))
        )
        XCTAssertFalse(
            signal.consumeRegistrationSuppression(at: registeredAt.addingTimeInterval(10))
        )
        XCTAssertFalse(signal.consumeLoginRestoreRequest())
    }

    func testLoginRestoreSignalDoesNotSuppressLoginAfterRegistrationApprovalDelay() throws {
        let suiteName = "SettleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let signal = LoginRestoreSignal(defaults: defaults)
        let registeredAt = Date(timeIntervalSince1970: 1_000)

        signal.prepareForRegistration(at: registeredAt)

        XCTAssertFalse(
            signal.consumeRegistrationSuppression(
                at: registeredAt.addingTimeInterval(61),
                maximumAge: 60
            )
        )
    }

    func testLoginRestoreSignalConsumesFreshRequestOnce() throws {
        let suiteName = "SettleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let signal = LoginRestoreSignal(defaults: defaults)
        let requestedAt = Date(timeIntervalSince1970: 1_000)

        signal.requestLoginRestore(at: requestedAt)

        XCTAssertTrue(signal.consumeLoginRestoreRequest(at: requestedAt.addingTimeInterval(30)))
        XCTAssertFalse(signal.consumeLoginRestoreRequest(at: requestedAt.addingTimeInterval(30)))
    }

    func testLoginRestoreSignalRejectsExpiredRequest() throws {
        let suiteName = "SettleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let signal = LoginRestoreSignal(defaults: defaults)
        let requestedAt = Date(timeIntervalSince1970: 1_000)

        signal.requestLoginRestore(at: requestedAt)

        XCTAssertFalse(
            signal.consumeLoginRestoreRequest(
                at: requestedAt.addingTimeInterval(301),
                maximumAge: 300
            )
        )
    }
}

private final class FakeLoginItemService: LoginItemServicing {
    var state: LaunchAtLoginState
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0

    init(state: LaunchAtLoginState) {
        self.state = state
    }

    func register() throws {
        registerCallCount += 1
        state = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        state = .notRegistered
    }
}
