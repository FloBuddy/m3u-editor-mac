import SwiftUI
import AppKit
import Observation

// MARK: - Sidebar Navigation

enum SidebarItem: Hashable {
    case allChannels
    case group(String)
    case smartFilter(SmartFilter)
}

enum SmartFilter: String, CaseIterable, Hashable, Identifiable {
    case enabled  = "Enabled"
    case disabled = "Disabled"
    case noLogo   = "No Logo"
    case noGroup  = "No Group"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .enabled:  return "checkmark.circle.fill"
        case .disabled: return "xmark.circle"
        case .noLogo:   return "photo.slash"
        case .noGroup:  return "folder.badge.questionmark"
        }
    }

    var color: Color {
        switch self {
        case .enabled:  return .green
        case .disabled: return .red
        case .noLogo:   return .orange
        case .noGroup:  return .secondary
        }
    }

    func matches(_ channel: M3UChannel) -> Bool {
        switch self {
        case .enabled:  return channel.isEnabled
        case .disabled: return !channel.isEnabled
        case .noLogo:   return channel.tvgLogo.isEmpty
        case .noGroup:  return channel.groupTitle.isEmpty
        }
    }
}

// MARK: - AppState

@Observable
final class AppState {

    // MARK: Workspace
    var playlists: [M3UPlaylist] = []
    var selectedPlaylistId: UUID?

    // MARK: Navigation
    var selectedSidebarItem: SidebarItem? = .allChannels

    // MARK: Selection & Search
    var selectedChannelIds: Set<UUID> = []
    var searchText: String = ""

    // MARK: UI state
    var showInspector: Bool = false
    var showBulkRename: Bool = false
    var showExport: Bool = false
    var showStreamHealth: Bool = false
    var alertMessage: String? = nil

    // MARK: Services
    var streamChecker = StreamChecker()

    // MARK: - Computed

    var currentPlaylist: M3UPlaylist? {
        guard let id = selectedPlaylistId else { return playlists.first }
        return playlists.first { $0.id == id }
    }

    var filteredChannels: [M3UChannel] {
        guard let playlist = currentPlaylist else { return [] }

        var result = playlist.channels

        // Sidebar item filter
        switch selectedSidebarItem {
        case .allChannels, nil:
            break
        case .group(let g):
            result = result.filter { $0.effectiveGroup == g }
        case .smartFilter(let f):
            result = result.filter { f.matches($0) }
        }

        // Search filter
        if !searchText.isEmpty {
            result = result.filter { $0.matches(searchText: searchText) }
        }

        return result
    }

    var selectedChannels: [M3UChannel] {
        currentPlaylist?.channels.filter { selectedChannelIds.contains($0.id) } ?? []
    }

    var firstSelectedChannel: M3UChannel? {
        selectedChannels.first
    }

    // MARK: - File operations

    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.message = "Select M3U playlist files to open"
        panel.prompt  = "Open"
        panel.allowedContentTypes = []

        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            openPlaylist(from: url)
        }
    }

    func openPlaylist(from url: URL) {
        // Re-focus if already open
        if let existing = playlists.first(where: { $0.fileURL?.path == url.path }) {
            selectedPlaylistId = existing.id
            return
        }

        do {
            let channels = try M3UParser.parse(url: url)
            let name = url.deletingPathExtension().lastPathComponent
            let playlist = M3UPlaylist(name: name, channels: channels, fileURL: url)
            playlists.append(playlist)
            selectedPlaylistId = playlist.id
            selectedSidebarItem = .allChannels
            selectedChannelIds = []
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func saveCurrentPlaylist() {
        guard let playlist = currentPlaylist else { return }
        if let url = playlist.fileURL {
            let content = M3UParser.serialize(channels: playlist.channels)
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                playlist.isModified = false
                playlist.lastSaved = Date()
            } catch {
                alertMessage = error.localizedDescription
            }
        } else {
            saveCurrentPlaylistAs()
        }
    }

    func saveCurrentPlaylistAs() {
        guard let playlist = currentPlaylist else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = playlist.name + ".m3u"
        panel.allowedContentTypes = []
        panel.canCreateDirectories = true
        panel.message = "Save M3U playlist"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let content = M3UParser.serialize(channels: playlist.channels)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            playlist.fileURL = url
            playlist.name = url.deletingPathExtension().lastPathComponent
            playlist.isModified = false
            playlist.lastSaved = Date()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func closePlaylist(_ id: UUID) {
        playlists.removeAll { $0.id == id }
        if selectedPlaylistId == id {
            selectedPlaylistId = playlists.first?.id
            selectedSidebarItem = .allChannels
        }
        selectedChannelIds = []
    }

    func newPlaylist() {
        let playlist = M3UPlaylist(name: "New Playlist")
        playlists.append(playlist)
        selectedPlaylistId = playlist.id
        selectedSidebarItem = .allChannels
        selectedChannelIds = []
    }

    // MARK: - Channel operations

    func deleteSelectedChannels() {
        currentPlaylist?.removeChannels(ids: selectedChannelIds)
        selectedChannelIds = []
    }

    func setEnabled(_ enabled: Bool, for ids: Set<UUID>) {
        guard let playlist = currentPlaylist else { return }
        for i in playlist.channels.indices where ids.contains(playlist.channels[i].id) {
            playlist.channels[i].isEnabled = enabled
        }
        playlist.isModified = true
    }

    func toggleEnabledForSelection() {
        let allEnabled = selectedChannels.allSatisfy(\.isEnabled)
        setEnabled(!allEnabled, for: selectedChannelIds)
    }

    func updateChannel(_ channel: M3UChannel) {
        currentPlaylist?.updateChannel(channel)
    }

    // MARK: - Drag & drop reordering

    func moveChannels(from source: IndexSet, to destination: Int) {
        currentPlaylist?.moveChannels(from: source, to: destination)
    }
}
