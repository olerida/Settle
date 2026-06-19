import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MenuContentView: View {
    @EnvironmentObject private var coordinator: LayoutCoordinator
    @State private var draggedPinnedLayoutID: UUID?
    var onPreferredHeightChange: ((CGFloat) -> Void)?

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                header
                permissionBanner
                actionBar
                layoutsList
                footer
            }
            .frame(width: 430)
            .frame(minHeight: 520, maxHeight: .infinity, alignment: .top)
            .padding(14)
            .background(Color(nsColor: .windowBackgroundColor))
            .blur(radius: isOverlayPresented ? 1.5 : 0)
            .disabled(isOverlayPresented)

            if isOverlayPresented {
                Rectangle()
                    .fill(Color.black.opacity(0.14))
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        coordinator.dismissOverlay()
                    }

                overlayPanel
                    .frame(maxWidth: 372)
                    .padding(20)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .onAppear {
            coordinator.refreshPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            coordinator.refreshPermissions()
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: PanelHeightMetricsPreferenceKey.self,
                    value: PanelHeightMetrics(panelHeight: proxy.size.height)
                )
            }
        }
        .onPreferenceChange(PanelHeightMetricsPreferenceKey.self) { metrics in
            let preferredHeight: CGFloat
            if coordinator.layouts.isEmpty {
                preferredHeight = 520
            } else {
                guard metrics.panelHeight > 0, metrics.listViewportHeight > 0, metrics.listContentHeight > 0 else {
                    return
                }
                preferredHeight = max(
                    520,
                    metrics.panelHeight - metrics.listViewportHeight + metrics.listContentHeight
                )
            }
            onPreferredHeightChange?(preferredHeight)
        }
    }

    private var isOverlayPresented: Bool { coordinator.isOverlayPresented }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Settle")
                    .font(.headline)
                Text(L10n.tr("Window layouts for the current desktop"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                Button {
                    coordinator.presentAbout()
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(HeaderIconButtonStyle())
                .accessibilityLabel(L10n.tr("About"))
                .help(L10n.tr("About"))

                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(HeaderIconButtonStyle())
                .accessibilityLabel(L10n.tr("Settings"))
                .help(L10n.tr("Settings"))
            }
        }
    }

    @ViewBuilder
    private var permissionBanner: some View {
        if !coordinator.permissionManager.isTrusted {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr("Accessibility access required"))
                    .font(.subheadline.weight(.semibold))
                Text(L10n.tr("Settle needs Accessibility permission to read, move, and resize windows."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(L10n.tr("If you just enabled it in System Settings and this warning remains, close and reopen the app."))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Button(L10n.tr("Open System Prompt")) {
                    coordinator.requestAccessibilityPermission()
                }
            }
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            Button {
                coordinator.prepareSave()
            } label: {
                Label(L10n.tr("Save Layout"), systemImage: "plus.circle")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(ActionChipButtonStyle(tone: .primary))

            if coordinator.activeRestoredLayout != nil {
                Button {
                    coordinator.minimizeWindowsOutsideActiveLayout()
                } label: {
                    Image(systemName: "rectangle.compress.vertical")
                }
                .buttonStyle(ActionChipButtonStyle())
                .accessibilityLabel(L10n.tr("Minimize Others"))
                .help(L10n.tr("Minimize visible windows that are not part of the active restored layout"))

                Button {
                    coordinator.closeWindowsOutsideActiveLayout()
                } label: {
                    Image(systemName: "xmark.bin")
                }
                .buttonStyle(ActionChipButtonStyle())
                .accessibilityLabel(L10n.tr("Close Others"))
                .help(L10n.tr("Close visible windows that are not part of the active restored layout"))
            }

            Spacer(minLength: 8)

            Button {
                coordinator.askToCloseAllWindows()
            } label: {
                Label(L10n.tr("Close All"), systemImage: "xmark.circle")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(ActionChipButtonStyle(tone: .destructive))
            .help(L10n.tr("Ask every app across every Space to quit"))
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var overlayPanel: some View {
        if coordinator.isCloseAllConfirmationPresented {
            QuitAllAppsPanel()
                .environmentObject(coordinator)
        } else if coordinator.isAboutPresented {
            AboutSettlePanel()
                .environmentObject(coordinator)
        } else if coordinator.isSaveSheetPresented {
            SaveLayoutPanel()
                .environmentObject(coordinator)
        } else if coordinator.renamingLayout != nil {
            RenameLayoutPanel()
                .environmentObject(coordinator)
        }
    }

    private var layoutsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.tr("Saved Layouts"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(coordinator.layouts.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if coordinator.layouts.isEmpty {
                Text(L10n.tr("No layouts yet."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if !coordinator.pinnedLayouts.isEmpty {
                            LayoutSectionCard(
                                title: L10n.tr("Pinned Layouts"),
                                caption: L10n.tr("Drag the handle to reorder pinned layouts.")
                            ) {
                                ForEach(Array(coordinator.pinnedLayouts.enumerated()), id: \.element.id) { index, layout in
                                    LayoutRow(
                                        layout: layout,
                                        sectionStyle: .pinned,
                                        draggedPinnedLayoutID: $draggedPinnedLayoutID
                                    )
                                    .environmentObject(coordinator)
                                    .onDrop(
                                        of: [UTType.text],
                                        delegate: PinnedLayoutDropDelegate(
                                            targetLayout: layout,
                                            pinnedLayouts: coordinator.pinnedLayouts,
                                            draggedPinnedLayoutID: $draggedPinnedLayoutID
                                        ) { from, to in
                                            coordinator.movePinnedLayout(from: from, to: to)
                                        }
                                    )

                                    if index < coordinator.pinnedLayouts.count - 1 {
                                        Divider()
                                            .padding(.leading, 12)
                                    }
                                }
                            }
                        }

                        LayoutSectionCard(title: L10n.tr("Saved Layouts")) {
                            if coordinator.unpinnedLayouts.isEmpty {
                                Text(L10n.tr("No regular layouts."))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                            } else {
                                ForEach(Array(coordinator.unpinnedLayouts.enumerated()), id: \.element.id) { index, layout in
                                    LayoutRow(layout: layout)
                                        .environmentObject(coordinator)

                                    if index < coordinator.unpinnedLayouts.count - 1 {
                                        Divider()
                                            .padding(.leading, 12)
                                    }
                                }
                            }
                        }
                    }
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: PanelHeightMetricsPreferenceKey.self,
                                value: PanelHeightMetrics(listContentHeight: proxy.size.height)
                            )
                        }
                    }
                }
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: PanelHeightMetricsPreferenceKey.self,
                            value: PanelHeightMetrics(listViewportHeight: proxy.size.height)
                        )
                    }
                }
                .frame(minHeight: 260, maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var footer: some View {
        HStack(alignment: .center) {
            Text(coordinator.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Button(L10n.tr("Quit")) {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
    }
}

private struct PanelHeightMetrics: Equatable {
    var panelHeight: CGFloat = 0
    var listViewportHeight: CGFloat = 0
    var listContentHeight: CGFloat = 0
}

private struct PanelHeightMetricsPreferenceKey: PreferenceKey {
    static let defaultValue = PanelHeightMetrics()

    static func reduce(value: inout PanelHeightMetrics, nextValue: () -> PanelHeightMetrics) {
        let next = nextValue()
        if next.panelHeight > 0 {
            value.panelHeight = next.panelHeight
        }
        if next.listViewportHeight > 0 {
            value.listViewportHeight = next.listViewportHeight
        }
        if next.listContentHeight > 0 {
            value.listContentHeight = next.listContentHeight
        }
    }
}

private struct HeaderIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08))
            )
    }
}

