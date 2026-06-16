import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

enum WindowManagerError: LocalizedError {
    case accessibilityPermissionMissing
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionMissing:
            L10n.tr("The window layout could not be restored because Accessibility access is missing.")
        case .captureFailed:
            L10n.tr("The current desktop could not be captured.")
        }
    }
}

struct WindowManager {
    struct CapturedLayoutResult {
        let layout: Layout
        let previewWindows: [PreviewWindowCapture]
    }

    struct PreviewWindowCapture {
        let windowID: CGWindowID
        let frame: CGRect
        let stackingIndex: Int
    }

    private struct VisibleWindowRecord {
        let offset: Int
        let windowID: CGWindowID
        let pid: pid_t
        let frame: CGRect
        let title: String
    }

    func captureCurrentLayout(name: String) throws -> CapturedLayoutResult {
        guard AXIsProcessTrusted() else {
            throw WindowManagerError.accessibilityPermissionMissing
        }

        let visibleWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let filtered = visibleWindows.enumerated().compactMap { offset, windowInfo -> VisibleWindowRecord? in
            guard
                let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                pid != currentPID,
                let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat]
            else {
                return nil
            }

            let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
            if layer != 0 { return nil }

            let frame = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            guard frame.width > 80, frame.height > 60 else { return nil }
            let title = windowInfo[kCGWindowName as String] as? String ?? ""
            return VisibleWindowRecord(
                offset: offset,
                windowID: windowID,
                pid: pid,
                frame: frame,
                title: title
            )
        }

        let grouped = Dictionary(grouping: filtered, by: \.pid)
        var previewWindows: [PreviewWindowCapture] = []

        let appSnapshots = grouped.compactMap { pid, windows -> AppLayoutSnapshot? in
            guard
                let runningApp = NSRunningApplication(processIdentifier: pid),
                let bundleIdentifier = runningApp.bundleIdentifier,
                !bundleIdentifier.isEmpty,
                shouldCaptureApp(bundleIdentifier: bundleIdentifier, appName: runningApp.localizedName ?? "")
            else {
                return nil
            }

            let accessibleWindows = axWindows(for: pid)
            let ordered = windows.sorted { $0.offset < $1.offset }
            let snapshots = ordered.enumerated().compactMap { orderIndex, entry in
                makeWindowSnapshot(
                    orderIndex: orderIndex,
                    stackingIndex: entry.offset,
                    title: entry.title,
                    frame: entry.frame,
                    accessibleWindows: accessibleWindows
                )
            }

            guard !snapshots.isEmpty else { return nil }
            previewWindows.append(contentsOf: ordered.map {
                PreviewWindowCapture(
                    windowID: $0.windowID,
                    frame: $0.frame,
                    stackingIndex: $0.offset
                )
            })
            let appName = runningApp.localizedName ?? bundleIdentifier
            return AppLayoutSnapshot(bundleIdentifier: bundleIdentifier, appDisplayName: appName, windows: snapshots)
        }
        .sorted { $0.appDisplayName.localizedCaseInsensitiveCompare($1.appDisplayName) == .orderedAscending }

        guard !appSnapshots.isEmpty else {
            throw WindowManagerError.captureFailed
        }

