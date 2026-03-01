import SwiftUI

struct StreamHealthView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var filterStatus: StatusFilter = .all

    enum StatusFilter: String, CaseIterable, Identifiable {
        case all      = "All"
        case online   = "Online"
        case offline  = "Offline"
        case unknown  = "Not Checked"

        var id: String { rawValue }
    }

    private var checker: StreamChecker { appState.streamChecker }

    private var channels: [M3UChannel] {
        guard let playlist = appState.currentPlaylist else { return [] }
        switch filterStatus {
        case .all:     return playlist.channels
        case .online:  return playlist.channels.filter { checker.statuses[$0.id]?.isOnline == true }
        case .offline: return playlist.channels.filter { checker.statuses[$0.id]?.isOffline == true }
        case .unknown: return playlist.channels.filter { checker.statuses[$0.id] == nil || checker.statuses[$0.id] == .unknown }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundStyle(.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stream Health Monitor")
                        .font(.headline)
                    Text("\(appState.currentPlaylist?.channels.count ?? 0) channels")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            .background(.bar)

            Divider()

            // Controls
            HStack(spacing: 12) {
                if checker.isRunning {
                    ProgressView(value: checker.progress)
                        .frame(width: 120)
                    Text("\(checker.checkedCount) / \(checker.totalCount)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Button("Stop") { checker.cancel() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else {
                    Button {
                        guard let playlist = appState.currentPlaylist else { return }
                        checker.checkAll(channels: playlist.channels)
                    } label: {
                        Label("Check All Streams", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Spacer()

                // Summary badges
                summaryBadge(
                    label: "Online",
                    count: checkerCount(online: true),
                    color: .green
                )
                summaryBadge(
                    label: "Offline",
                    count: checkerCount(offline: true),
                    color: .red
                )

                Picker("Filter", selection: $filterStatus) {
                    ForEach(StatusFilter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Channel list
            Table(channels) {
                TableColumn("Status") { ch in
                    StatusCell(status: checker.statuses[ch.id] ?? .unknown)
                }
                .width(100)

                TableColumn("Name") { ch in
                    HStack(spacing: 6) {
                        LogoView(urlString: ch.tvgLogo)
                        Text(ch.displayName).lineLimit(1)
                    }
                }

                TableColumn("Group", value: \.groupTitle)
                    .width(min: 80, ideal: 130, max: 180)

                TableColumn("Response") { ch in
                    let status = checker.statuses[ch.id] ?? .unknown
                    Text(status.label)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .width(100)

                TableColumn("URL") { ch in
                    Text(ch.url)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Divider()

            // Footer
            HStack {
                if checker.isRunning {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking streams…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Remove Offline Streams") {
                    removeOfflineStreams()
                }
                .buttonStyle(.bordered)
                .disabled(checkerCount(offline: true) == 0 || checker.isRunning)
            }
            .padding()
            .background(.bar)
        }
        .frame(minWidth: 760, minHeight: 500)
    }

    @ViewBuilder
    private func summaryBadge(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(count) \(label)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func checkerCount(online: Bool = false, offline: Bool = false) -> Int {
        guard let playlist = appState.currentPlaylist else { return 0 }
        return playlist.channels.filter { ch in
            guard let status = checker.statuses[ch.id] else { return false }
            if online  { return status.isOnline }
            if offline { return status.isOffline }
            return false
        }.count
    }

    private func removeOfflineStreams() {
        guard let playlist = appState.currentPlaylist else { return }
        let offlineIds = Set(playlist.channels.compactMap { ch -> UUID? in
            checker.statuses[ch.id]?.isOffline == true ? ch.id : nil
        })
        playlist.removeChannels(ids: offlineIds)
    }
}

// MARK: - Status Cell

private struct StatusCell: View {
    let status: StreamStatus

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: status.systemImage)
                .foregroundStyle(statusColor)
                .symbolEffect(.pulse, isActive: status == .checking)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusText: String {
        switch status {
        case .unknown:   return "—"
        case .checking:  return "Checking"
        case .online:    return "Online"
        case .redirect:  return "Redirect"
        case .offline:   return "Offline"
        }
    }

    private var statusColor: Color {
        switch status {
        case .unknown:   return .secondary
        case .checking:  return .accentColor
        case .online:    return .green
        case .redirect:  return .orange
        case .offline:   return .red
        }
    }
}
