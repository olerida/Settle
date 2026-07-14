import AppKit
import Carbon
import SwiftUI

enum LayoutSwitcherDirection: Equatable {
    case forward
    case backward
}

enum LayoutSwitcherModifier: String, Codable, CaseIterable {
    case option
    case control
    case command

    var symbol: String {
        switch self {
        case .option: "⌥"
        case .control: "⌃"
        case .command: "⌘"
        }
    }

    var carbonValue: UInt32 {
        switch self {
        case .option: UInt32(optionKey)
        case .control: UInt32(controlKey)
        case .command: UInt32(cmdKey)
        }
    }

    var eventFlag: NSEvent.ModifierFlags {
        switch self {
        case .option: .option
        case .control: .control
        case .command: .command
        }
    }
}

struct LayoutSwitcherShortcut: Codable, Equatable {
    var modifier: LayoutSwitcherModifier
    var keyCode: UInt32
    var keyLabel: String

    static let defaultShortcut = LayoutSwitcherShortcut(
        modifier: .option,
        keyCode: UInt32(kVK_Tab),
        keyLabel: "Tab"
    )

    var displayString: String {
        modifier.symbol + keyLabel
    }
}

@MainActor
final class LayoutSwitcherHotKeyManager {
    enum Event {
        case cycle(LayoutSwitcherDirection)
        case activate
        case cancel
    }

    enum RegistrationError: Error {
        case unavailable
    }

    private static let signature: OSType = 0x53544C45 // STLE
    private static let forwardID: UInt32 = 1
    private static let backwardID: UInt32 = 2
    private static let cancelID: UInt32 = 3

    private var forwardReference: EventHotKeyRef?
    private var backwardReference: EventHotKeyRef?
    private var cancelReference: EventHotKeyRef?
    private var carbonEventHandler: EventHandlerRef?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var currentShortcut: LayoutSwitcherShortcut?
    private var eventHandler: ((Event) -> Void)?
    private var isCycling = false
    private var isSuspended = false
    private var isStarted = false

    func start(
        shortcut: LayoutSwitcherShortcut?,
        eventHandler: @escaping (Event) -> Void
    ) throws {
        self.eventHandler = eventHandler
        guard !isStarted else {
            try apply(shortcut)
            return
        }

        isStarted = true
        try installCarbonEventHandler()
        installEventMonitors()
        try apply(shortcut)
    }

    func apply(_ shortcut: LayoutSwitcherShortcut?) throws {
        let previousShortcut = currentShortcut
        unregisterHotKeys()
        currentShortcut = shortcut

        guard !isSuspended else { return }

        do {
            try registerCurrentShortcut()
        } catch {
            currentShortcut = previousShortcut
            try? registerCurrentShortcut()
            throw error
        }
    }

    func suspend() {
        guard !isSuspended else { return }
        isSuspended = true
        unregisterHotKeys()
        cancelCycle()
    }

    func resume() throws {
        guard isSuspended else { return }
        isSuspended = false
        try registerCurrentShortcut()
    }

    func cancelCycle() {
        guard isCycling else { return }
        isCycling = false
        unregisterCancelHotKey()
        eventHandler?(.cancel)
    }

    func stop() {
        unregisterHotKeys()
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        if let carbonEventHandler {
            RemoveEventHandler(carbonEventHandler)
            self.carbonEventHandler = nil
        }
        isCycling = false
        isStarted = false
        eventHandler = nil
    }

