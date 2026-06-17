import AppKit
import SwiftUI

@MainActor
final class LayoutHUDController {
    private let panel: NSPanel
    private let hostingView: NSHostingView<LayoutHUDView>
    private var hideTask: Task<Void, Never>?

    init() {
        hostingView = NSHostingView(rootView: LayoutHUDView(title: ""))
        panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 88),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.transient, .ignoresCycle, .moveToActiveSpace]
        panel.contentView = hostingView
        panel.alphaValue = 0
    }

    func show(layoutName: String, duration: TimeInterval = 2.4) {
        hideTask?.cancel()

        hostingView.rootView = LayoutHUDView(title: layoutName)
        let fittingSize = hostingView.fittingSize
        let size = CGSize(width: max(220, fittingSize.width), height: max(68, fittingSize.height))
        panel.setContentSize(size)

        if let screen = targetScreen() {
            let frame = screen.visibleFrame
            let origin = CGPoint(
                x: frame.midX - (size.width / 2),
                y: frame.maxY - size.height - 72
            )
            panel.setFrame(CGRect(origin: origin, size: size), display: false)
        }

        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            panel.animator().alphaValue = 1
        }

        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    private func hide() {
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.2
                panel.animator().alphaValue = 0
            },
            completionHandler: { [panel] in
                Task { @MainActor in
                    panel.orderOut(nil)
                }
            }
        )
    }

    private func targetScreen() -> NSScreen? {
        if let mainScreen = NSScreen.main {
            return mainScreen
        }

        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.screens.first
    }
}

private struct LayoutHUDView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 24, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.97))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12))
            )
    }
}
