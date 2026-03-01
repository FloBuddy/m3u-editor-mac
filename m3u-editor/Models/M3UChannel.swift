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

    var displayName: String {
        let n = tvgName.isEmpty ? title : tvgName
        return n.trimmingCharacters(in: .whitespaces)
    }

    var effectiveGroup: String {
        groupTitle.isEmpty ? "Uncategorized" : groupTitle
    }

    func matches(searchText: String) -> Bool {
        guard !searchText.isEmpty else { return true }
        let q = searchText.lowercased()
        return displayName.lowercased().contains(q)
            || groupTitle.lowercased().contains(q)
            || tvgId.lowercased().contains(q)
            || url.lowercased().contains(q)
            || tvgLogo.lowercased().contains(q)
    }
}
