import SwiftUI

struct BulkRenameView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = RenameViewModel()
    @Environment(\.dismiss) private var dismiss

    let playlist: M3UPlaylist?
    let selectedIds: Set<UUID>

    private var targetChannels: [M3UChannel] {
        guard let playlist else { return [] }
        if selectedIds.isEmpty {
            return playlist.channels
        }
        return playlist.channels.filter { selectedIds.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "textformat")
                    .font(.title2)
                    .foregroundStyle(.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bulk Rename")
                        .font(.headline)
                    Text(selectedIds.isEmpty
                         ? "All \(targetChannels.count) channels"
                         : "\(targetChannels.count) selected channels")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", action: { dismiss() })
                    .keyboardShortcut(.escape)
            }
            .padding()
            .background(.bar)

            Divider()

            HStack(alignment: .top, spacing: 0) {
                // Left – controls
                Form {
                    Section("Operation") {
                        Picker("", selection: $vm.operation) {
                            ForEach(RenameOperation.allCases) { op in
                                Label(op.rawValue, systemImage: op.systemImage)
                                    .tag(op)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                    }

                    Section("Options") {
                        switch vm.operation {
                        case .findReplace:
                            TextField("Find", text: $vm.findText)
                            TextField("Replace with", text: $vm.replaceText)

                        case .regexReplace:
                            TextField("Regex pattern", text: $vm.findText)
                                .font(.body.monospaced())
                            TextField("Replace with", text: $vm.replaceText)

                        case .prefix, .suffix:
                            TextField(
                                vm.operation == .prefix ? "Prefix text" : "Suffix text",
                                text: $vm.affixText
                            )

                        case .caseTransform:
                            Picker("Transform", selection: $vm.caseTransform) {
                                ForEach(CaseTransform.allCases) { t in
                                    Text(t.rawValue).tag(t)
                                }
                            }
                            .pickerStyle(.radioGroup)

                        case .pattern:
                            TextField("Pattern", text: $vm.patternText)
                                .font(.body.monospaced())
                            Text("Tokens: {name} {group} {id} {index} {INDEX}")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                        case .cleanSpaces:
                            Text("Trims leading/trailing spaces and collapses internal whitespace.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Apply To") {
                        Picker("Field", selection: $vm.targetField) {
                            ForEach(RenameField.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }
                }
                .formStyle(.grouped)
                .frame(width: 280)
                .onChange(of: targetChannels) { vm.sourceChannels = targetChannels }
                .onAppear { vm.sourceChannels = targetChannels }

                Divider()

                // Right – live preview
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Preview")
                            .font(.headline)
                        Spacer()
                        if vm.hasChanges {
                            Label("\(vm.previewPairs.filter { $0.original != $0.renamed }.count) changes",
                                  systemImage: "pencil.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else {
                            Text("No changes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)

                    Divider()

                    if vm.previewPairs.isEmpty {
                        Text("No channels to preview.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Table(vm.previewPairs.indices.map { i -> PreviewRow in
                            PreviewRow(
                                id: i,
                                original: vm.previewPairs[i].original,
                                renamed: vm.previewPairs[i].renamed
                            )
                        }) {
                            TableColumn("Original") { row in
                                Text(row.original)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            TableColumn("Result") { row in
                                Text(row.renamed)
                                    .foregroundStyle(
                                        row.original == row.renamed ? .secondary : .primary
                                    )
                                    .fontWeight(row.original == row.renamed ? .regular : .medium)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .frame(minWidth: 400)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)

                Button("Apply Rename") {
                    applyRename()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.hasChanges)
                .keyboardShortcut(.return)
            }
            .padding()
            .background(.bar)
        }
        .frame(minWidth: 720, minHeight: 480)
    }

    private func applyRename() {
        guard let playlist else { return }
        if selectedIds.isEmpty {
            vm.applyRename(to: &playlist.channels)
        } else {
            // Apply only to selected
            var channels = playlist.channels
            let indices = channels.indices.filter { selectedIds.contains(channels[$0].id) }
            var subset = indices.map { channels[$0] }
            vm.applyRename(to: &subset)
            for (i, idx) in indices.enumerated() {
                channels[idx] = subset[i]
            }
            playlist.channels = channels
        }
        playlist.isModified = true
    }
}

// MARK: - Preview row helper

private struct PreviewRow: Identifiable {
    let id: Int
    let original: String
    let renamed: String
}
