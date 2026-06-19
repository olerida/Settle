import Foundation

@MainActor
final class LayoutStore: ObservableObject {
    @Published private(set) var layouts: [Layout] = []

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let storageURL: URL
    private let snapshotsDirectoryURL: URL

    convenience init(fileManager: FileManager = .default) {
        self.init(
            fileManager: fileManager,
            storageURL: Self.makeStorageURL(fileManager: fileManager),
            snapshotsDirectoryURL: Self.makeSnapshotsDirectoryURL(fileManager: fileManager)
        )
    }

    init(
        fileManager: FileManager = .default,
        storageURL: URL,
        snapshotsDirectoryURL: URL
    ) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        self.storageURL = storageURL
        self.snapshotsDirectoryURL = snapshotsDirectoryURL
        load()
    }

    func listLayouts() -> [Layout] {
        layouts
    }

    func save(_ layout: Layout, snapshotPNGData: Data? = nil) throws {
        var persistedLayout = layout
        let previousSnapshotFileName = layouts.first(where: { $0.id == persistedLayout.id })?.snapshotFileName

        if persistedLayout.pinned && persistedLayout.pinnedOrder == nil {
            persistedLayout.pinnedOrder = nextPinnedOrder()
        } else if !persistedLayout.pinned {
            persistedLayout.pinnedOrder = nil
        }

        if let snapshotPNGData {
            persistedLayout.snapshotFileName = try writeSnapshot(data: snapshotPNGData, layoutID: layout.id)
        }

        if let index = layouts.firstIndex(where: { $0.id == persistedLayout.id }) {
            if persistedLayout.snapshotFileName == nil {
                persistedLayout.snapshotFileName = layouts[index].snapshotFileName
            }
            layouts[index] = persistedLayout
        } else {
            layouts.append(persistedLayout)
        }
        sortLayouts()
        try persist()

        if
            let previousSnapshotFileName,
            let currentSnapshotFileName = persistedLayout.snapshotFileName,
            previousSnapshotFileName != currentSnapshotFileName
        {
            try deleteSnapshotIfNeeded(named: previousSnapshotFileName)
        }
    }

    func renameLayout(id: UUID, name: String) throws {
        guard let index = layouts.firstIndex(where: { $0.id == id }) else { return }
        layouts[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        layouts[index].updatedAt = .now
        sortLayouts()
        try persist()
    }

    func togglePinned(id: UUID) throws {
        guard let index = layouts.firstIndex(where: { $0.id == id }) else { return }
        layouts[index].pinned.toggle()
        layouts[index].pinnedOrder = layouts[index].pinned ? nextPinnedOrder() : nil
        layouts[index].updatedAt = .now
        sortLayouts()
        try persist()
    }

    func movePinnedLayout(from sourceIndex: Int, to destinationIndex: Int) throws {
        var pinnedLayouts = layouts.filter(\.pinned).sorted(by: pinnedSort)
        guard sourceIndex != destinationIndex else { return }
        guard pinnedLayouts.indices.contains(sourceIndex) else { return }

        let safeDestination = max(0, min(destinationIndex, pinnedLayouts.count))
        let movedLayout = pinnedLayouts.remove(at: sourceIndex)
        pinnedLayouts.insert(movedLayout, at: safeDestination > sourceIndex ? safeDestination - 1 : safeDestination)

        for (index, layout) in pinnedLayouts.enumerated() {
            guard let storedIndex = layouts.firstIndex(where: { $0.id == layout.id }) else { continue }
            layouts[storedIndex].pinnedOrder = index
            layouts[storedIndex].updatedAt = .now
        }

        sortLayouts()
        try persist()
    }

    func deleteLayout(id: UUID) throws {
        if let snapshotFileName = layouts.first(where: { $0.id == id })?.snapshotFileName {
            try deleteSnapshotIfNeeded(named: snapshotFileName)
        }
        layouts.removeAll { $0.id == id }
        try persist()
    }

    func snapshotURL(for layout: Layout) -> URL? {
        guard let snapshotFileName = layout.snapshotFileName else { return nil }
        let url = snapshotsDirectoryURL.appendingPathComponent(snapshotFileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    private func load() {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            layouts = []
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let document = try decoder.decode(LayoutDocument.self, from: data)
            layouts = document.layouts
            normalizePinnedOrders()
            sortLayouts()
        } catch {
            layouts = []
        }
    }

    private func sortLayouts() {
        normalizePinnedOrders()
        layouts.sort(by: layoutSort)
    }

    private func persist() throws {
        let directory = storageURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let document = LayoutDocument(version: LayoutDocument.currentVersion, layouts: layouts)
        let data = try encoder.encode(document)
        try data.write(to: storageURL, options: [.atomic])
    }

    private func writeSnapshot(data: Data, layoutID: UUID) throws -> String {
        try fileManager.createDirectory(at: snapshotsDirectoryURL, withIntermediateDirectories: true)
        let fileName = "\(layoutID.uuidString.lowercased())-\(UUID().uuidString.lowercased()).png"
        let snapshotURL = snapshotsDirectoryURL.appendingPathComponent(fileName)
        try data.write(to: snapshotURL, options: [.atomic])
        return fileName
    }

    private func deleteSnapshotIfNeeded(named fileName: String) throws {
        let snapshotURL = snapshotsDirectoryURL.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: snapshotURL.path) else { return }
        try fileManager.removeItem(at: snapshotURL)
    }

    private func normalizePinnedOrders() {
        let orderedPinnedLayouts = layouts
            .filter(\.pinned)
            .sorted(by: pinnedSort)

        for (index, layout) in orderedPinnedLayouts.enumerated() {
            guard let storedIndex = layouts.firstIndex(where: { $0.id == layout.id }) else { continue }
            layouts[storedIndex].pinnedOrder = index
        }

        for index in layouts.indices where !layouts[index].pinned {
            layouts[index].pinnedOrder = nil
        }
    }

    private func nextPinnedOrder() -> Int {
        layouts.compactMap(\.pinnedOrder).max().map { $0 + 1 } ?? 0
    }

    private func pinnedSort(_ lhs: Layout, _ rhs: Layout) -> Bool {
        if lhs.pinnedOrder != rhs.pinnedOrder {
            return (lhs.pinnedOrder ?? .max) < (rhs.pinnedOrder ?? .max)
        }
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func layoutSort(_ lhs: Layout, _ rhs: Layout) -> Bool {
        if lhs.pinned != rhs.pinned {
            return lhs.pinned && !rhs.pinned
        }
        if lhs.pinned {
            return pinnedSort(lhs, rhs)
        }
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func makeStorageURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseURL
            .appendingPathComponent("Settle", isDirectory: true)
            .appendingPathComponent("layouts.json")
    }

    private static func makeSnapshotsDirectoryURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseURL
            .appendingPathComponent("Settle", isDirectory: true)
            .appendingPathComponent("Snapshots", isDirectory: true)
    }
}
