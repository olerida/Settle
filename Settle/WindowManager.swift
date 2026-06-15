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
            "Settle necesita permiso de Accesibilidad para leer y mover ventanas."
        case .captureFailed:
            "No se pudo capturar el escritorio actual."
        }
    }
}

struct WindowManager {
    func captureCurrentLayout(name: String) throws -> Layout {
        guard AXIsProcessTrusted() else {
            throw WindowManagerError.accessibilityPermissionMissing
        }

        let visibleWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let filtered = visibleWindows.enumerated().compactMap { offset, windowInfo -> (Int, pid_t, CGRect, String?)? in
            guard
                let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                pid != currentPID,
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
            let title = windowInfo[kCGWindowName as String] as? String
            return (offset, pid, frame, title)
        }

        let grouped = Dictionary(grouping: filtered, by: \.1)
        let appSnapshots = grouped.compactMap { pid, windows -> AppLayoutSnapshot? in
            guard
                let runningApp = NSRunningApplication(processIdentifier: pid),
                let bundleIdentifier = runningApp.bundleIdentifier,
                !bundleIdentifier.isEmpty
            else {
                return nil
            }

            let accessibleWindows = axWindows(for: pid)
            let ordered = windows.sorted { $0.0 < $1.0 }
            let snapshots = ordered.enumerated().compactMap { orderIndex, entry in
                makeWindowSnapshot(
                    orderIndex: orderIndex,
                    title: entry.3 ?? "",
                    frame: entry.2,
                    accessibleWindows: accessibleWindows
                )
            }

            guard !snapshots.isEmpty else { return nil }
            let appName = runningApp.localizedName ?? bundleIdentifier
            return AppLayoutSnapshot(bundleIdentifier: bundleIdentifier, appDisplayName: appName, windows: snapshots)
        }
        .sorted { $0.appDisplayName.localizedCaseInsensitiveCompare($1.appDisplayName) == .orderedAscending }

        guard !appSnapshots.isEmpty else {
            throw WindowManagerError.captureFailed
        }

        return Layout(name: name, apps: appSnapshots)
    }

    func restoreLayout(_ layout: Layout, appLauncher: AppLauncher) async -> RestoreReport {
        guard AXIsProcessTrusted() else {
            return RestoreReport(
                failures: [RestoreFailure(appName: "Settle", message: WindowManagerError.accessibilityPermissionMissing.localizedDescription)]
            )
        }

        var report = RestoreReport()

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

                var reopenAttempted = false

                for targetWindow in appSnapshot.windows.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                    var windowCandidates = candidates(for: unmatchedWindows)

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
                    report.restoredWindows.append(label(for: appSnapshot, window: targetWindow))
                }
            } catch {
                report.failures.append(
                    RestoreFailure(appName: appSnapshot.appDisplayName, message: error.localizedDescription)
                )
            }
        }

        return report
    }

    private func candidates(for windows: [AXUIElement]) -> [(Int, WindowCandidate)] {
        windows.enumerated().compactMap { index, element -> (Int, WindowCandidate)? in
            guard let candidate = windowCandidate(from: element, orderIndex: index) else { return nil }
            return (index, candidate)
        }
    }

    private func label(for appSnapshot: AppLayoutSnapshot, window: WindowSnapshot) -> String {
        let title = window.windowTitleSnapshot.isEmpty ? "Untitled Window" : window.windowTitleSnapshot
        return "\(appSnapshot.appDisplayName) - \(title)"
    }

    private func makeWindowSnapshot(
        orderIndex: Int,
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
            screenHint: NSScreen.screens.first(where: { $0.frame.intersects(frame) })?.localizedName
        )
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
