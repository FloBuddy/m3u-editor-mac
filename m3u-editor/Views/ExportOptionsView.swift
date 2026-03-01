import SwiftUI

struct ExportOptionsView: View {
    @Environment(\.dismiss) private var dismiss

    let playlist: M3UPlaylist?

    @State private var format: ExportService.Format = .m3u
    @State private var includeDisabled: Bool = true
    @State private var exportScope: ExportScope = .all

    enum ExportScope: String, CaseIterable, Identifiable {
        case all      = "All Channels"
        case enabled  = "Enabled Only"
        case disabled = "Disabled Only"
        var id: String { rawValue }
    }

    private var channelsToExport: [M3UChannel] {
        guard let playlist else { return [] }
        switch exportScope {
        case .all:      return playlist.channels
        case .enabled:  return playlist.channels.filter(\.isEnabled)
        case .disabled: return playlist.channels.filter { !$0.isEnabled }
        }
    }

    private var previewContent: String {
        let preview = ExportService.export(
            channels: Array(channelsToExport.prefix(10)),
            format: format,
            includeDisabled: true
        )
        let suffix = channelsToExport.count > 10
            ? "\n\n… and \(channelsToExport.count - 10) more"
            : ""
        return preview + suffix
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export Playlist")
                        .font(.headline)
                    Text(playlist?.name ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()
            .background(.bar)

            Divider()

            HStack(alignment: .top, spacing: 0) {
                // Options
                Form {
                    Section("Format") {
                        ForEach(ExportService.Format.allCases) { fmt in
                            HStack {
                                Image(systemName: fmt.systemImage)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 20)
                                Text(fmt.rawValue)
                                Spacer()
                                if format == fmt {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { format = fmt }
                        }
                    }

                    Section("Channels") {
                        Picker("Include", selection: $exportScope) {
                            ForEach(ExportScope.allCases) { scope in
                                Text(scope.rawValue).tag(scope)
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }

                    Section("Stats") {
                        LabeledContent("Channels", value: "\(channelsToExport.count)")
                        LabeledContent("Format", value: format.rawValue)
                        LabeledContent("Extension", value: ".\(format.fileExtension)")
                    }
                }
                .formStyle(.grouped)
                .frame(width: 260)

                Divider()

                // Preview
                VStack(alignment: .leading, spacing: 0) {
                    Text("Preview")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.vertical, 10)

                    Divider()

                    ScrollView {
                        Text(previewContent)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .textSelection(.enabled)
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)

                Button("Export…") {
                    let content = ExportService.export(
                        channels: channelsToExport,
                        format: format,
                        includeDisabled: true
                    )
                    ExportService.saveWithPanel(
                        content: content,
                        suggestedName: playlist?.name ?? "export",
                        format: format
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(channelsToExport.isEmpty)
                .keyboardShortcut(.return)
            }
            .padding()
            .background(.bar)
        }
        .frame(minWidth: 680, minHeight: 460)
    }
}
