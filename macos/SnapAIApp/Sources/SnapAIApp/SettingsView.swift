import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var openAIKey = ""
    @State private var geminiKey = ""
    @State private var isReplacingOpenAIKey = false
    @State private var isReplacingGeminiKey = false

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
                    isReplacing: $isReplacingOpenAIKey,
                    account: "openai-api-key"
                )
                credentialRow(
                    title: "Google Gemini",
                    placeholder: "AIza…",
                    isConfigured: model.geminiConfigured,
                    value: $geminiKey,
                    isReplacing: $isReplacingGeminiKey,
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
        isReplacing: Binding<Bool>,
        account: String
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    if isConfigured {
                        Label("Configured in Keychain", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("Not configured", systemImage: "circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if isConfigured && !isReplacing.wrappedValue {
                    Label("Your key is stored securely in Keychain.", systemImage: "key.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("API key stored securely in Keychain")
                } else {
                    SecureField(isConfigured ? "Enter replacement key" : placeholder, text: value)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 360)
                        .accessibilityLabel(isConfigured ? "Replacement \(title) API key" : "\(title) API key")

                    if isConfigured {
                        Text("Your existing key remains active until you save the replacement.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                if isConfigured {
                    if isReplacing.wrappedValue {
                        Button("Save Replacement") {
                            model.saveProviderKey(value.wrappedValue, account: account)
                            value.wrappedValue = ""
                            isReplacing.wrappedValue = false
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(value.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button("Cancel") {
                            value.wrappedValue = ""
                            isReplacing.wrappedValue = false
                        }
                        .buttonStyle(.link)
                    } else {
                        Button("Replace Key") {
                            isReplacing.wrappedValue = true
                        }
                        .buttonStyle(.bordered)
                        .accessibilityHint("Reveals a field to replace the stored \(title) API key")
                    }

                    Button("Remove", role: .destructive) {
                        model.removeProviderKey(account: account)
                        value.wrappedValue = ""
                        isReplacing.wrappedValue = false
                    }
                    .buttonStyle(.link)
                } else {
                    Button("Save") {
                        model.saveProviderKey(value.wrappedValue, account: account)
                        value.wrappedValue = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(value.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
