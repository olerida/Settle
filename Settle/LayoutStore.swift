import Foundation

@MainActor
final class LayoutStore: ObservableObject {
    @Published private(set) var layouts: [Layout] = []

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let storageURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        self.storageURL = Self.makeStorageURL(fileManager: fileManager)
        load()
    }

    func listLayouts() -> [Layout] {
        layouts
    }

    func save(_ layout: Layout) throws {
        if let index = layouts.firstIndex(where: { $0.id == layout.id }) {
            layouts[index] = layout
        } else {
            layouts.append(layout)
        }
        sortLayouts()
        try persist()
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
        layouts.removeAll { $0.id == id }
        try persist()
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

    private static func makeStorageURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseURL
            .appendingPathComponent("Settle", isDirectory: true)
            .appendingPathComponent("layouts.json")
    }
}
