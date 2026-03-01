import Foundation

struct M3UChannel: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String = ""
    var url: String = ""
    var duration: Int = -1
    var tvgId: String = ""
    var tvgName: String = ""
    var tvgLogo: String = ""
    var groupTitle: String = ""
    var additionalAttributes: [String: String] = [:]
    var isEnabled: Bool = true

    nonisolated init(
        id: UUID = UUID(),
        title: String = "",
        url: String = "",
        duration: Int = -1,
        tvgId: String = "",
        tvgName: String = "",
        tvgLogo: String = "",
        groupTitle: String = "",
        additionalAttributes: [String: String] = [:],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.duration = duration
        self.tvgId = tvgId
        self.tvgName = tvgName
        self.tvgLogo = tvgLogo
        self.groupTitle = groupTitle
        self.additionalAttributes = additionalAttributes
        self.isEnabled = isEnabled
    }

    nonisolated var displayName: String {
        let n = tvgName.isEmpty ? title : tvgName
        return n.trimmingCharacters(in: .whitespaces)
    }

    nonisolated var effectiveGroup: String {
        groupTitle.isEmpty ? "Uncategorized" : groupTitle
    }

    nonisolated func matches(searchText: String) -> Bool {
        guard !searchText.isEmpty else { return true }
        let q = searchText.lowercased()
        return displayName.lowercased().contains(q)
            || groupTitle.lowercased().contains(q)
            || tvgId.lowercased().contains(q)
            || url.lowercased().contains(q)
            || tvgLogo.lowercased().contains(q)
    }
}