    private func installCarbonEventHandler() throws {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return OSStatus(eventNotHandledErr)
                }
                let manager = Unmanaged<LayoutSwitcherHotKeyManager>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                return MainActor.assumeIsolated {
                    manager.handleCarbonEvent(event)
                }
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &carbonEventHandler
        )
        guard status == noErr else {
            throw RegistrationError.unavailable
        }
    }

    private func installEventMonitors() {
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.flagsChanged, .keyDown]
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleMonitoredEvent(event)
            }
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.flagsChanged, .keyDown]
        ) { [weak self] event in
            let shouldConsumeEscape = MainActor.assumeIsolated {
                self?.handleMonitoredEvent(event) ?? false
            }
            return shouldConsumeEscape ? nil : event
        }
    }

    private func registerCurrentShortcut() throws {
        guard let shortcut = currentShortcut, !isSuspended else { return }

        let forwardID = EventHotKeyID(signature: Self.signature, id: Self.forwardID)
        let forwardStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifier.carbonValue,
            forwardID,
            GetApplicationEventTarget(),
            0,
            &forwardReference
        )
        guard forwardStatus == noErr, forwardReference != nil else {
            unregisterHotKeys()
            throw RegistrationError.unavailable
        }

        let backwardID = EventHotKeyID(signature: Self.signature, id: Self.backwardID)
        let backwardStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifier.carbonValue | UInt32(shiftKey),
            backwardID,
            GetApplicationEventTarget(),
            0,
            &backwardReference
        )
        guard backwardStatus == noErr, backwardReference != nil else {
            unregisterHotKeys()
            throw RegistrationError.unavailable
        }
    }

    private func unregisterHotKeys() {
        unregisterCancelHotKey()
        if let forwardReference {
            UnregisterEventHotKey(forwardReference)
            self.forwardReference = nil
        }
        if let backwardReference {
            UnregisterEventHotKey(backwardReference)
            self.backwardReference = nil
        }
    }

    private func registerCancelHotKey() {
        guard cancelReference == nil,
              let shortcut = currentShortcut else { return }

        let cancelID = EventHotKeyID(signature: Self.signature, id: Self.cancelID)
        RegisterEventHotKey(
            UInt32(kVK_Escape),
            shortcut.modifier.carbonValue,
            cancelID,
            GetApplicationEventTarget(),
            0,
            &cancelReference
        )
    }

    private func unregisterCancelHotKey() {
        if let cancelReference {
            UnregisterEventHotKey(cancelReference)
            self.cancelReference = nil
        }
    }

    private func handleCarbonEvent(_ event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID(signature: 0, id: 0)
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr, hotKeyID.signature == Self.signature else {
            return OSStatus(eventNotHandledErr)
        }

        switch hotKeyID.id {
        case Self.forwardID:
            if !isCycling { registerCancelHotKey() }
            isCycling = true
            eventHandler?(.cycle(.forward))
        case Self.backwardID:
            if !isCycling { registerCancelHotKey() }
            isCycling = true
            eventHandler?(.cycle(.backward))
        case Self.cancelID where isCycling:
            isCycling = false
            unregisterCancelHotKey()
            eventHandler?(.cancel)
        default:
            return OSStatus(eventNotHandledErr)
        }
        return noErr
    }

    @discardableResult
    private func handleMonitoredEvent(_ event: NSEvent) -> Bool {
        guard isCycling, let shortcut = currentShortcut else { return false }

        if event.type == .keyDown, event.keyCode == UInt16(kVK_Escape) {
            isCycling = false
            unregisterCancelHotKey()
            eventHandler?(.cancel)
            return true
        }

        if event.type == .flagsChanged,
           !event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(shortcut.modifier.eventFlag) {
            isCycling = false
            unregisterCancelHotKey()
            eventHandler?(.activate)
        }
        return false
    }
}

