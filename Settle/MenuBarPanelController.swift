import AppKit
import SwiftUI

@MainActor
enum AppSession {
    static let coordinator = LayoutCoordinator()
}

@MainActor
final class MenuBarAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private static let panelWidth: CGFloat = 430
    private static let minimumPanelHeight: CGFloat = 520
    private static let maximumScreenHeightRatio: CGFloat = 0.75

    private let coordinator = AppSession.coordinator
    private var statusItem: NSStatusItem!
    private var panel: MenuBarPanel!
    private var hostingView: NSHostingView<AnyView>!
    private var eventMonitor: Any?
    private var resizeAnchor: CGPoint?
    private var isAdjustingResize = false
    private var isLiveResizing = false
    private var hasManualHeightOverride = false
    private var preferredPanelHeight: CGFloat = 620
    private var preferredResizeTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configurePanel()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    @objc
    private func togglePanel() {
        if panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        button.image = NSImage(systemSymbolName: "rectangle.split.2x2.fill", accessibilityDescription: "Settle")
        button.image?.isTemplate = true
        button.action = #selector(togglePanel)
        button.target = self
    }

    private func configurePanel() {
        panel = MenuBarPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: preferredPanelHeight),
            styleMask: [.titled, .fullSizeContentView, .resizable, .closable],
            backing: .buffered,
            defer: false
        )
        panel.delegate = self
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.level = .statusBar
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        updatePanelSizeLimits(for: NSScreen.main)

        for buttonType in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(buttonType)?.isHidden = true
        }

        let contentView = MenuContentView { [weak self] preferredHeight in
            self?.preferredPanelHeightDidChange(preferredHeight)
        }
        hostingView = NSHostingView(rootView: AnyView(contentView.environmentObject(coordinator)))
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: panel.contentView?.bounds ?? .zero)
        container.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        panel.contentView = container
    }

    private func showPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }

        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenFrame = buttonWindow.convertToScreen(buttonFrame)
        let screen = buttonWindow.screen ?? NSScreen.main
        updatePanelSizeLimits(for: screen)
        hasManualHeightOverride = false

        var panelFrame = panel.frame
        panelFrame.size.width = Self.panelWidth
        panelFrame.size.height = clampedPanelHeight(preferredPanelHeight, for: screen)

        panelFrame.origin.x = round(screenFrame.maxX - panelFrame.width)
        panelFrame.origin.y = round(screenFrame.minY - panelFrame.height - 8)

        if let screen {
            let visibleFrame = screen.visibleFrame
            panelFrame.origin.x = max(visibleFrame.minX + 8, min(panelFrame.origin.x, visibleFrame.maxX - panelFrame.width - 8))
            panelFrame.origin.y = max(visibleFrame.minY + 8, panelFrame.origin.y)
        }

        panel.setFrame(panelFrame, display: true)
        panel.makeKeyAndOrderFront(nil)
        coordinator.refreshActiveLayoutForCurrentSpace()
        DispatchQueue.main.async { [weak panel] in
            guard let panel else { return }
            panel.makeFirstResponder(panel.contentView)
        }
        NSApp.activate(ignoringOtherApps: true)
        installEventMonitor()
    }

    private func closePanel() {
        preferredResizeTask?.cancel()
        if coordinator.isOverlayPresented {
            coordinator.dismissOverlay()
        }
        panel.orderOut(nil)
        removeEventMonitor()
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let panel, notification.object as? NSWindow === panel else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.panel.isVisible, !self.panel.isKeyWindow else { return }

            if self.coordinator.isOverlayPresented, NSApp.isActive {
                self.panel.makeKeyAndOrderFront(nil)
            } else {
                self.closePanel()
            }
        }
    }

    func windowWillStartLiveResize(_ notification: Notification) {
        guard let panel, notification.object as? NSWindow === panel else { return }
        isLiveResizing = true
        resizeAnchor = CGPoint(x: panel.frame.minX, y: panel.frame.maxY)
    }

    func windowDidResize(_ notification: Notification) {
        guard
            let panel,
            notification.object as? NSWindow === panel,
            let resizeAnchor,
            !isAdjustingResize
        else {
            return
        }

        isAdjustingResize = true
        var frame = panel.frame
        frame.origin.x = resizeAnchor.x
        frame.origin.y = resizeAnchor.y - frame.height
        panel.setFrame(frame, display: true)
        isAdjustingResize = false
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let panel, notification.object as? NSWindow === panel else { return }
        var frame = panel.frame
        frame.size.width = Self.panelWidth
        frame.origin.x = resizeAnchor?.x ?? frame.origin.x
        frame.origin.y = (resizeAnchor?.y ?? frame.maxY) - frame.height
        panel.setFrame(frame, display: true)
        resizeAnchor = nil
        isLiveResizing = false
        hasManualHeightOverride = true
    }

    private func preferredPanelHeightDidChange(_ height: CGFloat) {
        guard height.isFinite, height > 0 else { return }
        preferredPanelHeight = max(Self.minimumPanelHeight, height)

        guard panel.isVisible, !isLiveResizing, !hasManualHeightOverride else { return }
        preferredResizeTask?.cancel()
        preferredResizeTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled else { return }
            self?.resizePanelToPreferredHeight(animated: true)
        }
    }

    private func resizePanelToPreferredHeight(animated: Bool) {
        let screen = statusItem.button?.window?.screen ?? panel.screen ?? NSScreen.main
        updatePanelSizeLimits(for: screen)

        let targetHeight = clampedPanelHeight(preferredPanelHeight, for: screen)
        guard abs(panel.frame.height - targetHeight) > 1 else { return }

        let topEdge = panel.frame.maxY
        var frame = panel.frame
        frame.size = NSSize(width: Self.panelWidth, height: targetHeight)
        frame.origin.y = topEdge - targetHeight

        if let screen {
            frame.origin.y = max(screen.visibleFrame.minY + 8, frame.origin.y)
        }

        panel.setFrame(frame, display: true, animate: animated)
    }

    private func updatePanelSizeLimits(for screen: NSScreen?) {
        let maximumHeight = maximumPanelHeight(for: screen)
        panel.minSize = NSSize(
            width: Self.panelWidth,
            height: min(Self.minimumPanelHeight, maximumHeight)
        )
        panel.maxSize = NSSize(width: Self.panelWidth, height: maximumHeight)
    }

    private func clampedPanelHeight(_ height: CGFloat, for screen: NSScreen?) -> CGFloat {
        let maximumHeight = maximumPanelHeight(for: screen)
        let minimumHeight = min(Self.minimumPanelHeight, maximumHeight)
        return min(max(height, minimumHeight), maximumHeight)
    }

    private func maximumPanelHeight(for screen: NSScreen?) -> CGFloat {
        floor((screen?.visibleFrame.height ?? 800) * Self.maximumScreenHeightRatio)
    }

    private func installEventMonitor() {
        removeEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePanel()
            }
        }
    }

    private func removeEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}

final class MenuBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        if AppSession.coordinator.isOverlayPresented {
            AppSession.coordinator.dismissOverlay()
            return
        }

        super.cancelOperation(sender)
    }
}
