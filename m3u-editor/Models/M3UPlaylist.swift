import Foundation
import Observation
import SwiftUI

@Observable
final class M3UPlaylist: Identifiable {
    let id: UUID
    var name: String
    var channels: [M3UChannel]
    var fileURL: URL?
    var isModified: Bool = false
    var lastSaved: Date?

    init(
        id: UUID = UUID(),
        name: String = "Untitled",
        channels: [M3UChannel] = [],
        fileURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.channels = channels
        self.fileURL = fileURL
    }

    // MARK: - Derived properties

    var groups: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for ch in channels {
            let g = ch.effectiveGroup
            if seen.insert(g).inserted {
                result.append(g)
            }
        }
        return result.sorted()
    }

    var enabledCount: Int { channels.filter(\.isEnabled).count }
    var disabledCount: Int { channels.filter { !$0.isEnabled }.count }
    var noLogoCount: Int { channels.filter { $0.tvgLogo.isEmpty }.count }

    func channels(inGroup group: String) -> [M3UChannel] {
        channels.filter { $0.effectiveGroup == group }
    }

    func filtered(searchText: String, group: String? = nil) -> [M3UChannel] {
        var result = channels
        if let group {
            result = result.filter { $0.effectiveGroup == group }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.matches(searchText: searchText) }
        }
        return result
    }

    // MARK: - Mutations

    func addChannel(_ channel: M3UChannel) {
        channels.append(channel)
        isModified = true
    }

    func removeChannels(ids: Set<UUID>) {
        channels.removeAll { ids.contains($0.id) }
        isModified = true
    }

    func updateChannel(_ channel: M3UChannel) {
        guard let index = channels.firstIndex(where: { $0.id == channel.id }) else { return }
        channels[index] = channel
        isModified = true
    }

    func moveChannels(from source: IndexSet, to destination: Int) {
        channels.move(fromOffsets: source, toOffset: destination)
        isModified = true
    }
}