struct LayoutSwitcherShortcutRecorder: NSViewRepresentable {
    let shortcut: LayoutSwitcherShortcut?
    let onChange: (LayoutSwitcherShortcut) -> Void
    let onInvalid: () -> Void
    let onRecordingChanged: (Bool) -> Void

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.setAccessibilityRole(.button)
        update(view)
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        update(nsView)
    }

    private func update(_ view: RecorderView) {
        view.shortcut = shortcut
        view.onChange = onChange
        view.onInvalid = onInvalid
        view.onRecordingChanged = onRecordingChanged
        view.needsDisplay = true
    }

    final class RecorderView: NSView {
        var shortcut: LayoutSwitcherShortcut?
        var onChange: ((LayoutSwitcherShortcut) -> Void)?
        var onInvalid: (() -> Void)?
        var onRecordingChanged: ((Bool) -> Void)?

        override var acceptsFirstResponder: Bool { true }
        override var intrinsicContentSize: NSSize { NSSize(width: 150, height: 30) }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
        }

        override func accessibilityPerformPress() -> Bool {
            window?.makeFirstResponder(self)
            return true
        }

        override func becomeFirstResponder() -> Bool {
            let result = super.becomeFirstResponder()
            if result {
                onRecordingChanged?(true)
                needsDisplay = true
            }
            return result
        }

        override func resignFirstResponder() -> Bool {
            let result = super.resignFirstResponder()
            if result {
                onRecordingChanged?(false)
                needsDisplay = true
            }
            return result
        }

        override func keyDown(with event: NSEvent) {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let modifiers = LayoutSwitcherModifier.allCases.filter { flags.contains($0.eventFlag) }
            guard modifiers.count == 1, !flags.contains(.shift), let modifier = modifiers.first,
                  let keyLabel = Self.keyLabel(for: event) else {
                NSSound.beep()
                onInvalid?()
                return
            }

            let shortcut = LayoutSwitcherShortcut(
                modifier: modifier,
                keyCode: UInt32(event.keyCode),
                keyLabel: keyLabel
            )
            onChange?(shortcut)
            window?.makeFirstResponder(nil)
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
            let path = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
            (NSColor.controlBackgroundColor.withAlphaComponent(0.72)).setFill()
            path.fill()
            (window?.firstResponder === self ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
            path.lineWidth = window?.firstResponder === self ? 2 : 1
            path.stroke()

            let text = window?.firstResponder === self
                ? L10n.tr("Press shortcut")
                : shortcut?.displayString ?? L10n.tr("Disabled")
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]
            let size = text.size(withAttributes: attributes)
            text.draw(
                at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2),
                withAttributes: attributes
            )
        }

        override func accessibilityLabel() -> String? {
            L10n.tr("Layout switcher shortcut")
        }

        override func accessibilityValue() -> Any? {
            shortcut?.displayString ?? L10n.tr("Disabled")
        }

        private static func keyLabel(for event: NSEvent) -> String? {
            let specialKeys: [UInt16: String] = [
                UInt16(kVK_Tab): "Tab",
                UInt16(kVK_Space): "Space",
                UInt16(kVK_Return): "Return",
                UInt16(kVK_ANSI_KeypadEnter): "Enter",
                UInt16(kVK_Escape): "Esc",
                UInt16(kVK_Delete): "Delete",
                UInt16(kVK_ForwardDelete): "Forward Delete",
                UInt16(kVK_LeftArrow): "←",
                UInt16(kVK_RightArrow): "→",
                UInt16(kVK_UpArrow): "↑",
                UInt16(kVK_DownArrow): "↓",
                UInt16(kVK_Home): "Home",
                UInt16(kVK_End): "End",
                UInt16(kVK_PageUp): "Page Up",
                UInt16(kVK_PageDown): "Page Down",
                UInt16(kVK_F1): "F1",
                UInt16(kVK_F2): "F2",
                UInt16(kVK_F3): "F3",
                UInt16(kVK_F4): "F4",
                UInt16(kVK_F5): "F5",
                UInt16(kVK_F6): "F6",
                UInt16(kVK_F7): "F7",
                UInt16(kVK_F8): "F8",
                UInt16(kVK_F9): "F9",
                UInt16(kVK_F10): "F10",
                UInt16(kVK_F11): "F11",
                UInt16(kVK_F12): "F12"
            ]
            if let label = specialKeys[event.keyCode] {
                return label
            }
            guard let characters = event.charactersIgnoringModifiers?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !characters.isEmpty else {
                return nil
            }
            return characters.uppercased()
        }
    }
}