        return CapturedLayoutResult(
            layout: Layout(name: name, apps: appSnapshots),
            previewWindows: previewWindows
        )
    }

    func captureDesktopSnapshotPNGData(
        for layout: Layout,
        previewWindows: [PreviewWindowCapture],
        maxPreviewSize: CGSize = CGSize(width: 360, height: 220),
        padding: CGFloat = 24
    ) -> Data? {
        guard
            !previewWindows.isEmpty,
            let snapshotBounds = Self.snapshotBounds(for: previewWindows, fallbackLayout: layout, padding: padding),
            let compositeImage = compositePreviewImage(previewWindows, within: snapshotBounds)
        else {
            return nil
        }

        let sourceSize = CGSize(width: compositeImage.width, height: compositeImage.height)
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }

        let scale = min(
            1,
            maxPreviewSize.width / sourceSize.width,
            maxPreviewSize.height / sourceSize.height
        )
        let targetSize = CGSize(
            width: max(1, floor(sourceSize.width * scale)),
            height: max(1, floor(sourceSize.height * scale))
        )
        let rendered = NSImage(cgImage: compositeImage, size: sourceSize)

        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(targetSize.width),
                pixelsHigh: Int(targetSize.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        rendered.draw(in: CGRect(origin: .zero, size: targetSize))
        NSGraphicsContext.restoreGraphicsState()

        return bitmap.representation(using: .png, properties: [:])
    }

    static func snapshotBounds(for layout: Layout, padding: CGFloat = 24) -> CGRect? {
        let frames = layout.apps
            .flatMap(\.windows)
            .map { $0.frame.cgRect }
            .filter { $0.width > 1 && $0.height > 1 }

        guard let union = frames.reduce(nil, { partial, frame in
            partial?.union(frame) ?? frame
        }) else {
            return nil
        }

        return union
            .insetBy(dx: -padding, dy: -padding)
            .integral
    }

    private static func snapshotBounds(
        for previewWindows: [PreviewWindowCapture],
        fallbackLayout layout: Layout,
        padding: CGFloat = 24
    ) -> CGRect? {
        let frames = previewWindows
            .map(\.frame)
            .filter { $0.width > 1 && $0.height > 1 }

        guard let union = frames.reduce(nil, { partial, frame in
            partial?.union(frame) ?? frame
        }) else {
            return snapshotBounds(for: layout, padding: padding)
        }

        return union
            .insetBy(dx: -padding, dy: -padding)
            .integral
    }

    private func compositePreviewImage(
        _ previewWindows: [PreviewWindowCapture],
        within snapshotBounds: CGRect
    ) -> CGImage? {
        let canvasSize = CGSize(
            width: max(1, ceil(snapshotBounds.width)),
            height: max(1, ceil(snapshotBounds.height))
        )

        guard
            let context = CGContext(
                data: nil,
                width: Int(canvasSize.width),
                height: Int(canvasSize.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return nil
        }

        context.interpolationQuality = .high
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
        context.fill(CGRect(origin: .zero, size: canvasSize))

        var renderedAnyWindow = false

        for previewWindow in previewWindows.sorted(by: { $0.stackingIndex > $1.stackingIndex }) {
            guard let image = CGWindowListCreateImage(
                CGRectNull,
                .optionIncludingWindow,
                previewWindow.windowID,
                [.boundsIgnoreFraming, .bestResolution]
            ) else {
                continue
            }

            let drawRect = CGRect(
                x: previewWindow.frame.minX - snapshotBounds.minX,
                y: snapshotBounds.maxY - previewWindow.frame.maxY,
                width: previewWindow.frame.width,
                height: previewWindow.frame.height
            )

            context.draw(image, in: drawRect)
            renderedAnyWindow = true
        }

        guard renderedAnyWindow else { return nil }
        return context.makeImage()
    }

    private func shouldCaptureApp(bundleIdentifier: String, appName: String) -> Bool {
        if bundleIdentifier.hasPrefix("com.apple.accessibility.") {
            return false
        }

        let loweredName = appName.lowercased()
        if loweredName.contains("authwarn") {
            return false
        }

        return true
    }

    func restoreLayout(_ layout: Layout, appLauncher: AppLauncher) async -> RestoreReport {
        guard AXIsProcessTrusted() else {
            return RestoreReport(
                failures: [RestoreFailure(appName: "Settle", message: WindowManagerError.accessibilityPermissionMissing.localizedDescription)]
            )
        }

        var report = RestoreReport()
        var matchedWindows: [(WindowSnapshot, AXUIElement)] = []

        for appSnapshot in layout.apps {
            do {
                let (runningApp, launched) = try await appLauncher.ensureRunning(bundleIdentifier: appSnapshot.bundleIdentifier)
                if launched {
                    report.launchedApps.append(appSnapshot.appDisplayName)
                    try await Task.sleep(for: .milliseconds(900))
                }

                var unmatchedWindows = axWindows(for: runningApp.processIdentifier)
                if unmatchedWindows.isEmpty {
                    try await Task.sleep(for: .milliseconds(600))
                    unmatchedWindows = axWindows(for: runningApp.processIdentifier)
                }

                var currentSpaceWindowRequests = 0
                var reopenAttempted = false

                for targetWindow in appSnapshot.windows.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                    var windowCandidates = candidates(for: unmatchedWindows)

                    while WindowMatcher.bestMatch(target: targetWindow, candidates: windowCandidates.map(\.1)) == nil, currentSpaceWindowRequests < 2 {
                        try await appLauncher.requestWindowInCurrentSpace(
                            bundleIdentifier: appSnapshot.bundleIdentifier,
                            runningApp: runningApp
                        )
                        currentSpaceWindowRequests += 1
                        try await Task.sleep(for: .milliseconds(900))
                        unmatchedWindows = axWindows(for: runningApp.processIdentifier)
                        windowCandidates = candidates(for: unmatchedWindows)
                    }

                    if WindowMatcher.bestMatch(target: targetWindow, candidates: windowCandidates.map(\.1)) == nil, !reopenAttempted {
                        try await appLauncher.reopen(bundleIdentifier: appSnapshot.bundleIdentifier)
                        reopenAttempted = true
                        try await Task.sleep(for: .milliseconds(900))
                        unmatchedWindows = axWindows(for: runningApp.processIdentifier)
                        windowCandidates = candidates(for: unmatchedWindows)
                    }

                    guard let matchIndex = WindowMatcher.bestMatch(target: targetWindow, candidates: windowCandidates.map(\.1)) else {
                        report.unreconciledWindows.append(label(for: appSnapshot, window: targetWindow))
                        continue
                    }

                    let axIndex = windowCandidates[matchIndex].0
                    let element = unmatchedWindows.remove(at: axIndex)
                    apply(window: element, target: targetWindow)
                    matchedWindows.append((targetWindow, element))
                    report.restoredWindows.append(label(for: appSnapshot, window: targetWindow))
                }
            } catch {
                report.failures.append(
                    RestoreFailure(appName: appSnapshot.appDisplayName, message: error.localizedDescription)
                )
            }
        }

        await raiseWindowsToSavedOrder(matchedWindows)

        return report
    }

    private func candidates(for windows: [AXUIElement]) -> [(Int, WindowCandidate)] {
        windows.enumerated().compactMap { index, element -> (Int, WindowCandidate)? in
            guard let candidate = windowCandidate(from: element, orderIndex: index) else { return nil }
            return (index, candidate)
        }
    }

    private func label(for appSnapshot: AppLayoutSnapshot, window: WindowSnapshot) -> String {
        let title = window.windowTitleSnapshot.isEmpty ? L10n.tr("Untitled Window") : window.windowTitleSnapshot
        return "\(appSnapshot.appDisplayName) - \(title)"
    }

    private func makeWindowSnapshot(
        orderIndex: Int,
        stackingIndex: Int,
        title: String,
        frame: CGRect,
        accessibleWindows: [AXUIElement]
    ) -> WindowSnapshot? {
        var minimized = false
        var isMain = orderIndex == 0

        if let match = accessibleWindows.first(where: { axWindow in
            let axTitle = axStringValue(axWindow, attribute: kAXTitleAttribute)
            let axFrame = axFrameValue(axWindow)
            let titlesEqual = title.isEmpty || axTitle.isEmpty || title.caseInsensitiveCompare(axTitle) == .orderedSame
            guard titlesEqual, let axFrame else { return false }
            return distance(axFrame, frame) < 120
        }) {
            minimized = axBoolValue(match, attribute: kAXMinimizedAttribute) ?? false
            isMain = (axBoolValue(match, attribute: kAXMainAttribute) ?? false) || orderIndex == 0
        }

        return WindowSnapshot(
            windowTitleSnapshot: title,
            frame: WindowFrame(rect: frame),
            isMinimized: minimized,
            isMainWindowCandidate: isMain,
            orderIndex: orderIndex,
            stackingIndex: stackingIndex,
            screenHint: NSScreen.screens.first(where: { $0.frame.intersects(frame) })?.localizedName
        )
    }

    private func raiseWindowsToSavedOrder(_ matches: [(WindowSnapshot, AXUIElement)]) async {
        for match in Self.matchesInRaiseOrder(matches) {
            AXUIElementPerformAction(match.1, kAXRaiseAction as CFString)
            try? await Task.sleep(for: .milliseconds(35))
        }
    }

    static func matchesInRaiseOrder(_ matches: [(WindowSnapshot, AXUIElement)]) -> [(WindowSnapshot, AXUIElement)] {
        matches.sorted(by: { $0.0.stackingIndex > $1.0.stackingIndex })
    }

    private func apply(window: AXUIElement, target: WindowSnapshot) {
        if let falseValue = try? axValue(target.isMinimized ? kCFBooleanTrue : kCFBooleanFalse) {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, falseValue)
        }

        var position = CGPoint(x: target.frame.x, y: target.frame.y)
        var size = CGSize(width: target.frame.width, height: target.frame.height)
        if let positionValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
        if let minimizedValue = try? axValue(target.isMinimized ? kCFBooleanTrue : kCFBooleanFalse) {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, minimizedValue)
        }
    }

    private func axWindows(for pid: pid_t) -> [AXUIElement] {
        let appElement = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let value, CFGetTypeID(value) == CFArrayGetTypeID() else {
            return []
        }

        let windows = value as! [AXUIElement]
        return windows.filter { window in
            let role = axStringValue(window, attribute: kAXRoleAttribute)
            let subrole = axStringValue(window, attribute: kAXSubroleAttribute)
            guard role == kAXWindowRole as String else { return false }
            return subrole.isEmpty || subrole == kAXStandardWindowSubrole as String
        }
    }

    private func windowCandidate(from window: AXUIElement, orderIndex: Int) -> WindowCandidate? {
        guard let frame = axFrameValue(window), frame.width > 40, frame.height > 40 else {
            return nil
        }
        let title = axStringValue(window, attribute: kAXTitleAttribute)
        let isMain = axBoolValue(window, attribute: kAXMainAttribute) ?? (orderIndex == 0)
        return WindowCandidate(title: title, frame: frame, orderIndex: orderIndex, isMainWindowCandidate: isMain)
    }

    private func axFrameValue(_ element: AXUIElement) -> CGRect? {
        guard
            let rawPosition = axRawValue(element, attribute: kAXPositionAttribute),
            let rawSize = axRawValue(element, attribute: kAXSizeAttribute),
            CFGetTypeID(rawPosition) == AXValueGetTypeID(),
            CFGetTypeID(rawSize) == AXValueGetTypeID()
        else {
            return nil
        }
        let positionValue = unsafeDowncast(rawPosition, to: AXValue.self)
        let sizeValue = unsafeDowncast(rawSize, to: AXValue.self)

        var point = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetType(positionValue) == .cgPoint,
            AXValueGetValue(positionValue, .cgPoint, &point),
            AXValueGetType(sizeValue) == .cgSize,
            AXValueGetValue(sizeValue, .cgSize, &size)
        else {
            return nil
        }
        return CGRect(origin: point, size: size)
    }

    private func axStringValue(_ element: AXUIElement, attribute: String) -> String {
        guard let raw = axRawValue(element, attribute: attribute) else { return "" }
        return raw as? String ?? ""
    }

    private func axBoolValue(_ element: AXUIElement, attribute: String) -> Bool? {
        guard let raw = axRawValue(element, attribute: attribute) else { return nil }
        if let value = raw as? Bool {
            return value
        }
        if CFGetTypeID(raw) == CFBooleanGetTypeID() {
            let value = unsafeDowncast(raw, to: CFBoolean.self)
            return CFBooleanGetValue(value)
        }
        return nil
    }

    private func axRawValue(_ element: AXUIElement, attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let value else { return nil }
        return value
    }

    private func axValue(_ value: CFBoolean) throws -> CFTypeRef {
        value
    }

    private func distance(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        abs(lhs.origin.x - rhs.origin.x)
        + abs(lhs.origin.y - rhs.origin.y)
        + abs(lhs.size.width - rhs.size.width)
        + abs(lhs.size.height - rhs.size.height)
    }
}
