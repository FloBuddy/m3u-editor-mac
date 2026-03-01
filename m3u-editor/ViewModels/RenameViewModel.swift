import Foundation
import Observation

// MARK: - Rename Operation

enum RenameOperation: String, CaseIterable, Identifiable {
    case findReplace    = "Find & Replace"
    case prefix         = "Add Prefix"
    case suffix         = "Add Suffix"
    case caseTransform  = "Change Case"
    case pattern        = "Pattern"
    case cleanSpaces    = "Clean Whitespace"
    case regexReplace   = "Regex Replace"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .findReplace:   return "magnifyingglass"
        case .prefix:        return "text.insert"
        case .suffix:        return "text.append"
        case .caseTransform: return "textformat"
        case .pattern:       return "sparkles.rectangle.stack"
        case .cleanSpaces:   return "scissors"
        case .regexReplace:  return "chevron.left.forwardslash.chevron.right"
        }
    }
}

// MARK: - Case Transform

enum CaseTransform: String, CaseIterable, Identifiable {
    case uppercase     = "UPPERCASE"
    case lowercase     = "lowercase"
    case titleCase     = "Title Case"
    case sentenceCase  = "Sentence case"

    var id: String { rawValue }

    func apply(to string: String) -> String {
        switch self {
        case .uppercase:
            return string.uppercased()
        case .lowercase:
            return string.lowercased()
        case .titleCase:
            return string
                .components(separatedBy: " ")
                .map { word -> String in
                    guard let first = word.first else { return word }
                    return first.uppercased() + word.dropFirst().lowercased()
                }
                .joined(separator: " ")
        case .sentenceCase:
            guard let first = string.first else { return string }
            return first.uppercased() + string.dropFirst().lowercased()
        }
    }
}

// MARK: - Target Field

enum RenameField: String, CaseIterable, Identifiable {
    case title    = "Title"
    case tvgName  = "TVG Name"
    case both     = "Title + TVG Name"

    var id: String { rawValue }
}

// MARK: - RenameViewModel

@Observable
final class RenameViewModel {
    var operation: RenameOperation = .findReplace

    // Find & Replace / Regex
    var findText: String = ""
    var replaceText: String = ""

    // Prefix / Suffix
    var affixText: String = ""

    // Case Transform
    var caseTransform: CaseTransform = .titleCase

    // Pattern – supports {name}, {group}, {index}, {INDEX}
    var patternText: String = "{name}"

    // Target field
    var targetField: RenameField = .title

    // Source channels (set by caller)
    var sourceChannels: [M3UChannel] = []

    // MARK: - Preview

    var previewPairs: [(original: String, renamed: String)] {
        sourceChannels.prefix(100).enumerated().map { (idx, ch) in
            let original = fieldValue(of: ch, for: targetField)
            let renamed = applyOperation(to: original, channel: ch, index: idx)
            return (original, renamed)
        }
    }

    var hasChanges: Bool {
        previewPairs.contains { $0.original != $0.renamed }
    }

    // MARK: - Apply

    func applyRename(to channels: inout [M3UChannel]) {
        for (idx, _) in channels.enumerated() {
            let ch = channels[idx]
            switch targetField {
            case .title:
                channels[idx].title = applyOperation(to: ch.title, channel: ch, index: idx)
            case .tvgName:
                channels[idx].tvgName = applyOperation(to: ch.tvgName, channel: ch, index: idx)
            case .both:
                channels[idx].title   = applyOperation(to: ch.title,   channel: ch, index: idx)
                channels[idx].tvgName = applyOperation(to: ch.tvgName, channel: ch, index: idx)
            }
        }
    }

    // MARK: - Private

    private func fieldValue(of channel: M3UChannel, for field: RenameField) -> String {
        switch field {
        case .title:   return channel.title
        case .tvgName: return channel.tvgName
        case .both:    return channel.title
        }
    }

    private func applyOperation(to string: String, channel: M3UChannel, index: Int) -> String {
        switch operation {
        case .findReplace:
            guard !findText.isEmpty else { return string }
            return string.replacingOccurrences(of: findText, with: replaceText)

        case .regexReplace:
            guard !findText.isEmpty,
                  let regex = try? NSRegularExpression(pattern: findText) else { return string }
            let range = NSRange(string.startIndex..., in: string)
            return regex.stringByReplacingMatches(
                in: string, range: range, withTemplate: replaceText)

        case .prefix:
            return affixText + string

        case .suffix:
            return string + affixText

        case .caseTransform:
            return caseTransform.apply(to: string)

        case .pattern:
            return patternText
                .replacingOccurrences(of: "{name}",  with: string)
                .replacingOccurrences(of: "{group}", with: channel.groupTitle)
                .replacingOccurrences(of: "{id}",    with: channel.tvgId)
                .replacingOccurrences(of: "{index}", with: "\(index + 1)")
                .replacingOccurrences(of: "{INDEX}", with: String(format: "%04d", index + 1))

        case .cleanSpaces:
            return string
                .trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
    }
}
