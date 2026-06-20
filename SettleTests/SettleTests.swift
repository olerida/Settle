import ApplicationServices
import CoreGraphics
import XCTest
@testable import Settle

final class SettleTests: XCTestCase {
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

    func testLayoutDocumentRoundTrip() throws {
        let layout = Layout(name: "Work", apps: [
            AppLayoutSnapshot(bundleIdentifier: "com.apple.TextEdit", appDisplayName: "TextEdit", windows: [
                WindowSnapshot(
                    windowTitleSnapshot: "Notes",
                    frame: WindowFrame(rect: CGRect(x: 10, y: 10, width: 300, height: 200)),
                    isMinimized: false,
                    isMainWindowCandidate: true,
                    orderIndex: 0,
                    stackingIndex: 0
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
