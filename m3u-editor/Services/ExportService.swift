import Foundation
import AppKit

struct ExportService {

    // MARK: - Format

    enum Format: String, CaseIterable, Identifiable {
        case m3u  = "M3U Playlist"
        case csv  = "CSV"
        case json = "JSON"
        case txt  = "Plain Text"

        var id: String { rawValue }

        var fileExtension: String {
            switch self {
            case .m3u:  return "m3u"
            case .csv:  return "csv"
            case .json: return "json"
            case .txt:  return "txt"
            }
        }

        var systemImage: String {
            switch self {
            case .m3u:  return "play.rectangle"
            case .csv:  return "tablecells"
            case .json: return "curlybraces"
            case .txt:  return "doc.text"
            }
        }
    }

    // MARK: - Export content generation

    static func export(
        channels: [M3UChannel],
        format: Format,
        includeDisabled: Bool = true
    ) -> String {
        let list = includeDisabled ? channels : channels.filter(\.isEnabled)
        switch format {
        case .m3u:  return M3UParser.serialize(channels: list, includeDisabled: true)
        case .csv:  return exportCSV(list)
        case .json: return exportJSON(list)
        case .txt:  return exportTXT(list)
        }
    }

    // MARK: - Formats

    private static func exportCSV(_ channels: [M3UChannel]) -> String {
        let header = "Title,TVG Name,TVG ID,Group,Logo URL,Stream URL,Enabled"
        let rows = channels.map { ch in
            [ch.title, ch.tvgName, ch.tvgId, ch.groupTitle,
             ch.tvgLogo, ch.url, ch.isEnabled ? "1" : "0"]
                .map(csvEscape)
                .joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private static func csvEscape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func exportJSON(_ channels: [M3UChannel]) -> String {
        let items = channels.map { ch -> [String: Any] in
            var item: [String: Any] = [
                "title": ch.title,
                "url": ch.url,
                "group": ch.groupTitle,
                "enabled": ch.isEnabled
            ]
            if !ch.tvgId.isEmpty    { item["tvg_id"]   = ch.tvgId }
            if !ch.tvgName.isEmpty  { item["tvg_name"] = ch.tvgName }
            if !ch.tvgLogo.isEmpty  { item["tvg_logo"] = ch.tvgLogo }
            if ch.duration != -1    { item["duration"]  = ch.duration }
            if !ch.additionalAttributes.isEmpty { item["extra"] = ch.additionalAttributes }
            return item
        }
        guard let data = try? JSONSerialization.data(
            withJSONObject: items,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ), let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    private static func exportTXT(_ channels: [M3UChannel]) -> String {
        channels.enumerated().map { i, ch in
            let name  = ch.displayName
            let group = ch.groupTitle.isEmpty ? "" : " [\(ch.groupTitle)]"
            return "\(i + 1). \(name)\(group)\n   \(ch.url)"
        }.joined(separator: "\n\n")
    }

    // MARK: - Save panel

    @MainActor
    static func saveWithPanel(content: String, suggestedName: String, format: Format) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName + "." + format.fileExtension
        panel.message = "Choose a location to save the exported file"
        panel.prompt  = "Export"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }
}
