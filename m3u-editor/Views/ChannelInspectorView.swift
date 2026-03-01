import SwiftUI

// MARK: - Inspector root

struct ChannelInspectorView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let channel = appState.firstSelectedChannel {
                // .id forces full re-init when a different channel is selected
                InspectorContent(channel: channel) { updated in
                    appState.updateChannel(updated)
                }
                .id(channel.id)
            } else {
                emptyState
            }
        }
        .frame(width: 270)
        .background(.background)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Select a channel\nto inspect")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Inspector content (owns the draft state)

private struct InspectorContent: View {
    let channel: M3UChannel
    let onSave: (M3UChannel) -> Void

    @State private var draft: M3UChannel

    init(channel: M3UChannel, onSave: @escaping (M3UChannel) -> Void) {
        self.channel = channel
        self.onSave = onSave
        self._draft = State(initialValue: channel)
    }

    private var isDirty: Bool { draft != channel }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Logo + name header
                headerSection

                Divider()

                VStack(alignment: .leading, spacing: 20) {
                    inspectorSection("Channel Info") {
                        InspectorField("Title",   text: $draft.title)
                        InspectorField("TVG Name", text: $draft.tvgName)
                        InspectorField("TVG ID",   text: $draft.tvgId)
                        InspectorField("Group",    text: $draft.groupTitle)
                    }

                    inspectorSection("Media") {
                        InspectorField("Logo URL",   text: $draft.tvgLogo)
                        InspectorField("Stream URL", text: $draft.url, monospaced: true)
                    }

                    inspectorSection("Options") {
                        Toggle("Enabled", isOn: $draft.isEnabled)
                            .toggleStyle(.switch)
                    }

                    if !channel.additionalAttributes.isEmpty {
                        inspectorSection("Extra Attributes") {
                            ForEach(
                                channel.additionalAttributes
                                    .sorted(by: { $0.key < $1.key }),
                                id: \.key
                            ) { k, v in
                                HStack {
                                    Text(k)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(v)
                                        .font(.caption.monospaced())
                                        .lineLimit(1)
                                }
                            }
                        }
                    }

                    // Apply / Revert
                    if isDirty {
                        HStack {
                            Button("Revert") { draft = channel }
                                .buttonStyle(.bordered)
                            Spacer()
                            Button("Apply") { onSave(draft) }
                                .buttonStyle(.borderedProminent)
                        }
                    }

                    Divider()

                    // Quick actions
                    inspectorSection("Quick Actions") {
                        Button("Copy Stream URL") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(channel.url, forType: .string)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)

                        Button("Open in Browser") {
                            if let url = URL(string: channel.url) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .disabled(URL(string: channel.url) == nil)
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 8) {
            Group {
                if let url = URL(string: channel.tvgLogo), !channel.tvgLogo.isEmpty {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        default:
                            logoPlaceholder
                        }
                    }
                } else {
                    logoPlaceholder
                }
            }
            .frame(height: 60)

            Text(channel.displayName)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if !channel.groupTitle.isEmpty {
                Text(channel.groupTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
    }

    private var logoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "tv")
                    .foregroundStyle(.tertiary)
                    .font(.title2)
            }
    }

    @ViewBuilder
    private func inspectorSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }
}

// MARK: - Inspector field

private struct InspectorField: View {
    let label: String
    @Binding var text: String
    var monospaced: Bool = false

    init(_ label: String, text: Binding<String>, monospaced: Bool = false) {
        self.label = label
        self._text = text
        self.monospaced = monospaced
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(monospaced ? .caption.monospaced() : .caption)
        }
    }
}
