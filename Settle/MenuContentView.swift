import AppKit
import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var coordinator: LayoutCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            permissionBanner
            actionButtons
            layoutsList
            footer
        }
        .padding(14)
        .frame(width: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $coordinator.isSaveSheetPresented) {
            SaveLayoutSheet()
                .environmentObject(coordinator)
        }
        .sheet(item: $coordinator.renamingLayout) { _ in
            RenameLayoutSheet()
                .environmentObject(coordinator)
        }
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
                Text("Window layouts for the current desktop")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Settings") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private var permissionBanner: some View {
        if !coordinator.permissionManager.isTrusted {
            VStack(alignment: .leading, spacing: 8) {
                Text("Accessibility access required")
                    .font(.subheadline.weight(.semibold))
                Text("Settle needs Accessibility permission to read, move, and resize windows.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("If you just enabled it in System Settings and this warning remains, close and reopen the app.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Button("Open System Prompt") {
                    coordinator.requestAccessibilityPermission()
                }
            }
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button("Save Current Layout...") {
                coordinator.prepareSave()
            }
            .buttonStyle(.borderedProminent)

            Button("Quick Save") {
                coordinator.quickSave()
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.small)
    }

    private var layoutsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Saved Layouts")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(coordinator.layouts.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if coordinator.layouts.isEmpty {
                Text("No layouts yet.")
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
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
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
                    Label("\(layout.apps.count) apps", systemImage: "square.stack.3d.up")
                    Label(layout.updatedAt.settleRowTimestamp, systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                coordinator.restore(layout)
            } label: {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .controlSize(.small)
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel("Restore layout")
            .help("Restore layout")

            Button {
                coordinator.overwrite(layout)
            } label: {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .controlSize(.small)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Update layout")
            .help("Update layout with current windows")

            Menu {
                Button(layout.pinned ? "Unpin" : "Pin") {
                    coordinator.togglePinned(layout)
                }
                Button("Rename") {
                    coordinator.beginRename(layout)
                }
                Divider()
                Button("Delete", role: .destructive) {
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

private struct SaveLayoutSheet: View {
    @EnvironmentObject private var coordinator: LayoutCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save Current Layout")
                .font(.headline)
            TextField("Layout name", text: $coordinator.saveName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    Task {
                        await coordinator.saveCurrentLayout(named: coordinator.saveName)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
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

private struct RenameLayoutSheet: View {
    @EnvironmentObject private var coordinator: LayoutCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename Layout")
                .font(.headline)
            TextField("Layout name", text: $coordinator.renameName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") {
                    coordinator.cancelRename()
                    dismiss()
                }
                Button("Save") {
                    coordinator.commitRename()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