private struct LayoutSectionCard<Content: View>: View {
    let title: String
    var caption: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 0) {
                content
            }
            .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct QuitAllAppsPanel: View {
    @EnvironmentObject private var coordinator: LayoutCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.tr("Quit Every App"))
                .font(.headline)
            Text(L10n.tr("This will ask every app across all Spaces to quit. Apps may ask to save changes before closing."))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(L10n.tr("Cancel")) {
                    coordinator.cancelCloseAllWindows()
                }
                Button(L10n.tr("Quit All Apps"), role: .destructive) {
                    coordinator.closeAllWindows()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16))
        )
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }
}

private struct AboutSettlePanel: View {
    @EnvironmentObject private var coordinator: LayoutCoordinator

    private let websiteURL = URL(string: "http://settle.titanolandia.es")!
    private let sourceCodeURL = URL(string: "https://github.com/olerida/Settle")!

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("About Settle"))
                        .font(.headline)
                    Text(L10n.tr("Settle is a menu bar app for saving and restoring macOS window layouts."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                GridRow {
                    Text(L10n.tr("Version"))
                        .foregroundStyle(.secondary)
                    Text(coordinator.appVersionDescription)
                }
                GridRow {
                    Text(L10n.tr("Developer"))
                        .foregroundStyle(.secondary)
                    Text("Oscar Lerida")
                }
                GridRow {
                    Text(L10n.tr("Website"))
                        .foregroundStyle(.secondary)
                    Link(L10n.tr("Website URL"), destination: websiteURL)
                }
                GridRow {
                    Text(L10n.tr("Source Code"))
                        .foregroundStyle(.secondary)
                    Link("github.com/olerida/Settle", destination: sourceCodeURL)
                }
                GridRow {
                    Text(L10n.tr("License"))
                        .foregroundStyle(.secondary)
                    Text(L10n.tr("MIT License"))
                }
            }
            .font(.subheadline)

            Text(L10n.tr("Built for macOS 14 and later"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button(L10n.tr("Close")) {
                    coordinator.dismissAbout()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16))
        )
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }
}

