import AppKit
import SwiftUI

struct LayoutSwitcherItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let snapshotURL: URL?
}

enum LayoutSwitcherSelection {
    static func nextIndex(
        from currentIndex: Int?,
        count: Int,
        direction: LayoutSwitcherDirection
    ) -> Int? {
        guard count > 0 else { return nil }
        guard let currentIndex, (0..<count).contains(currentIndex) else {
            return direction == .forward ? 0 : count - 1
        }
        switch direction {
        case .forward:
            return (currentIndex + 1) % count
        case .backward:
            return (currentIndex - 1 + count) % count
        }
    }
}

enum LayoutSwitcherActiveOrder {
    static func orderedIDs(
        recentlyActiveIDs: [UUID],
        rememberedIDs: Set<UUID>,
        currentID: UUID?,
        availableIDs: [UUID]
    ) -> [UUID] {
        let availableIDSet = Set(availableIDs)
        var orderedIDs = recentlyActiveIDs.filter {
            rememberedIDs.contains($0) && availableIDSet.contains($0)
        }
        for id in availableIDs where rememberedIDs.contains(id) && !orderedIDs.contains(id) {
            orderedIDs.append(id)
        }
        if let currentID, availableIDSet.contains(currentID) {
            orderedIDs.removeAll { $0 == currentID }
            orderedIDs.insert(currentID, at: 0)
        }
        return orderedIDs
    }
}

@MainActor
final class LayoutSwitcherController {
    private let model = LayoutSwitcherModel()
    private var panel: LayoutSwitcherPanel?
    private var hostingView: NSHostingView<LayoutSwitcherOverlay>?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func show(
        items: [LayoutSwitcherItem],
        selectedID: UUID,
        shortcut: LayoutSwitcherShortcut
    ) {
        model.items = items
        model.selectedID = selectedID
        model.shortcut = shortcut

        let panel = panel ?? makePanel()
        position(panel, itemCount: items.count)

        guard !panel.isVisible else { return }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func dismiss() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.08
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            DispatchQueue.main.async {
                panel?.orderOut(nil)
                panel?.alphaValue = 1
            }
        })
    }

    private func makePanel() -> LayoutSwitcherPanel {
        let panel = LayoutSwitcherPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovable = false

        let overlay = LayoutSwitcherOverlay(model: model)
        let hostingView = NSHostingView(rootView: overlay)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        panel.contentView = container

        self.panel = panel
        self.hostingView = hostingView
        return panel
    }

    private func position(_ panel: NSPanel, itemCount: Int) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let desiredWidth = CGFloat(max(itemCount, 1)) * 218 + 52
        let width = min(max(desiredWidth, 310), visibleFrame.width - 64)
        let height: CGFloat = 238
        let frame = NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )
        panel.setFrame(frame, display: true)
    }
}

@MainActor
private final class LayoutSwitcherModel: ObservableObject {
    @Published var items: [LayoutSwitcherItem] = []
    @Published var selectedID: UUID?
    @Published var shortcut = LayoutSwitcherShortcut.defaultShortcut
}

private struct LayoutSwitcherOverlay: View {
    @ObservedObject var model: LayoutSwitcherModel
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 12) {
            Text(L10n.tr("Active Layouts"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.82))

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(model.items) { item in
                            LayoutSwitcherCard(
                                item: item,
                                isSelected: item.id == model.selectedID
                            )
                            .id(item.id)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .scrollIndicators(.hidden)
                .onChange(of: model.selectedID) { _, selectedID in
                    guard let selectedID else { return }
                    withAnimation(.easeOut(duration: 0.13)) {
                        proxy.scrollTo(selectedID, anchor: .center)
                    }
                }
            }

            Text(
                L10n.format(
                    "%@ next · Shift previous · Esc cancel",
                    model.shortcut.displayString
                )
            )
            .font(.caption2)
            .foregroundStyle(Color.white.opacity(0.68))
        }
        .padding(16)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14))
        }
        .shadow(color: .black.opacity(0.3), radius: 28, y: 16)
        .scaleEffect(appeared ? 1 : 0.97)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.14)) {
                appeared = true
            }
        }
        .animation(.easeOut(duration: 0.12), value: model.selectedID)
    }
}

private struct LayoutSwitcherCard: View {
    let item: LayoutSwitcherItem
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Group {
                if let image = snapshotImage {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                } else {
                    ZStack {
                        Color.secondary.opacity(0.09)
                        VStack(spacing: 6) {
                            Image(systemName: "rectangle.dashed")
                                .font(.title2)
                            Text(L10n.tr("No snapshot"))
                                .font(.caption2)
                        }
                        .foregroundStyle(Color.white.opacity(0.64))
                    }
                }
            }
            .frame(width: 198, height: 124)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(item.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .frame(width: 214)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.17) : Color.white.opacity(0.045))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.9) : Color.white.opacity(0.07),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .scaleEffect(isSelected ? 1 : 0.975)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var snapshotImage: NSImage? {
        guard let snapshotURL else { return nil }
        return NSImage(contentsOf: snapshotURL)
    }

    private var snapshotURL: URL? {
        item.snapshotURL
    }
}

private final class LayoutSwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
