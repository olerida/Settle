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

enum LayoutSwitcherAction: CaseIterable, Hashable {
    case closeActiveLayout
    case closeOtherWindows
    case minimizeOtherWindows
    case updateActiveLayout
    case restoreActiveLayout
}

struct LayoutSwitcherActionShortcut: Codable, Equatable {
    var keyCode: UInt32
    var keyLabel: String

    func displayString(with switcherShortcut: LayoutSwitcherShortcut?) -> String {
        guard let switcherShortcut else { return keyLabel }
        return "\(switcherShortcut.displayString)+\(keyLabel)"
    }
}

struct LayoutSwitcherActionShortcuts: Codable, Equatable {
    var closeActiveLayout: LayoutSwitcherActionShortcut
    var closeOtherWindows: LayoutSwitcherActionShortcut
    var minimizeOtherWindows: LayoutSwitcherActionShortcut
    var updateActiveLayout: LayoutSwitcherActionShortcut
    var restoreActiveLayout: LayoutSwitcherActionShortcut

    private enum CodingKeys: String, CodingKey {
        case closeActiveLayout
        case closeOtherWindows
        case minimizeOtherWindows
        case updateActiveLayout
        case restoreActiveLayout
    }

    init(
        closeActiveLayout: LayoutSwitcherActionShortcut,
        closeOtherWindows: LayoutSwitcherActionShortcut,
        minimizeOtherWindows: LayoutSwitcherActionShortcut,
        updateActiveLayout: LayoutSwitcherActionShortcut,
        restoreActiveLayout: LayoutSwitcherActionShortcut
    ) {
        self.closeActiveLayout = closeActiveLayout
        self.closeOtherWindows = closeOtherWindows
        self.minimizeOtherWindows = minimizeOtherWindows
        self.updateActiveLayout = updateActiveLayout
        self.restoreActiveLayout = restoreActiveLayout
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.defaultShortcuts
        closeActiveLayout = try container.decode(LayoutSwitcherActionShortcut.self, forKey: .closeActiveLayout)
        closeOtherWindows = try container.decode(LayoutSwitcherActionShortcut.self, forKey: .closeOtherWindows)
        minimizeOtherWindows = try container.decode(LayoutSwitcherActionShortcut.self, forKey: .minimizeOtherWindows)
        updateActiveLayout = try container.decodeIfPresent(
            LayoutSwitcherActionShortcut.self,
            forKey: .updateActiveLayout
        ) ?? defaults.updateActiveLayout
        restoreActiveLayout = try container.decodeIfPresent(
            LayoutSwitcherActionShortcut.self,
            forKey: .restoreActiveLayout
        ) ?? defaults.restoreActiveLayout
    }

    static let defaultShortcuts = LayoutSwitcherActionShortcuts(
        closeActiveLayout: LayoutSwitcherActionShortcut(
            keyCode: UInt32(kVK_ANSI_C),
            keyLabel: "C"
        ),
        closeOtherWindows: LayoutSwitcherActionShortcut(
            keyCode: UInt32(kVK_ANSI_K),
            keyLabel: "K"
        ),
        minimizeOtherWindows: LayoutSwitcherActionShortcut(
            keyCode: UInt32(kVK_ANSI_M),
            keyLabel: "M"
        ),
        updateActiveLayout: LayoutSwitcherActionShortcut(
            keyCode: UInt32(kVK_ANSI_U),
            keyLabel: "U"
        ),
        restoreActiveLayout: LayoutSwitcherActionShortcut(
            keyCode: UInt32(kVK_ANSI_R),
            keyLabel: "R"
        )
    )

    private static let migrationFallbacks = [
        LayoutSwitcherActionShortcut(keyCode: UInt32(kVK_ANSI_U), keyLabel: "U"),
        LayoutSwitcherActionShortcut(keyCode: UInt32(kVK_ANSI_R), keyLabel: "R"),
        LayoutSwitcherActionShortcut(keyCode: UInt32(kVK_ANSI_A), keyLabel: "A"),
        LayoutSwitcherActionShortcut(keyCode: UInt32(kVK_ANSI_S), keyLabel: "S"),
        LayoutSwitcherActionShortcut(keyCode: UInt32(kVK_ANSI_D), keyLabel: "D"),
        LayoutSwitcherActionShortcut(keyCode: UInt32(kVK_ANSI_F), keyLabel: "F"),
        LayoutSwitcherActionShortcut(keyCode: UInt32(kVK_ANSI_G), keyLabel: "G"),
        LayoutSwitcherActionShortcut(keyCode: UInt32(kVK_ANSI_H), keyLabel: "H"),
        LayoutSwitcherActionShortcut(keyCode: UInt32(kVK_ANSI_J), keyLabel: "J"),
        LayoutSwitcherActionShortcut(keyCode: UInt32(kVK_ANSI_L), keyLabel: "L")
    ]

