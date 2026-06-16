import AppKit
import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var coordinator: LayoutCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            permissionBanner
            actionButtons
            inlineEditor
            layoutsList
            footer
        }
        .padding(14)
        .frame(width: 430)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            coordinator.refreshPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            coordinator.refreshPermissions()
        }
    }

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
            Button(L10n.tr("Settings")) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .buttonStyle(.borderless)
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

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
                coordinator.prepareSave()
            } label: {
                Label(L10n.tr("Save Layout"), systemImage: "plus.circle")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(ActionChipButtonStyle())

            Button {
                coordinator.quickSave()
            } label: {
                Label(L10n.tr("Quick Save"), systemImage: "bolt.circle")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(ActionChipButtonStyle())
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var inlineEditor: some View {
        if coordinator.isSaveSheetPresented {
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
                    LazyVStack(spacing: 0) {
                        ForEach(Array(coordinator.layouts.enumerated()), id: \.element.id) { index, layout in
                            LayoutRow(layout: layout)
                                .environmentObject(coordinator)
                            if index < coordinator.layouts.count - 1 {
                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                    .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
                }
                .frame(minHeight: 260, maxHeight: 340)
            }
        }
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

private struct ActionChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.1 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08))
            )
    }
}

private struct LayoutRow: View {
    @EnvironmentObject private var coordinator: LayoutCoordinator
    let layout: Layout

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(layout.pinned ? Color.accentColor : Color.secondary.opacity(0.35))
                .frame(width: 8, height: 8)

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
        .onHover { hovering in
            guard snapshotURL != nil else {
                isPreviewPresented = false
                return
            }
            isPreviewPresented = hovering
        }
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
        .padding(12)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
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
        .padding(12)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
    }
}
