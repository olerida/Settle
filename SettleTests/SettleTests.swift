import CoreGraphics
import XCTest
@testable import Settle

final class SettleTests: XCTestCase {
    func testWindowMatcherPrefersExactTitleAndGeometry() {
        let target = WindowSnapshot(
            windowTitleSnapshot: "Project",
            frame: WindowFrame(rect: CGRect(x: 100, y: 100, width: 800, height: 600)),
            isMinimized: false,
            isMainWindowCandidate: true,
            orderIndex: 0
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
                    orderIndex: 0
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
    }
}