private struct ActionChipButtonStyle: ButtonStyle {
    enum Tone {
        case standard
        case primary
        case destructive
    }

    var tone: Tone = .standard

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(foregroundColor(isPressed: configuration.isPressed))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(borderColor)
            )
    }

    private func foregroundColor(isPressed: Bool) -> Color {
        switch tone {
        case .standard:
            return .primary
        case .primary:
            return .accentColor.opacity(isPressed ? 0.85 : 1)
        case .destructive:
            return .red.opacity(isPressed ? 0.9 : 0.8)
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch tone {
        case .standard:
            return .white.opacity(isPressed ? 0.1 : 0.06)
        case .primary:
            return .accentColor.opacity(isPressed ? 0.18 : 0.12)
        case .destructive:
            return .red.opacity(isPressed ? 0.14 : 0.08)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .standard:
            return .white.opacity(0.08)
        case .primary:
            return .accentColor.opacity(0.24)
        case .destructive:
            return .red.opacity(0.18)
        }
    }
}

private struct LayoutRow: View {
    enum SectionStyle {
        case standard
        case pinned
    }

    @EnvironmentObject private var coordinator: LayoutCoordinator
    let layout: Layout
    var sectionStyle: SectionStyle = .standard
    @Binding var draggedPinnedLayoutID: UUID?

    init(
        layout: Layout,
        sectionStyle: SectionStyle = .standard,
        draggedPinnedLayoutID: Binding<UUID?> = .constant(nil)
    ) {
        self.layout = layout
        self.sectionStyle = sectionStyle
        self._draggedPinnedLayoutID = draggedPinnedLayoutID
    }

