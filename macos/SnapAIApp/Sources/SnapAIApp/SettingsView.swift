import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var openAIKey = ""
    @State private var geminiKey = ""

    var body: some View {
        Form {
            if model.statusMessage.localizedCaseInsensitiveContains("keychain") ||
                model.statusMessage.localizedCaseInsensitiveContains("couldn't access") {
                Section {
                    Label {
                        Text(model.statusMessage)
                            .font(.subheadline)
                            .textSelection(.enabled)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                PageHeader(
                    eyebrow: "SETTINGS",
                    title: "Secure by default.",
                    subtitle: "Credentials stay in Keychain. Files stay in folders you choose."
                )
                .padding(.vertical, 8)
            }

            Section("Provider credentials") {
                credentialRow(
                    title: "OpenAI",
                    placeholder: "sk-…",
                    isConfigured: model.openAIConfigured,
                    value: $openAIKey,
                    account: "openai-api-key"
                )
                credentialRow(
                    title: "Google Gemini",
                    placeholder: "AIza…",
                    isConfigured: model.geminiConfigured,
                    value: $geminiKey,
                    account: "google-api-key"
                )

                Text("Keys are never shown in full, written to JSON, or included in generation history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Output folder") {
                HStack {
                    Label(model.outputFolder?.path ?? "No folder selected", systemImage: "folder")
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose Folder") {
                        model.chooseOutputFolder()
                    }
                }

                Text("SnapAI requests access only to the folder you select and remembers it with a security-scoped bookmark.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Local generation core") {
                HStack {
                    Label(
                        model.coreReady ? "Connected" : "Unavailable",
                        systemImage: model.coreReady ? "checkmark.circle.fill" : "exclamationmark.triangle"
                    )
                    .foregroundStyle(model.coreReady ? .green : .orange)
                    Spacer()
                    Button("Restart") {
                        model.restartCore()
                    }
                }
                Text(model.coreStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Accessibility and appearance") {
                Label("Uses semantic system colors for Light and Dark Mode.", systemImage: "circle.lefthalf.filled")
                Label("Supports keyboard commands and VoiceOver-friendly labels.", systemImage: "accessibility")
                Label("Avoids decorative motion when Reduce Motion is enabled.", systemImage: "figure.walk.motion")
            }

            Section("Status") {
                Text(model.statusMessage)
                    .foregroundStyle(.secondary)
                Text("Native macOS shell · MVP foundation")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 760)
        .padding(32)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Settings")
    }

    @ViewBuilder
    private func credentialRow(
        title: String,
        placeholder: String,
        isConfigured: Bool,
        value: Binding<String>,
        account: String
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    Label(
                        isConfigured ? "Configured" : "Not configured",
                        systemImage: isConfigured ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.caption)
                    .foregroundStyle(isConfigured ? .green : .secondary)
                }

                SecureField(placeholder, text: value)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 360)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Button("Save") {
                    model.saveProviderKey(value.wrappedValue, account: account)
                    value.wrappedValue = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(value.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if isConfigured {
                    Button("Remove", role: .destructive) {
                        model.removeProviderKey(account: account)
                    }
                    .buttonStyle(.link)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
