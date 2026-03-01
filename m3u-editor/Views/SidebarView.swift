import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        List(selection: $state.selectedSidebarItem) {

            // MARK: Playlists
            Section("Playlists") {
                ForEach(appState.playlists) { playlist in
                    PlaylistRow(playlist: playlist)
                        .tag(Optional<SidebarItem>.none)
                        .contextMenu {
                            Button("Save") { appState.saveCurrentPlaylist() }
                            Button("Save As…") { appState.saveCurrentPlaylistAs() }
                            Divider()
                            Button("Close", role: .destructive) {
                                appState.closePlaylist(playlist.id)
                            }
                        }
                }
            }

            // MARK: Navigation (shown when a playlist is loaded)
            if let playlist = appState.currentPlaylist {
                Section("Channels") {
                    SidebarNavRow(
                        icon: "list.bullet",
                        iconColor: .accentColor,
                        label: "All Channels",
                        badge: playlist.channels.count
                    )
                    .tag(SidebarItem.allChannels as SidebarItem?)

                    ForEach(playlist.groups, id: \.self) { group in
                        SidebarNavRow(
                            icon: "folder",
                            iconColor: .orange,
                            label: group,
                            badge: playlist.channels(inGroup: group).count
                        )
                        .tag(SidebarItem.group(group) as SidebarItem?)
                    }
                }

                // MARK: Smart Filters
                Section("Smart Filters") {
                    ForEach(SmartFilter.allCases) { filter in
                        SidebarNavRow(
                            icon: filter.systemImage,
                            iconColor: filter.color,
                            label: filter.rawValue,
                            badge: playlist.channels.filter { filter.matches($0) }.count
                        )
                        .tag(SidebarItem.smartFilter(filter) as SidebarItem?)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            SidebarFooter()
        }
    }
}

// MARK: - Playlist Row

private struct PlaylistRow: View {
    @Environment(AppState.self) private var appState
    let playlist: M3UPlaylist

    private var isActive: Bool { appState.selectedPlaylistId == playlist.id }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.rectangle")
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(playlist.name)
                        .fontWeight(isActive ? .semibold : .regular)
                        .lineLimit(1)
                    if playlist.isModified {
                        Circle().fill(.orange).frame(width: 6, height: 6)
                    }
                }
                Text("\(playlist.channels.count) channels")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isActive {
                Button {
                    appState.closePlaylist(playlist.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.selectedPlaylistId = playlist.id
            appState.selectedSidebarItem = .allChannels
        }
    }
}

// MARK: - Generic nav row

private struct SidebarNavRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let badge: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 16)
            Text(label).lineLimit(1)
            Spacer()
            Text("\(badge)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Footer

private struct SidebarFooter: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack {
            Button {
                appState.openFilePicker()
            } label: {
                Label("Open", systemImage: "folder.badge.plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Open M3U file (⌘O)")

            Spacer()

            Button {
                appState.newPlaylist()
            } label: {
                Image(systemName: "plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("New empty playlist")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
