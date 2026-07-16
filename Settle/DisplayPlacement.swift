import CoreGraphics
import Foundation

struct WindowPlacement: Equatable {
    let frame: CGRect
    let display: DisplaySnapshot
}

enum DisplayPlacement {
    static func appKitRectToAX(_ rect: CGRect, primaryFrame: CGRect) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func displayContainingLargestArea(
        of windowFrame: CGRect,
        displays: [DisplaySnapshot]
    ) -> DisplaySnapshot? {
        var bestDisplay: DisplaySnapshot?
        var bestArea: CGFloat = 0

        for display in displays {
            let intersection = windowFrame.intersection(display.visibleFrame.cgRect)
            let area = intersection.isNull ? 0 : intersection.width * intersection.height
            if area > bestArea {
                bestArea = area
                bestDisplay = display
            }
        }

        return bestDisplay
    }

    static func normalizedFrame(_ frame: CGRect, in visibleFrame: CGRect) -> WindowFrame? {
        guard visibleFrame.width > 0, visibleFrame.height > 0 else { return nil }
        return WindowFrame(
            rect: CGRect(
                x: (frame.minX - visibleFrame.minX) / visibleFrame.width,
                y: (frame.minY - visibleFrame.minY) / visibleFrame.height,
                width: frame.width / visibleFrame.width,
                height: frame.height / visibleFrame.height
            )
        )
    }

    static func translatedFrame(_ normalizedFrame: WindowFrame, into visibleFrame: CGRect) -> CGRect {
        CGRect(
            x: visibleFrame.minX + normalizedFrame.x * visibleFrame.width,
            y: visibleFrame.minY + normalizedFrame.y * visibleFrame.height,
            width: normalizedFrame.width * visibleFrame.width,
            height: normalizedFrame.height * visibleFrame.height
        )
    }

    static func matchDisplays(
        captured: [DisplaySnapshot],
        current: [DisplaySnapshot]
    ) -> [DisplaySnapshot: DisplaySnapshot] {
        let distinctCaptured = captured.reduce(into: [DisplaySnapshot]()) { result, display in
            if !result.contains(display) { result.append(display) }
        }
        var unmatchedCaptured = Array(distinctCaptured.indices)
        var availableCurrent = Array(current.indices)
        var result: [DisplaySnapshot: DisplaySnapshot] = [:]

        func assignMatches(
            candidateIndices: (DisplaySnapshot, [Int]) -> [Int],
            capturedIsUnambiguous: (DisplaySnapshot, [Int]) -> Bool = { _, _ in true }
        ) {
            for capturedIndex in unmatchedCaptured {
                let capturedDisplay = distinctCaptured[capturedIndex]
                guard capturedIsUnambiguous(capturedDisplay, unmatchedCaptured) else { continue }
                let candidates = candidateIndices(capturedDisplay, availableCurrent)
                guard candidates.count == 1, let currentIndex = candidates.first else { continue }
                result[capturedDisplay] = current[currentIndex]
                availableCurrent.removeAll { $0 == currentIndex }
            }
            unmatchedCaptured.removeAll { result[distinctCaptured[$0]] != nil }
        }

        assignMatches { capturedDisplay, available in
            guard let uuid = capturedDisplay.uuid?.lowercased(), !uuid.isEmpty else { return [] }
            return available.filter { current[$0].uuid?.lowercased() == uuid }
        }

        assignMatches { capturedDisplay, available in
            guard capturedDisplay.hasHardwareIdentity else { return [] }
            return available.filter {
                let candidate = current[$0]
                return candidate.hasHardwareIdentity
                    && candidate.vendorID == capturedDisplay.vendorID
                    && candidate.modelID == capturedDisplay.modelID
                    && candidate.serialNumber == capturedDisplay.serialNumber
            }
        }

        assignMatches(
            candidateIndices: { capturedDisplay, available in
                let nameMatches = available.filter {
                    current[$0].localizedName.localizedCaseInsensitiveCompare(capturedDisplay.localizedName) == .orderedSame
                }
                guard nameMatches.count > 1 else { return nameMatches }

                let capturedSize = capturedDisplay.visibleFrame.cgRect.size
                let sizeMatches = nameMatches.filter {
                    let size = current[$0].visibleFrame.cgRect.size
                    return abs(size.width - capturedSize.width) <= 2
                        && abs(size.height - capturedSize.height) <= 2
                }
                return sizeMatches.count == 1 ? sizeMatches : []
            },
            capturedIsUnambiguous: { capturedDisplay, unmatched in
                unmatched.filter {
                    distinctCaptured[$0].localizedName.localizedCaseInsensitiveCompare(capturedDisplay.localizedName) == .orderedSame
                }.count == 1
            }
        )

        return result
    }

    static func placement(
        for window: WindowSnapshot,
        currentDisplays: [DisplaySnapshot],
        displayMatches: [DisplaySnapshot: DisplaySnapshot]
    ) -> WindowPlacement? {
        guard let mainDisplay = currentDisplays.first(where: { $0.isMain }) ?? currentDisplays.first else {
            return nil
        }

        if let normalizedFrame = window.normalizedFrame {
            let targetDisplay = window.display.flatMap { displayMatches[$0] } ?? mainDisplay
            let translated = translatedFrame(normalizedFrame, into: targetDisplay.visibleFrame.cgRect)
            return WindowPlacement(
                frame: clamp(translated, to: targetDisplay.visibleFrame.cgRect),
                display: targetDisplay
            )
        }

        let absoluteFrame = window.frame.cgRect
        let targetDisplay = displayContainingLargestArea(of: absoluteFrame, displays: currentDisplays) ?? mainDisplay
        return WindowPlacement(
            frame: clamp(absoluteFrame, to: targetDisplay.visibleFrame.cgRect),
            display: targetDisplay
        )
    }

    static func clamp(_ frame: CGRect, to visibleFrame: CGRect) -> CGRect {
        guard visibleFrame.width > 0, visibleFrame.height > 0 else { return frame }

        let width = min(max(frame.width, 1), visibleFrame.width)
        let height = min(max(frame.height, 1), visibleFrame.height)
        let x = min(max(frame.minX, visibleFrame.minX), visibleFrame.maxX - width)
        let y = min(max(frame.minY, visibleFrame.minY), visibleFrame.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func isUsable(_ actualFrame: CGRect, on display: DisplaySnapshot) -> Bool {
        guard actualFrame.width > 0, actualFrame.height > 0 else { return false }

        let titleBar = CGRect(
            x: actualFrame.minX,
            y: actualFrame.minY,
            width: actualFrame.width,
            height: min(28, actualFrame.height)
        )
        let visibleTitleBar = titleBar.intersection(display.visibleFrame.cgRect)
        guard !visibleTitleBar.isNull else { return false }

        return visibleTitleBar.width >= min(80, titleBar.width)
            && visibleTitleBar.height >= min(20, titleBar.height)
    }

    static func matchesTargetFrame(
        _ actualFrame: CGRect,
        target targetFrame: CGRect,
        tolerance: CGFloat = 4
    ) -> Bool {
        abs(actualFrame.minX - targetFrame.minX) <= tolerance
            && abs(actualFrame.minY - targetFrame.minY) <= tolerance
            && abs(actualFrame.width - targetFrame.width) <= tolerance
            && abs(actualFrame.height - targetFrame.height) <= tolerance
    }
}
