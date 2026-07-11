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
    enum BrowserRestoreStrategy: Equatable {
        case safari
        case chrome

        static func forBundleIdentifier(_ bundleIdentifier: String) -> BrowserRestoreStrategy? {
            switch bundleIdentifier {
            case "com.apple.Safari":
                .safari
            case "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.dev", "com.google.Chrome.canary":
                .chrome
            default:
                nil
            }
        }
    }

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

        // Browsers have several Command-N actions in their accessibility trees.
        // Prefer the actual New Window item so a missing layout window is not
        // mistaken for a tab, profile, or document action.
        if let strategy = BrowserRestoreStrategy.forBundleIdentifier(bundleIdentifier),
           pressBrowserNewWindowMenuItem(for: runningApp, strategy: strategy) {
            return
        }
        if pressNewWindowMenuItem(for: runningApp) {
            return
        }
        try await open(bundleIdentifier: bundleIdentifier, activates: false)
    }

    private func pressBrowserNewWindowMenuItem(
        for app: NSRunningApplication,
        strategy: BrowserRestoreStrategy
    ) -> Bool {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard
            let menuBar = axElementValue(appElement, attribute: kAXMenuBarAttribute),
            let menuItem = findBrowserNewWindowMenuItem(in: menuBar, strategy: strategy, remainingDepth: 6)
        else {
            return false
        }
        return AXUIElementPerformAction(menuItem, kAXPressAction as CFString) == .success
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

    private func findBrowserNewWindowMenuItem(
        in element: AXUIElement,
        strategy: BrowserRestoreStrategy,
        remainingDepth: Int
    ) -> AXUIElement? {
        guard remainingDepth >= 0 else { return nil }
        let title = axStringValue(element, attribute: kAXTitleAttribute)
        let character = axStringValue(element, attribute: kAXMenuItemCmdCharAttribute)
        let modifiers = axUInt32Value(element, attribute: kAXMenuItemCmdModifiersAttribute) ?? 0
        let enabled = axBoolValue(element, attribute: kAXEnabledAttribute) ?? true
        if Self.isBrowserNewWindowMenuItem(
            title: title,
            character: character,
            modifiers: modifiers,
            enabled: enabled,
            strategy: strategy
        ) {
            return element
        }

        for child in axElementsValue(element, attribute: kAXChildrenAttribute) {
            if let match = findBrowserNewWindowMenuItem(in: child, strategy: strategy, remainingDepth: remainingDepth - 1) {
                return match
            }
        }
        return nil
    }

    static func isNewWindowShortcut(character: String, modifiers: UInt32, enabled: Bool) -> Bool {
        enabled && character.caseInsensitiveCompare("n") == .orderedSame && modifiers == 0
    }

    static func isBrowserNewWindowMenuItem(
        title: String,
        character: String,
        modifiers: UInt32,
        enabled: Bool,
        strategy: BrowserRestoreStrategy
    ) -> Bool {
        guard isNewWindowShortcut(character: character, modifiers: modifiers, enabled: enabled) else {
            return false
        }
        let normalizedTitle = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        switch strategy {
        case .safari, .chrome:
            return ["new window", "nueva ventana", "nova finestra", "nouvelle fenetre", "neues fenster"]
                .contains(normalizedTitle)
        }
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

enum BrowserTabManagerError: LocalizedError {
    case automationPermissionDenied
    case automationFailed(String)

    var errorDescription: String? {
        switch self {
        case .automationPermissionDenied:
            L10n.tr("Browser Automation access is denied. Enable Settle for Safari or Chrome in System Settings.")
        case .automationFailed(let message):
            L10n.format("Browser tabs could not be saved: %@", message)
        }
    }
}

struct BrowserTabManager {
    static func supports(bundleIdentifier: String) -> Bool {
        AppLauncher.BrowserRestoreStrategy.forBundleIdentifier(bundleIdentifier) != nil
    }

    func captureWindows(bundleIdentifier: String) throws -> [BrowserWindowTabs] {
        let output = try run(script: captureScript(bundleIdentifier: bundleIdentifier))
        return Self.parseCapturedWindows(output)
    }

    static func parseCapturedWindows(_ output: String) -> [BrowserWindowTabs] {
        let groupedTabs = output
            .split(separator: "\n")
            .compactMap { line -> (Int, BrowserTab)? in
                let columns = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
                guard columns.count == 2, let windowIndex = Int(columns[0]), !columns[1].isEmpty else { return nil }
                return (windowIndex, BrowserTab(url: String(columns[1])))
            }
            .reduce(into: [Int: [BrowserTab]]()) { result, item in
                result[item.0, default: []].append(item.1)
            }
        return groupedTabs.keys.sorted().compactMap { index in
            guard let tabs = groupedTabs[index], !tabs.isEmpty else { return nil }
            return BrowserWindowTabs(tabs: tabs)
        }
    }

    func restoreWindows(_ windows: [BrowserWindowTabs], bundleIdentifier: String) throws {
        guard !windows.isEmpty else { return }
        try run(script: restoreScript(windows: windows, bundleIdentifier: bundleIdentifier))
    }

    func restoreExistingWindows(_ windows: [BrowserWindowTabs], bundleIdentifier: String) throws {
        guard !windows.isEmpty else { return }
        try run(script: restoreExistingWindowsScript(windows: windows, bundleIdentifier: bundleIdentifier))
    }

    private func run(script source: String) throws -> String {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            if error[NSAppleScript.errorNumber] as? Int == Int(errAEEventNotPermitted) {
                throw BrowserTabManagerError.automationPermissionDenied
            }
            throw BrowserTabManagerError.automationFailed(
                error[NSAppleScript.errorMessage] as? String ?? L10n.tr("Automation permission was not granted.")
            )
        }
        return result?.stringValue ?? ""
    }

    private func captureScript(bundleIdentifier: String) -> String {
        let windowBody: String
        if AppLauncher.BrowserRestoreStrategy.forBundleIdentifier(bundleIdentifier) == .chrome {
            windowBody = """
            if (mode of currentWindow as text) is \"normal\" then
                repeat with currentTab in tabs of currentWindow
                    set capturedTabs to capturedTabs & windowIndex & (ASCII character 9) & URL of currentTab & linefeed
                end repeat
            end if
            """
        } else {
            windowBody = """
            repeat with currentTab in tabs of currentWindow
                set capturedTabs to capturedTabs & windowIndex & (ASCII character 9) & URL of currentTab & linefeed
            end repeat
            """
        }
        return """
        tell application id \"\(bundleIdentifier)\"
            set capturedTabs to \"\"
            repeat with windowIndex from 1 to count of windows
                set currentWindow to window windowIndex
                \(windowBody)
            end repeat
            return capturedTabs
        end tell
        """
    }

    private func restoreScript(windows: [BrowserWindowTabs], bundleIdentifier: String) -> String {
        let commands = windows.compactMap { window -> String? in
            guard let firstTab = window.tabs.first else { return nil }
            let remainingTabs = window.tabs.dropFirst().map { tab in
                "make new tab at end of tabs of front window with properties {URL:\(quoted(tab.url))}"
            }.joined(separator: "\n")
            switch AppLauncher.BrowserRestoreStrategy.forBundleIdentifier(bundleIdentifier) {
            case .safari:
                return "make new document with properties {URL:\(quoted(firstTab.url))}\n\(remainingTabs)"
            case .chrome:
                return "set newWindow to make new window\nset URL of active tab of newWindow to \(quoted(firstTab.url))\n" + window.tabs.dropFirst().map { tab in
                    "make new tab at end of tabs of newWindow with properties {URL:\(quoted(tab.url))}"
                }.joined(separator: "\n")
            case nil:
                return nil
            }
        }.joined(separator: "\n")
        return "tell application id \"\(bundleIdentifier)\"\nlaunch\n\(commands)\nend tell"
    }

    private func restoreExistingWindowsScript(windows: [BrowserWindowTabs], bundleIdentifier: String) -> String {
        let commands = windows.enumerated().compactMap { offset, window -> String? in
            guard let firstTab = window.tabs.first else { return nil }
            let additionalTabs = window.tabs.dropFirst().map { tab in
                "make new tab at end of tabs of targetWindow with properties {URL:\(quoted(tab.url))}"
            }.joined(separator: "\n")
            let common = """
            set targetWindow to window \(offset + 1)
            repeat while (count of tabs of targetWindow) > 1
                close last tab of targetWindow
            end repeat
            """
            switch AppLauncher.BrowserRestoreStrategy.forBundleIdentifier(bundleIdentifier) {
            case .safari:
                return "\(common)\nset URL of current tab of targetWindow to \(quoted(firstTab.url))\n\(additionalTabs)"
            case .chrome:
                return "\(common)\nset URL of active tab of targetWindow to \(quoted(firstTab.url))\n\(additionalTabs)"
            case nil:
                return nil
            }
        }.joined(separator: "\n")
        return "tell application id \"\(bundleIdentifier)\"\n\(commands)\nend tell"
    }

    private func quoted(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\\\", with: "\\\\\\\\").replacingOccurrences(of: "\"", with: "\\\\\""))\""
    }
}
