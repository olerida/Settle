import AppKit
import ApplicationServices
import Foundation

enum AppLauncherError: LocalizedError {
    case appNotInstalled(String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .appNotInstalled(let bundleIdentifier):
            L10n.format("The app %@ is not installed.", bundleIdentifier)
        case .launchFailed(let bundleIdentifier):
            L10n.format("This app could not be opened: %@.", bundleIdentifier)
        }
    }
}

struct AppLauncher {
    func ensureRunning(bundleIdentifier: String) async throws -> (NSRunningApplication, Bool) {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            return (running, false)
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw AppLauncherError.appNotInstalled(bundleIdentifier)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false

        try await withCheckedThrowingContinuation { continuation in
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { app, error in
                if app != nil {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: error ?? AppLauncherError.launchFailed(bundleIdentifier))
                }
            }
        }

        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
                return (running, true)
            }
            try await Task.sleep(for: .milliseconds(250))
        }

        throw AppLauncherError.launchFailed(bundleIdentifier)
    }

    func reopen(bundleIdentifier: String) async throws {
        try await open(bundleIdentifier: bundleIdentifier, activates: false)
    }

    func requestWindowInCurrentSpace(bundleIdentifier: String, runningApp: NSRunningApplication) async throws {
        guard !runningApp.isTerminated else {
            throw AppLauncherError.launchFailed(bundleIdentifier)
        }
        if pressNewWindowMenuItem(for: runningApp) {
            return
        }
        try await open(bundleIdentifier: bundleIdentifier, activates: false)
    }

    private func pressNewWindowMenuItem(for app: NSRunningApplication) -> Bool {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard
            let menuBar = axElementValue(appElement, attribute: kAXMenuBarAttribute),
            let menuItem = findNewWindowMenuItem(in: menuBar, remainingDepth: 6)
        else {
            return false
        }
        return AXUIElementPerformAction(menuItem, kAXPressAction as CFString) == .success
    }

    private func findNewWindowMenuItem(in element: AXUIElement, remainingDepth: Int) -> AXUIElement? {
        guard remainingDepth >= 0 else { return nil }
        let role = axStringValue(element, attribute: kAXRoleAttribute)
        if role == kAXMenuItemRole as String {
            let character = axStringValue(element, attribute: kAXMenuItemCmdCharAttribute)
            let modifiers = axUInt32Value(element, attribute: kAXMenuItemCmdModifiersAttribute) ?? 0
            let enabled = axBoolValue(element, attribute: kAXEnabledAttribute) ?? true
            if Self.isNewWindowShortcut(character: character, modifiers: modifiers, enabled: enabled) {
                return element
            }
        }

        for child in axElementsValue(element, attribute: kAXChildrenAttribute) {
            if let match = findNewWindowMenuItem(in: child, remainingDepth: remainingDepth - 1) {
                return match
            }
        }
        return nil
    }

    static func isNewWindowShortcut(character: String, modifiers: UInt32, enabled: Bool) -> Bool {
        enabled && character.caseInsensitiveCompare("n") == .orderedSame && modifiers == 0
    }

    private func axElementValue(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        guard
            let raw = axRawValue(element, attribute: attribute),
            CFGetTypeID(raw) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return unsafeDowncast(raw, to: AXUIElement.self)
    }

    private func axElementsValue(_ element: AXUIElement, attribute: String) -> [AXUIElement] {
        guard let raw = axRawValue(element, attribute: attribute), CFGetTypeID(raw) == CFArrayGetTypeID() else {
            return []
        }
        return raw as! [AXUIElement]
    }

    private func axStringValue(_ element: AXUIElement, attribute: String) -> String {
        guard let raw = axRawValue(element, attribute: attribute), CFGetTypeID(raw) == CFStringGetTypeID() else {
            return ""
        }
        return raw as! String
    }

    private func axBoolValue(_ element: AXUIElement, attribute: String) -> Bool? {
        guard let raw = axRawValue(element, attribute: attribute), CFGetTypeID(raw) == CFBooleanGetTypeID() else {
            return nil
        }
        return CFBooleanGetValue(unsafeDowncast(raw, to: CFBoolean.self))
    }

    private func axUInt32Value(_ element: AXUIElement, attribute: String) -> UInt32? {
        guard let raw = axRawValue(element, attribute: attribute), CFGetTypeID(raw) == CFNumberGetTypeID() else {
            return nil
        }
        var value: Int32 = 0
        let number = unsafeDowncast(raw, to: CFNumber.self)
        return CFNumberGetValue(number, .sInt32Type, &value) ? UInt32(bitPattern: value) : nil
    }

    private func axRawValue(_ element: AXUIElement, attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private func open(bundleIdentifier: String, activates: Bool) async throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw AppLauncherError.appNotInstalled(bundleIdentifier)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
