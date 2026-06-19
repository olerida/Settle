import AppKit
import SwiftUI

@MainActor
enum AppSession {
    static let coordinator = LayoutCoordinator()
}

@MainActor
final class MenuBarAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let coordinator = AppSession.coordinator
    private var statusItem: NSStatusItem!
    private var panel: MenuBarPanel!
    private var hostingView: NSHostingView<AnyView>!
    private var eventMonitor: Any?
    private var resizeAnchor: CGPoint?
    private var isAdjustingResize = false

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
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 620),
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
        panel.minSize = NSSize(width: 430, height: 520)
        panel.maxSize = NSSize(width: 430, height: 1200)

        for buttonType in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(buttonType)?.isHidden = true
        }

        hostingView = NSHostingView(rootView: AnyView(MenuContentView().environmentObject(coordinator)))
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
        var panelFrame = panel.frame

        panelFrame.origin.x = round(screenFrame.maxX - panelFrame.width)
        panelFrame.origin.y = round(screenFrame.minY - panelFrame.height - 8)

        if let screen = buttonWindow.screen ?? NSScreen.main {
            let visibleFrame = screen.visibleFrame
            panelFrame.origin.x = max(visibleFrame.minX + 8, min(panelFrame.origin.x, visibleFrame.maxX - panelFrame.width - 8))
            panelFrame.origin.y = max(visibleFrame.minY + 8, panelFrame.origin.y)
        }

        panel.setFrame(panelFrame, display: true)
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak panel] in
            guard let panel else { return }
            panel.makeFirstResponder(panel.contentView)
        }
        NSApp.activate(ignoringOtherApps: true)
        installEventMonitor()
    }

    private func closePanel() {
        panel.orderOut(nil)
        removeEventMonitor()
    }

    func windowDidResignKey(_ notification: Notification) {
        closePanel()
    }

    func windowWillStartLiveResize(_ notification: Notification) {
        guard let panel, notification.object as? NSWindow === panel else { return }
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
        frame.size.width = 430
        frame.origin.x = resizeAnchor?.x ?? frame.origin.x
        frame.origin.y = (resizeAnchor?.y ?? frame.maxY) - frame.height
        panel.setFrame(frame, display: true)
        resizeAnchor = nil
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
