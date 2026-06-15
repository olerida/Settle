@preconcurrency import ApplicationServices
import Foundation

@MainActor
final class AccessibilityPermissionManager: ObservableObject {
    @Published private(set) var isTrusted: Bool = false

    init() {
        refresh()
    }

    func refresh() {
        isTrusted = AXIsProcessTrusted()
    }

    func requestIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        refresh()
    }
}
