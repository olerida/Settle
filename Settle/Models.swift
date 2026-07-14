import CoreGraphics
import Foundation

enum SpacePolicy: String, Codable, Hashable, CaseIterable {
    case currentSpaceOnly
}

enum ExtraWindowsBehavior: String, Codable, Hashable, CaseIterable {
    case leaveUntouched
    case minimize
    case hide
}

struct WindowFrame: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct DisplaySnapshot: Codable, Hashable {
    var uuid: String?
    var vendorID: UInt32?
    var modelID: UInt32?
    var serialNumber: UInt32?
    var localizedName: String
    var visibleFrame: WindowFrame
    var isMain: Bool

    var hasHardwareIdentity: Bool {
        guard let vendorID, let modelID, let serialNumber else { return false }
        return vendorID != 0 && modelID != 0 && serialNumber != 0
    }
}

struct WindowSnapshot: Codable, Hashable, Identifiable {
    var id: UUID
    var windowTitleSnapshot: String
    var frame: WindowFrame
    var isMinimized: Bool
    var isMainWindowCandidate: Bool
    var orderIndex: Int
    var stackingIndex: Int
    var screenHint: String?
    var display: DisplaySnapshot?
    var normalizedFrame: WindowFrame?

    init(
        id: UUID = UUID(),
        windowTitleSnapshot: String,
        frame: WindowFrame,
        isMinimized: Bool,
        isMainWindowCandidate: Bool,
        orderIndex: Int,
        stackingIndex: Int,
        screenHint: String? = nil,
        display: DisplaySnapshot? = nil,
        normalizedFrame: WindowFrame? = nil
    ) {
        self.id = id
        self.windowTitleSnapshot = windowTitleSnapshot
        self.frame = frame
        self.isMinimized = isMinimized
        self.isMainWindowCandidate = isMainWindowCandidate
        self.orderIndex = orderIndex
        self.stackingIndex = stackingIndex
        self.screenHint = screenHint
        self.display = display
        self.normalizedFrame = normalizedFrame
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case windowTitleSnapshot
        case frame
        case isMinimized
        case isMainWindowCandidate
        case orderIndex
        case stackingIndex
        case screenHint
        case display
        case normalizedFrame
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        windowTitleSnapshot = try container.decode(String.self, forKey: .windowTitleSnapshot)
        frame = try container.decode(WindowFrame.self, forKey: .frame)
        isMinimized = try container.decode(Bool.self, forKey: .isMinimized)
        isMainWindowCandidate = try container.decode(Bool.self, forKey: .isMainWindowCandidate)
        orderIndex = try container.decode(Int.self, forKey: .orderIndex)
        stackingIndex = try container.decodeIfPresent(Int.self, forKey: .stackingIndex) ?? orderIndex
        screenHint = try container.decodeIfPresent(String.self, forKey: .screenHint)
        display = try container.decodeIfPresent(DisplaySnapshot.self, forKey: .display)
        normalizedFrame = try container.decodeIfPresent(WindowFrame.self, forKey: .normalizedFrame)
    }
}

struct AppLayoutSnapshot: Codable, Hashable, Identifiable {
    var id: UUID
    var bundleIdentifier: String
    var appDisplayName: String
    var windows: [WindowSnapshot]
    var browserWindows: [BrowserWindowTabs]?

    init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        appDisplayName: String,
        windows: [WindowSnapshot],
        browserWindows: [BrowserWindowTabs]? = nil
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appDisplayName = appDisplayName
        self.windows = windows
        self.browserWindows = browserWindows
    }
}

struct BrowserTab: Codable, Hashable {
    var url: String
}

struct BrowserWindowTabs: Codable, Hashable {
    var tabs: [BrowserTab]
}

struct Layout: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var pinned: Bool
    var pinnedOrder: Int?
    var snapshotFileName: String?
    var spacePolicy: SpacePolicy
    var extraWindowsBehaviorDefault: ExtraWindowsBehavior
    var restoresBrowserTabs: Bool
    var apps: [AppLayoutSnapshot]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        pinned: Bool = false,
        pinnedOrder: Int? = nil,
        snapshotFileName: String? = nil,
        spacePolicy: SpacePolicy = .currentSpaceOnly,
        extraWindowsBehaviorDefault: ExtraWindowsBehavior = .leaveUntouched,
        restoresBrowserTabs: Bool = false,
        apps: [AppLayoutSnapshot]
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pinned = pinned
        self.pinnedOrder = pinnedOrder
        self.snapshotFileName = snapshotFileName
        self.spacePolicy = spacePolicy
        self.extraWindowsBehaviorDefault = extraWindowsBehaviorDefault
        self.restoresBrowserTabs = restoresBrowserTabs
        self.apps = apps
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt
        case updatedAt
        case pinned
        case pinnedOrder
        case snapshotFileName
        case spacePolicy
        case extraWindowsBehaviorDefault
        case restoresBrowserTabs
        case apps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        pinned = try container.decode(Bool.self, forKey: .pinned)
        pinnedOrder = try container.decodeIfPresent(Int.self, forKey: .pinnedOrder)
        snapshotFileName = try container.decodeIfPresent(String.self, forKey: .snapshotFileName)
        spacePolicy = try container.decode(SpacePolicy.self, forKey: .spacePolicy)
        extraWindowsBehaviorDefault = try container.decode(ExtraWindowsBehavior.self, forKey: .extraWindowsBehaviorDefault)
        restoresBrowserTabs = try container.decodeIfPresent(Bool.self, forKey: .restoresBrowserTabs) ?? false
        apps = try container.decode([AppLayoutSnapshot].self, forKey: .apps)
    }
}

struct LayoutDocument: Codable {
    var version: Int
    var layouts: [Layout]

    static let currentVersion = 3
}

struct RestoreFailure: Error, Identifiable, Hashable {
    let id = UUID()
    let appName: String
    let message: String
}

struct RestoreReport {
    var launchedApps: [String] = []
    var restoredWindows: [String] = []
    var unreconciledWindows: [String] = []
    var unreconciledApps: [String] = []
    var missingApps: [String] = []
    var failures: [RestoreFailure] = []

    var completedSuccessfully: Bool {
        missingApps.isEmpty && unreconciledWindows.isEmpty && failures.isEmpty
    }

    mutating func recordUnreconciledWindow(_ windowLabel: String, appName: String) {
        unreconciledWindows.append(windowLabel)
        if !unreconciledApps.contains(appName) {
            unreconciledApps.append(appName)
        }
    }

    mutating func recordMissingApp(_ appName: String) {
        guard !missingApps.contains(appName) else { return }
        missingApps.append(appName)
    }
}