    func resolvingExpandedActionConflicts(
        primaryKeyCode: UInt32?
    ) -> LayoutSwitcherActionShortcuts? {
        let existingShortcuts = [closeActiveLayout, closeOtherWindows, minimizeOtherWindows]
        let existingKeyCodes = existingShortcuts.map(\.keyCode)
        var unavailableKeyCodes = Set(existingKeyCodes)
        unavailableKeyCodes.insert(UInt32(kVK_Escape))
        if let primaryKeyCode {
            unavailableKeyCodes.insert(primaryKeyCode)
        }

        guard Set(existingKeyCodes).count == existingKeyCodes.count,
              !existingKeyCodes.contains(UInt32(kVK_Escape)),
              !existingKeyCodes.contains(where: { $0 == primaryKeyCode }) else {
            return nil
        }

        var resolved = self
        if unavailableKeyCodes.contains(resolved.updateActiveLayout.keyCode) {
            let protectedRestoreKeyCode = unavailableKeyCodes.contains(resolved.restoreActiveLayout.keyCode)
                ? nil
                : resolved.restoreActiveLayout.keyCode
            guard let replacement = Self.migrationFallbacks.first(where: {
                !unavailableKeyCodes.contains($0.keyCode) && $0.keyCode != protectedRestoreKeyCode
            }) else {
                return nil
            }
            resolved.updateActiveLayout = replacement
        }
        unavailableKeyCodes.insert(resolved.updateActiveLayout.keyCode)

        if unavailableKeyCodes.contains(resolved.restoreActiveLayout.keyCode) {
            guard let replacement = Self.migrationFallbacks.first(where: {
                !unavailableKeyCodes.contains($0.keyCode)
            }) else {
                return nil
            }
            resolved.restoreActiveLayout = replacement
        }

        return resolved
    }

    subscript(action: LayoutSwitcherAction) -> LayoutSwitcherActionShortcut {
        get {
            switch action {
            case .closeActiveLayout: closeActiveLayout
            case .closeOtherWindows: closeOtherWindows
            case .minimizeOtherWindows: minimizeOtherWindows
            case .updateActiveLayout: updateActiveLayout
            case .restoreActiveLayout: restoreActiveLayout
            }
        }
        set {
            switch action {
            case .closeActiveLayout: closeActiveLayout = newValue
            case .closeOtherWindows: closeOtherWindows = newValue
            case .minimizeOtherWindows: minimizeOtherWindows = newValue
            case .updateActiveLayout: updateActiveLayout = newValue
            case .restoreActiveLayout: restoreActiveLayout = newValue
            }
        }
    }

    func isValid(primaryKeyCode: UInt32?) -> Bool {
        let keyCodes = LayoutSwitcherAction.allCases.map { self[$0].keyCode }
        return Set(keyCodes).count == keyCodes.count
            && !keyCodes.contains(UInt32(kVK_Escape))
            && !keyCodes.contains(where: { $0 == primaryKeyCode })
    }
}

@MainActor
final class LayoutSwitcherHotKeyManager {
    enum Event {
        case cycle(LayoutSwitcherDirection)
        case perform(LayoutSwitcherAction)
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
    private static let closeActiveLayoutID: UInt32 = 4
    private static let closeOtherWindowsID: UInt32 = 5
    private static let minimizeOtherWindowsID: UInt32 = 6
    private static let updateActiveLayoutID: UInt32 = 7
    private static let restoreActiveLayoutID: UInt32 = 8

    private var forwardReference: EventHotKeyRef?
    private var backwardReference: EventHotKeyRef?
    private var cancelReference: EventHotKeyRef?
    private var actionReferences: [LayoutSwitcherAction: EventHotKeyRef] = [:]
    private var carbonEventHandler: EventHandlerRef?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var currentShortcut: LayoutSwitcherShortcut?
    private var currentActionShortcuts = LayoutSwitcherActionShortcuts.defaultShortcuts
    private var eventHandler: ((Event) -> Void)?
    private var isCycling = false
    private var isSuspended = false
    private var isStarted = false

