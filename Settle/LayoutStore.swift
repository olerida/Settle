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
        layouts[index].updatedAt = .now
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
            sortLayouts()
        } catch {
            layouts = []
        }
    }

    private func sortLayouts() {
        layouts.sort {
            if $0.pinned != $1.pinned {
                return $0.pinned && !$1.pinned
            }
            if $0.updatedAt != $1.updatedAt {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
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
