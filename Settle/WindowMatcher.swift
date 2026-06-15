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
        candidates: [WindowCandidate]
    ) -> Int? {
        let scored = candidates.enumerated().map { index, candidate in
            (index, score(target: target, candidate: candidate))
        }

        guard let best = scored.min(by: { $0.1 < $1.1 }), best.1 < 2_500 else {
            return nil
        }
        return best.0
    }

    static func score(target: WindowSnapshot, candidate: WindowCandidate) -> Double {
        let titlePenalty: Double
        if !target.windowTitleSnapshot.isEmpty && !candidate.title.isEmpty {
            titlePenalty = target.windowTitleSnapshot.localizedCaseInsensitiveCompare(candidate.title) == .orderedSame ? 0 : 300
        } else {
            titlePenalty = 120
        }

        let dx = target.frame.x - candidate.frame.origin.x
        let dy = target.frame.y - candidate.frame.origin.y
        let dw = target.frame.width - candidate.frame.size.width
        let dh = target.frame.height - candidate.frame.size.height
        let geometryPenalty = abs(dx) + abs(dy) + abs(dw) + abs(dh)
        let orderPenalty = Double(abs(target.orderIndex - candidate.orderIndex) * 40)
        let mainPenalty: Double = target.isMainWindowCandidate == candidate.isMainWindowCandidate ? 0 : 25

        return geometryPenalty + titlePenalty + orderPenalty + mainPenalty
    }
}
