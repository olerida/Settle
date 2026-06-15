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

struct WindowSnapshot: Codable, Hashable, Identifiable {
    var id: UUID
    var windowTitleSnapshot: String
    var frame: WindowFrame
    var isMinimized: Bool
    var isMainWindowCandidate: Bool
    var orderIndex: Int
    var stackingIndex: Int
    var screenHint: String?

    init(
        id: UUID = UUID(),
        windowTitleSnapshot: String,
        frame: WindowFrame,
        isMinimized: Bool,
        isMainWindowCandidate: Bool,
        orderIndex: Int,
        stackingIndex: Int,
        screenHint: String? = nil
    ) {
        self.id = id
        self.windowTitleSnapshot = windowTitleSnapshot
        self.frame = frame
        self.isMinimized = isMinimized
        self.isMainWindowCandidate = isMainWindowCandidate
        self.orderIndex = orderIndex
        self.stackingIndex = stackingIndex
        self.screenHint = screenHint
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
    }
}

struct AppLayoutSnapshot: Codable, Hashable, Identifiable {
    var id: UUID
    var bundleIdentifier: String
    var appDisplayName: String
    var windows: [WindowSnapshot]

    init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        appDisplayName: String,
        windows: [WindowSnapshot]
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appDisplayName = appDisplayName
        self.windows = windows
    }
}

struct Layout: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var pinned: Bool
    var snapshotFileName: String?
    var spacePolicy: SpacePolicy
    var extraWindowsBehaviorDefault: ExtraWindowsBehavior
    var apps: [AppLayoutSnapshot]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        pinned: Bool = false,
        snapshotFileName: String? = nil,
        spacePolicy: SpacePolicy = .currentSpaceOnly,
        extraWindowsBehaviorDefault: ExtraWindowsBehavior = .leaveUntouched,
        apps: [AppLayoutSnapshot]
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pinned = pinned
        self.snapshotFileName = snapshotFileName
        self.spacePolicy = spacePolicy
        self.extraWindowsBehaviorDefault = extraWindowsBehaviorDefault
        self.apps = apps
    }
}

struct LayoutDocument: Codable {
    var version: Int
    var layouts: [Layout]

    static let currentVersion = 1
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
    var failures: [RestoreFailure] = []
}