    func start(
        shortcut: LayoutSwitcherShortcut?,
        actionShortcuts: LayoutSwitcherActionShortcuts = .defaultShortcuts,
        eventHandler: @escaping (Event) -> Void
    ) throws {
        self.eventHandler = eventHandler
        guard !isStarted else {
            try apply(shortcut: shortcut, actionShortcuts: actionShortcuts)
            return
        }

        isStarted = true
        try installCarbonEventHandler()
        installEventMonitors()
        try apply(shortcut: shortcut, actionShortcuts: actionShortcuts)
    }

    func apply(
        shortcut: LayoutSwitcherShortcut?,
        actionShortcuts: LayoutSwitcherActionShortcuts
    ) throws {
        guard actionShortcuts.isValid(primaryKeyCode: shortcut?.keyCode) else {
            throw RegistrationError.unavailable
        }
        let previousShortcut = currentShortcut
        let previousActionShortcuts = currentActionShortcuts
        unregisterHotKeys()
        currentShortcut = shortcut
        currentActionShortcuts = actionShortcuts

        do {
            if !isSuspended {
                try registerCurrentShortcut()
            }
            try validateActionShortcutAvailability()
        } catch {
            unregisterHotKeys()
            currentShortcut = previousShortcut
            currentActionShortcuts = previousActionShortcuts
            if !isSuspended {
                try? registerCurrentShortcut()
            }
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
        do {
            try registerCurrentShortcut()
            try validateActionShortcutAvailability()
        } catch {
            unregisterHotKeys()
            isSuspended = true
            throw error
        }
    }

    func cancelCycle() {
        guard isCycling else { return }
        isCycling = false
        unregisterCyclingHotKeys()
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

    private func validateActionShortcutAvailability() throws {
        guard let shortcut = currentShortcut else { return }
        var temporaryReferences: [EventHotKeyRef] = []
        defer {
            for reference in temporaryReferences {
                UnregisterEventHotKey(reference)
            }
        }

        for action in LayoutSwitcherAction.allCases {
            let actionID = EventHotKeyID(signature: Self.signature, id: hotKeyID(for: action))
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(
                currentActionShortcuts[action].keyCode,
                shortcut.modifier.carbonValue,
                actionID,
                GetApplicationEventTarget(),
                0,
                &reference
            )
            guard status == noErr, let reference else {
                throw RegistrationError.unavailable
            }
            temporaryReferences.append(reference)
        }
    }

    private func unregisterHotKeys() {
        unregisterCyclingHotKeys()
        if let forwardReference {
            UnregisterEventHotKey(forwardReference)
            self.forwardReference = nil
        }
        if let backwardReference {
            UnregisterEventHotKey(backwardReference)
            self.backwardReference = nil
        }
    }

    private func registerCyclingHotKeys() {
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

        for action in LayoutSwitcherAction.allCases {
            let actionID = EventHotKeyID(signature: Self.signature, id: hotKeyID(for: action))
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(
                currentActionShortcuts[action].keyCode,
                shortcut.modifier.carbonValue,
                actionID,
                GetApplicationEventTarget(),
                0,
                &reference
            )
            if status == noErr, let reference {
                actionReferences[action] = reference
            }
        }
    }

    private func unregisterCyclingHotKeys() {
        if let cancelReference {
            UnregisterEventHotKey(cancelReference)
            self.cancelReference = nil
        }
        for reference in actionReferences.values {
            UnregisterEventHotKey(reference)
        }
        actionReferences.removeAll()
    }

    private func hotKeyID(for action: LayoutSwitcherAction) -> UInt32 {
        switch action {
        case .closeActiveLayout: Self.closeActiveLayoutID
        case .closeOtherWindows: Self.closeOtherWindowsID
        case .minimizeOtherWindows: Self.minimizeOtherWindowsID
        case .updateActiveLayout: Self.updateActiveLayoutID
        case .restoreActiveLayout: Self.restoreActiveLayoutID
        }
    }

    private func action(for hotKeyID: UInt32) -> LayoutSwitcherAction? {
        switch hotKeyID {
        case Self.closeActiveLayoutID: .closeActiveLayout
        case Self.closeOtherWindowsID: .closeOtherWindows
        case Self.minimizeOtherWindowsID: .minimizeOtherWindows
        case Self.updateActiveLayoutID: .updateActiveLayout
        case Self.restoreActiveLayoutID: .restoreActiveLayout
        default: nil
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
            if !isCycling { registerCyclingHotKeys() }
            isCycling = true
            eventHandler?(.cycle(.forward))
        case Self.backwardID:
            if !isCycling { registerCyclingHotKeys() }
            isCycling = true
            eventHandler?(.cycle(.backward))
        case Self.cancelID where isCycling:
            isCycling = false
            unregisterCyclingHotKeys()
            eventHandler?(.cancel)
        case let id where isCycling:
            guard let action = action(for: id) else {
                return OSStatus(eventNotHandledErr)
            }
            isCycling = false
            unregisterCyclingHotKeys()
            eventHandler?(.perform(action))
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
            unregisterCyclingHotKeys()
            eventHandler?(.cancel)
            return true
        }

        if event.type == .flagsChanged,
           !event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(shortcut.modifier.eventFlag) {
            isCycling = false
            unregisterCyclingHotKeys()
            eventHandler?(.activate)
        }
        return false
    }
}

struct LayoutSwitcherActionShortcutRecorder: NSViewRepresentable {
    let shortcut: LayoutSwitcherActionShortcut
    let switcherShortcut: LayoutSwitcherShortcut?
    let accessibilityLabel: String
    let onChange: (LayoutSwitcherActionShortcut) -> Void
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
        view.switcherShortcut = switcherShortcut
        view.recorderAccessibilityLabel = accessibilityLabel
        view.onChange = onChange
        view.onInvalid = onInvalid
        view.onRecordingChanged = onRecordingChanged
        view.needsDisplay = true
    }

    final class RecorderView: NSView {
        var shortcut = LayoutSwitcherActionShortcuts.defaultShortcuts.closeActiveLayout
        var switcherShortcut: LayoutSwitcherShortcut?
        var recorderAccessibilityLabel = ""
        var onChange: ((LayoutSwitcherActionShortcut) -> Void)?
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
            let disallowedModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
            guard event.modifierFlags.intersection(disallowedModifiers).isEmpty,
                  let keyLabel = LayoutSwitcherKeyLabel.label(for: event) else {
                NSSound.beep()
                onInvalid?()
                return
            }

            onChange?(
                LayoutSwitcherActionShortcut(
                    keyCode: UInt32(event.keyCode),
                    keyLabel: keyLabel
                )
            )
            window?.makeFirstResponder(nil)
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            LayoutSwitcherRecorderDrawing.draw(
                in: self,
                text: window?.firstResponder === self
                    ? L10n.tr("Press key")
                    : shortcut.displayString(with: switcherShortcut)
            )
        }

        override func accessibilityLabel() -> String? {
            recorderAccessibilityLabel
        }

        override func accessibilityValue() -> Any? {
            shortcut.displayString(with: switcherShortcut)
        }
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
                  let keyLabel = LayoutSwitcherKeyLabel.label(for: event) else {
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
            LayoutSwitcherRecorderDrawing.draw(
                in: self,
                text: window?.firstResponder === self
                    ? L10n.tr("Press shortcut")
                    : shortcut?.displayString ?? L10n.tr("Disabled")
            )
        }

        override func accessibilityLabel() -> String? {
            L10n.tr("Layout switcher shortcut")
        }

        override func accessibilityValue() -> Any? {
            shortcut?.displayString ?? L10n.tr("Disabled")
        }

    }
}

@MainActor
private enum LayoutSwitcherRecorderDrawing {
    static func draw(in view: NSView, text: String) {
        let rect = view.bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
        NSColor.controlBackgroundColor.withAlphaComponent(0.72).setFill()
        path.fill()
        (view.window?.firstResponder === view ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = view.window?.firstResponder === view ? 2 : 1
        path.stroke()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(x: (view.bounds.width - size.width) / 2, y: (view.bounds.height - size.height) / 2),
            withAttributes: attributes
        )
    }
}

private enum LayoutSwitcherKeyLabel {
    static func label(for event: NSEvent) -> String? {
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
