import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            if appState.playlists.isEmpty {
                EmptyStateView()
            } else {
                PlaylistDetailView()
            }
        }
        .navigationSplitViewStyle(.balanced)

        // MARK: Sheets
        .sheet(isPresented: $state.showBulkRename) {
            BulkRenameView(
                playlist: appState.currentPlaylist,
                selectedIds: appState.selectedChannelIds
            )
        }
        .sheet(isPresented: $state.showExport) {
            ExportOptionsView(playlist: appState.currentPlaylist)
        }
        .sheet(isPresented: $state.showStreamHealth) {
            StreamHealthView()
        }

        // MARK: Alert
        .alert("Error", isPresented: Binding(
            get: { appState.alertMessage != nil },
            set: { if !$0 { appState.alertMessage = nil } }
        )) {
            Button("OK") { appState.alertMessage = nil }
        } message: {
            Text(appState.alertMessage ?? "")
        }
    }
}

// MARK: - Playlist Detail

struct PlaylistDetailView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 0) {
            ChannelListView()

            if appState.showInspector {
                Divider()
                ChannelInspectorView()
            }
        }
        .toolbar {
            AppToolbar()
        }
        // Keyboard shortcuts
        .onKeyPress(.delete) {
            if !appState.selectedChannelIds.isEmpty {
                appState.deleteSelectedChannels()
                return .handled
            }
            return .ignored
        }
    }
}

// MARK: - Toolbar

struct AppToolbar: ToolbarContent {
    @Environment(AppState.self) private var appState

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                appState.openFilePicker()
            } label: {
                Label("Open", systemImage: "folder.badge.plus")
            }
            .help("Open M3U playlist (⌘O)")
            .keyboardShortcut("o")

            Button {
                appState.saveCurrentPlaylist()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .help("Save playlist (⌘S)")
            .keyboardShortcut("s")
            .disabled(appState.currentPlaylist == nil)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                appState.showBulkRename = true
            } label: {
                Label("Rename", systemImage: "textformat")
            }
            .help("Bulk rename channels (⌘R)")
            .keyboardShortcut("r")
            .disabled(appState.currentPlaylist == nil)

            Button {
                appState.showStreamHealth = true
            } label: {
                Label("Check Streams", systemImage: "antenna.radiowaves.left.and.right")
            }
            .help("Check stream health")
            .disabled(appState.currentPlaylist == nil)

            Button {
                appState.showExport = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export playlist (⌘E)")
            .keyboardShortcut("e")
            .disabled(appState.currentPlaylist == nil)

            Divider()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.showInspector.toggle()
                }
            } label: {
                Label("Inspector", systemImage: "sidebar.right")
            }
            .help("Toggle inspector panel (⌘I)")
            .keyboardShortcut("i")
        }
    }
}
