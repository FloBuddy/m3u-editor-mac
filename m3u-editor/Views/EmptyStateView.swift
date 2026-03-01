import SwiftUI
import UniformTypeIdentifiers

struct EmptyStateView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text("No Playlist Open")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Open an M3U file to start editing channels,\nor create a new empty playlist.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button {
                    appState.openFilePicker()
                } label: {
                    Label("Open File…", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    appState.newPlaylist()
                } label: {
                    Label("New Playlist", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url, url.pathExtension.lowercased() == "m3u" {
                    DispatchQueue.main.async {
                        appState.openPlaylist(from: url)
                    }
                }
            }
            handled = true
        }
        return handled
    }
}
