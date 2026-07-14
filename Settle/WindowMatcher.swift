import CoreGraphics
import Foundation

struct WindowCandidate {
    let title: String
    let frame: CGRect
    let orderIndex: Int
    let isMainWindowCandidate: Bool
}

enum WindowMatcher {
    static func bestMatch(
        target: WindowSnapshot,
        candidates: [WindowCandidate],
        referenceFrame: CGRect? = nil
    ) -> Int? {
        if !target.windowTitleSnapshot.isEmpty {
            let exactTitleMatches = candidates.indices.filter {
                !candidates[$0].title.isEmpty
                    && target.windowTitleSnapshot.localizedCaseInsensitiveCompare(candidates[$0].title) == .orderedSame
            }
            if exactTitleMatches.count == 1 {
                return exactTitleMatches[0]
            }
        }

        let scored = candidates.enumerated().map { index, candidate in
            (index, score(target: target, candidate: candidate, referenceFrame: referenceFrame))
        }

        guard let best = scored.min(by: { $0.1 < $1.1 }), best.1 < 2_500 else {
            return nil
        }
        return best.0
    }

    static func score(
        target: WindowSnapshot,
        candidate: WindowCandidate,
        referenceFrame: CGRect? = nil
    ) -> Double {
        let titlePenalty: Double
        if !target.windowTitleSnapshot.isEmpty && !candidate.title.isEmpty {
            titlePenalty = target.windowTitleSnapshot.localizedCaseInsensitiveCompare(candidate.title) == .orderedSame ? 0 : 300
        } else {
            titlePenalty = 120
        }

        let expectedFrame = referenceFrame ?? target.frame.cgRect
        let dx = expectedFrame.minX - candidate.frame.origin.x
        let dy = expectedFrame.minY - candidate.frame.origin.y
        let dw = expectedFrame.width - candidate.frame.size.width
        let dh = expectedFrame.height - candidate.frame.size.height
        let geometryPenalty = abs(dx) + abs(dy) + abs(dw) + abs(dh)
        let orderPenalty = Double(abs(target.orderIndex - candidate.orderIndex) * 40)
        let mainPenalty: Double = target.isMainWindowCandidate == candidate.isMainWindowCandidate ? 0 : 25

        return geometryPenalty + titlePenalty + orderPenalty + mainPenalty
    }
}
