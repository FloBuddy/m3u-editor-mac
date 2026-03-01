import SwiftUI

struct ChannelListView: View {
    @Environment(AppState.self) private var appState

    @State private var sortOrder: [KeyPathComparator<M3UChannel>] = [
        .init(\.displayName, order: .forward)
    ]

    private var sortedChannels: [M3UChannel] {
        appState.filteredChannels.sorted(using: sortOrder)
    }

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search channels…", text: $state.searchText)
                    .textFieldStyle(.plain)
                if !appState.searchText.isEmpty {
                    Button { appState.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            // Channel table
            if sortedChannels.isEmpty {
                channelEmptyState
            } else {
                Table(
                    sortedChannels,
                    selection: $state.selectedChannelIds,
                    sortOrder: $sortOrder
                ) {
                    // Enabled toggle
                    TableColumn("") { ch in
                        Toggle("", isOn: enabledBinding(for: ch))
                            .toggleStyle(.checkbox)
                            .help(ch.isEnabled ? "Disable channel" : "Enable channel")
                    }
                    .width(24)

                    // Logo
                    TableColumn("") { ch in
                        LogoView(urlString: ch.tvgLogo)
                    }
                    .width(28)

                    // Name
                    TableColumn("Name", value: \.displayName) { ch in
                        Text(ch.displayName)
                            .lineLimit(1)
                            .foregroundStyle(ch.isEnabled ? .primary : .secondary)
                    }

                    // Group
                    TableColumn("Group", value: \.groupTitle) { ch in
                        Text(ch.effectiveGroup)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .width(min: 80, ideal: 140, max: 200)

                    // URL
                    TableColumn("URL") { ch in
                        Text(ch.url)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .font(.caption.monospaced())
                    }
                }
                .contextMenu(forSelectionType: UUID.self) { ids in
                    channelContextMenu(ids: ids)
                } primaryAction: { _ in
                    appState.showInspector = true
                }
            }

            Divider()

            // Status bar
            StatusBar()
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var channelEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: appState.searchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(appState.searchText.isEmpty ? "No channels" : "No results for \"\(appState.searchText)\"")
                .foregroundStyle(.secondary)
            if !appState.searchText.isEmpty {
                Button("Clear Search") { appState.searchText = "" }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func channelContextMenu(ids: Set<UUID>) -> some View {
        if ids.count == 1 {
            Button("Show in Inspector") {
                appState.showInspector = true
            }
            Divider()
        }

        let allEnabled = ids.allSatisfy { id in
            appState.currentPlaylist?.channels.first(where: { $0.id == id })?.isEnabled == true
        }
        Button(allEnabled ? "Disable" : "Enable") {
            appState.setEnabled(!allEnabled, for: ids)
        }

        Divider()

        Button("Copy URL") {
            if let ch = appState.currentPlaylist?.channels.first(where: { ids.contains($0.id) }) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(ch.url, forType: .string)
            }
        }

        Button("Copy Name") {
            let names = appState.currentPlaylist?.channels
                .filter { ids.contains($0.id) }
                .map(\.displayName)
                .joined(separator: "\n") ?? ""
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(names, forType: .string)
        }

        Divider()

        Button("Delete", role: .destructive) {
            appState.selectedChannelIds = ids
            appState.deleteSelectedChannels()
        }
    }

    // MARK: - Helpers

    private func enabledBinding(for channel: M3UChannel) -> Binding<Bool> {
        Binding(
            get: { channel.isEnabled },
            set: { newValue in
                appState.setEnabled(newValue, for: [channel.id])
            }
        )
    }
}

// MARK: - Logo View

struct LogoView: View {
    let urlString: String

    var body: some View {
        Group {
            if let url = URL(string: urlString), !urlString.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit()
                    default:
                        placeholderRect
                    }
                }
            } else {
                placeholderRect
            }
        }
        .frame(width: 24, height: 18)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private var placeholderRect: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(.quaternary)
    }
}

// MARK: - Status Bar

private struct StatusBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 16) {
            if let playlist = appState.currentPlaylist {
                Label("\(playlist.channels.count)", systemImage: "play.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("\(playlist.groups.count)", systemImage: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !appState.searchText.isEmpty {
                    Label("\(appState.filteredChannels.count) shown", systemImage: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !appState.selectedChannelIds.isEmpty {
                Text("\(appState.selectedChannelIds.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.bar)
    }
}