    var body: some View {
        let isActive = coordinator.activeRestoredLayout?.id == layout.id

        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.35))
                .frame(width: 8, height: 8)
                .accessibilityHidden(!isActive)
                .accessibilityLabel(L10n.tr("Active layout"))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(layout.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if layout.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    Label(L10n.format("%d apps", layout.apps.count), systemImage: "square.stack.3d.up")
                    Label(layout.updatedAt.settleRowTimestamp, systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if sectionStyle == .pinned {
                Image(systemName: "line.3.horizontal")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .help(L10n.tr("Drag to reorder"))
                    .accessibilityLabel(L10n.tr("Reorder pinned layout"))
                    .onDrag {
                        draggedPinnedLayoutID = layout.id
                        return NSItemProvider(object: layout.id.uuidString as NSString)
                    }
            }

            LayoutSnapshotPreviewButton(layout: layout)
                .environmentObject(coordinator)
                .id(layout.snapshotFileName ?? layout.id.uuidString)

            Button {
                coordinator.restore(layout)
            } label: {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .controlSize(.small)
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel(L10n.tr("Restore layout"))
            .help(L10n.tr("Restore layout"))

            Button {
                coordinator.overwrite(layout)
            } label: {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .controlSize(.small)
            .foregroundStyle(.secondary)
            .accessibilityLabel(L10n.tr("Update layout"))
            .help(L10n.tr("Update layout with current windows"))

            Menu {
                Button(L10n.tr(layout.pinned ? "Unpin" : "Pin")) {
                    coordinator.togglePinned(layout)
                }
                Button(L10n.tr("Rename")) {
                    coordinator.beginRename(layout)
                }
                Divider()
                Button(L10n.tr("Delete"), role: .destructive) {
                    coordinator.delete(layout)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isActive ? Color.accentColor.opacity(0.28) : Color.clear)
        )
    }
}

private struct PinnedLayoutDropDelegate: DropDelegate {
    let targetLayout: Layout
    let pinnedLayouts: [Layout]
    @Binding var draggedPinnedLayoutID: UUID?
    let moveAction: (Int, Int) -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggedPinnedLayoutID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard
            let draggedPinnedLayoutID,
            draggedPinnedLayoutID != targetLayout.id,
            let fromIndex = pinnedLayouts.firstIndex(where: { $0.id == draggedPinnedLayoutID }),
            let toIndex = pinnedLayouts.firstIndex(where: { $0.id == targetLayout.id })
        else {
            return
        }

        moveAction(fromIndex, toIndex > fromIndex ? toIndex + 1 : toIndex)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

private struct LayoutSnapshotPreviewButton: View {
    @EnvironmentObject private var coordinator: LayoutCoordinator
    let layout: Layout

    @State private var isPreviewPresented = false

    var body: some View {
        let snapshotURL = coordinator.snapshotURL(for: layout)

        Button {
            guard snapshotURL != nil else { return }
            isPreviewPresented.toggle()
        } label: {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.body)
        }
        .buttonStyle(.plain)
        .controlSize(.small)
        .foregroundStyle(snapshotURL == nil ? .tertiary : .secondary)
        .disabled(snapshotURL == nil)
        .accessibilityLabel(L10n.tr("Show snapshot preview"))
        .help(L10n.tr("Show snapshot preview"))
        .popover(isPresented: $isPreviewPresented, arrowEdge: .trailing) {
            if let snapshotURL, let image = snapshotImage(at: snapshotURL) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(layout.name)
                        .font(.headline)
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 320, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(12)
            }
        }
    }

    private func snapshotImage(at url: URL) -> NSImage? {
        guard let data = try? Data(contentsOf: url), let image = NSImage(data: data) else {
            return nil
        }
        image.size = image.size
        return image
    }
}

private struct SaveLayoutPanel: View {
    @EnvironmentObject private var coordinator: LayoutCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.tr("Save Current Layout"))
                .font(.headline)
            TextField(L10n.tr("Layout name"), text: $coordinator.saveName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(L10n.tr("Cancel")) {
                    coordinator.cancelSave()
                }
                Button(L10n.tr("Save")) {
                    Task {
                        await coordinator.saveCurrentLayout(named: coordinator.saveName)
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16))
        )
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }
}

private extension Date {
    var settleRowTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

private struct RenameLayoutPanel: View {
    @EnvironmentObject private var coordinator: LayoutCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.tr("Rename Layout"))
                .font(.headline)
            TextField(L10n.tr("Layout name"), text: $coordinator.renameName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(L10n.tr("Cancel")) {
                    coordinator.cancelRename()
                }
                Button(L10n.tr("Save")) {
                    coordinator.commitRename()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16))
        )
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }
}
