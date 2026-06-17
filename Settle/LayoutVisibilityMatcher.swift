import Foundation

enum LayoutVisibilityMatcher {
    static func bestMatch(
        currentApps: [AppLayoutSnapshot],
        among layouts: [Layout],
        minimumScore: Double = 0.6
    ) -> Layout? {
        let scored = layouts.map { layout in
            (layout, score(currentApps: currentApps, against: layout))
        }

        guard let best = scored.max(by: { $0.1 < $1.1 }), best.1 >= minimumScore else {
            return nil
        }

        return best.0
    }

    static func score(currentApps: [AppLayoutSnapshot], against layout: Layout) -> Double {
        guard !currentApps.isEmpty, !layout.apps.isEmpty else { return 0 }

        let currentAppsByBundle = Dictionary(uniqueKeysWithValues: currentApps.map { ($0.bundleIdentifier, $0) })
        let expectedWindowCount = max(1, layout.apps.reduce(0) { $0 + $1.windows.count })

        var matchedAppCount = 0
        var matchedWindowCount = 0
        var matchedWindowQuality = 0.0

        for expectedApp in layout.apps {
            guard let currentApp = currentAppsByBundle[expectedApp.bundleIdentifier] else { continue }
            matchedAppCount += 1

            var remainingCandidates = currentApp.windows.enumerated().map { index, window in
                (
                    index,
                    WindowCandidate(
                        title: window.windowTitleSnapshot,
                        frame: window.frame.cgRect,
                        orderIndex: window.orderIndex,
                        isMainWindowCandidate: window.isMainWindowCandidate
                    )
                )
            }

            for expectedWindow in expectedApp.windows.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                let candidates = remainingCandidates.map(\.1)
                guard let matchIndex = WindowMatcher.bestMatch(target: expectedWindow, candidates: candidates) else {
                    continue
                }

                let candidate = remainingCandidates.remove(at: matchIndex).1
                matchedWindowCount += 1
                let rawScore = WindowMatcher.score(target: expectedWindow, candidate: candidate)
                matchedWindowQuality += max(0, 1 - (rawScore / 2_500))
            }
        }

        let appCoverage = Double(matchedAppCount) / Double(max(1, layout.apps.count))
        let windowCoverage = Double(matchedWindowCount) / Double(expectedWindowCount)
        let quality = matchedWindowCount > 0 ? matchedWindowQuality / Double(matchedWindowCount) : 0
        let extraAppPenalty = min(
            0.18,
            Double(max(0, currentApps.count - matchedAppCount)) / Double(max(1, currentApps.count)) * 0.18
        )

        return max(0, (appCoverage * 0.4) + (windowCoverage * 0.4) + (quality * 0.25) - extraAppPenalty)
    }
}
