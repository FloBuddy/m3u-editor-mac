import SwiftUI

@main
struct m3u_editorApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(appState)
        }
        .commands {
            AppCommands(appState: appState)
        }
        .defaultSize(width: 1200, height: 720)
    }
}

// MARK: - Menu Commands

struct AppCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Playlist") { appState.newPlaylist() }
                .keyboardShortcut("n")

            Button("Open…") { appState.openFilePicker() }
                .keyboardShortcut("o")
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") { appState.saveCurrentPlaylist() }
                .keyboardShortcut("s")
                .disabled(appState.currentPlaylist == nil)

            Button("Save As…") { appState.saveCurrentPlaylistAs() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(appState.currentPlaylist == nil)
        }
    }
}
