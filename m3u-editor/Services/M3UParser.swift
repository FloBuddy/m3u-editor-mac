import Foundation

enum M3UParseError: LocalizedError {
    case emptyContent
    case invalidFormat(String)

    var errorDescription: String? {
        switch self {
        case .emptyContent: return "The file is empty or could not be decoded."
        case .invalidFormat(let msg): return "Invalid M3U format: \(msg)"
        }
    }
}

struct M3UParser {

    // MARK: - Parsing

    static func parse(url: URL) throws -> [M3UChannel] {
        let data = try Data(contentsOf: url)
        let content = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
        guard !content.isEmpty else { throw M3UParseError.emptyContent }
        return try parse(string: content)
    }

    static func parse(string: String) throws -> [M3UChannel] {
        guard !string.isEmpty else { throw M3UParseError.emptyContent }

        let lines = string.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var channels: [M3UChannel] = []
        var pending: M3UChannel? = nil

        for line in lines {
            if line.isEmpty { continue }
            if line.hasPrefix("#EXTM3U") { continue }

            if line.hasPrefix("#EXTINF:") {
                pending = parseExtInf(line: line)
            } else if !line.hasPrefix("#") {
                // URL line
                if var ch = pending {
                    ch.url = line
                    channels.append(ch)
                    pending = nil
                } else {
                    // Bare URL with no EXTINF
                    var ch = M3UChannel()
                    ch.title = line
                    ch.url = line
                    channels.append(ch)
                }
            }
            // Any other # comment lines are skipped
        }

        return channels
    }

    // MARK: - EXTINF parsing

    private static func parseExtInf(line: String) -> M3UChannel {
        let content = String(line.dropFirst("#EXTINF:".count))

        var channel = M3UChannel()

        guard let commaIdx = lastUnquotedCommaIndex(in: content) else {
            channel.title = content
            return channel
        }

        let attrPart = String(content[content.startIndex..<commaIdx])
        channel.title = String(content[content.index(after: commaIdx)...])
            .trimmingCharacters(in: .whitespaces)

        // First token is the duration
        let tokens = attrPart.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if let durationToken = tokens.first {
            channel.duration = Int(String(durationToken)) ?? -1
        }

        let attrStr = tokens.count > 1 ? String(tokens[1]) : ""
        let attrs = parseAttributes(attrStr)

        channel.tvgId    = attrs["tvg-id"] ?? ""
        channel.tvgName  = attrs["tvg-name"] ?? ""
        channel.tvgLogo  = attrs["tvg-logo"] ?? ""
        channel.groupTitle = attrs["group-title"] ?? ""

        let knownKeys: Set<String> = ["tvg-id", "tvg-name", "tvg-logo", "group-title"]
        channel.additionalAttributes = attrs.filter { !knownKeys.contains($0.key) }

        return channel
    }

    /// Returns the index of the last comma that is NOT inside double quotes.
    private static func lastUnquotedCommaIndex(in str: String) -> String.Index? {
        var inQuotes = false
        var result: String.Index? = nil
        for idx in str.indices {
            switch str[idx] {
            case "\"": inQuotes.toggle()
            case "," where !inQuotes: result = idx
            default: break
            }
        }
        return result
    }

    /// Parses `key="value" key2="value2" ...` attribute strings.
    private static func parseAttributes(_ str: String) -> [String: String] {
        var attrs: [String: String] = [:]
        var remaining = str[str.startIndex...]

        while !remaining.isEmpty {
            remaining = remaining.drop(while: { $0 == " " })
            guard let eqIdx = remaining.firstIndex(of: "=") else { break }

            let key = String(remaining[remaining.startIndex..<eqIdx])
                .trimmingCharacters(in: .whitespaces)
            remaining = remaining[remaining.index(after: eqIdx)...]

            if remaining.first == "\"" {
                remaining = remaining.dropFirst()
                if let closeIdx = remaining.firstIndex(of: "\"") {
                    attrs[key] = String(remaining[remaining.startIndex..<closeIdx])
                    remaining = remaining[remaining.index(after: closeIdx)...]
                }
            } else {
                let end = remaining.firstIndex(of: " ") ?? remaining.endIndex
                attrs[key] = String(remaining[remaining.startIndex..<end])
                remaining = remaining[end...]
            }
        }

        return attrs
    }

    // MARK: - Serialization

    static func serialize(channels: [M3UChannel], includeDisabled: Bool = true) -> String {
        var lines = ["#EXTM3U"]

        for channel in channels {
            if !channel.isEnabled && !includeDisabled { continue }

            var attrs = "\(channel.duration)"
            if !channel.tvgId.isEmpty    { attrs += " tvg-id=\"\(channel.tvgId)\"" }
            if !channel.tvgName.isEmpty  { attrs += " tvg-name=\"\(channel.tvgName)\"" }
            if !channel.tvgLogo.isEmpty  { attrs += " tvg-logo=\"\(channel.tvgLogo)\"" }
            if !channel.groupTitle.isEmpty { attrs += " group-title=\"\(channel.groupTitle)\"" }
            for (k, v) in channel.additionalAttributes.sorted(by: { $0.key < $1.key }) {
                attrs += " \(k)=\"\(v)\""
            }

            lines.append("#EXTINF:\(attrs),\(channel.title)")
            lines.append(channel.url)
        }

        return lines.joined(separator: "\n")
    }
}
