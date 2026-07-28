import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var stepDirection: Edge = .trailing
    @State private var openAIKey = ""
    @State private var geminiKey = ""
    @State private var geminiSkipped = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(height: 5)
                        .animation(
                            reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.85),
                            value: step
                        )
                }
            }
            .frame(maxWidth: 520)
            .padding(.top, 34)
            .accessibilityLabel("Setup step \(step + 1) of 3")

            Spacer()

            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.accentColor.gradient)
                            .frame(width: 52, height: 52)
                        Image(systemName: "wand.and.stars")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("SnapAI")
                            .font(.title2.weight(.bold))
                            .tracking(-0.015)
                        Text("Private, local-first image generation")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                stepContent
                    .id(step)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .move(edge: stepDirection).combined(with: .opacity),
                                removal: .move(edge: stepDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
                            )
                    )
                    .animation(
                        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.95),
                        value: step
                    )
            }
            .frame(maxWidth: 620, alignment: .leading)

            Spacer()
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            welcomeStep
        case 1:
            providerStep
        default:
            outputStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Let’s get your studio ready.")
                .font(.largeTitle.weight(.bold))
                .tracking(-0.022)
                .lineSpacing(2)
            Text("A quick setup keeps the rest of SnapAI focused: choose a provider, a save location, and start creating.")
                .font(.title3)
                .foregroundStyle(.secondary)

            SurfaceCard {
                VStack(alignment: .leading, spacing: 13) {
                    privacyRow(
                        title: "Keys stay in Keychain",
                        detail: "SnapAI never writes provider credentials to its local state or history.",
                        symbol: "key.fill"
                    )
                    privacyRow(
                        title: "Files stay on your Mac",
                        detail: "Images are written only to folders you explicitly choose.",
                        symbol: "lock.shield"
                    )
                    privacyRow(
                        title: "No account required",
                        detail: "Requests go directly from this Mac to your selected provider.",
                        symbol: "network"
                    )
                }
            }

            HStack {
                Spacer()
                Button("Continue") {
                    stepDirection = .trailing
                    step = 1
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var providerStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Connect a provider")
                .font(.largeTitle.weight(.bold))
                .tracking(-0.022)
                .lineSpacing(2)
            Text("Your key is stored in macOS Keychain and passed to the local core only for a generation request.")
                .font(.title3)
                .foregroundStyle(.secondary)

            SurfaceCard {
                VStack(alignment: .leading, spacing: 16) {
                    credentialRow(
                        title: "OpenAI",
                        placeholder: "sk-…",
                        isConfigured: model.openAIConfigured,
                        value: $openAIKey,
                        account: "openai-api-key",
                        allowsSkip: false,
                        skipped: .constant(false)
                    )
                    Divider()
                    credentialRow(
                        title: "Google Gemini",
                        placeholder: "AIza…",
                        isConfigured: model.geminiConfigured,
                        value: $geminiKey,
                        account: "google-api-key",
                        allowsSkip: true,
                        skipped: $geminiSkipped
                    )
                    Text("Gemini is optional. You can connect it later from Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Back") {
                    stepDirection = .leading
                    step = 0
                }
                .buttonStyle(.borderless)
                Spacer()
                Button("Continue") {
                    stepDirection = .trailing
                    step = 2
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.openAIConfigured && !model.geminiConfigured)
            }
        }
    }

    private var outputStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Choose where images go")
                .font(.largeTitle.weight(.bold))
                .tracking(-0.022)
                .lineSpacing(2)
            Text("SnapAI will remember this folder using a security-scoped bookmark. You can override it for any individual run.")
                .font(.title3)
                .foregroundStyle(.secondary)

            SurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                        Text(model.outputFolder?.path ?? "No output folder selected")
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .foregroundStyle(model.outputFolder == nil ? .secondary : .primary)
                        Spacer()
                        Button("Choose Folder") {
                            model.chooseOutputFolder()
                        }
                        .buttonStyle(.bordered)
                    }

                    Divider()

                    HStack(spacing: 10) {
                        if model.coreReady {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.coreReady ? "Local core ready" : "Local core is starting")
                                .font(.subheadline.weight(.semibold))
                            Text(model.coreStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            HStack {
                Button("Back") {
                    stepDirection = .leading
                    step = 1
                }
                .buttonStyle(.borderless)
                Spacer()
                Button("Start creating") {
                    model.completeOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canCompleteOnboarding)
            }
        }
    }

    private func privacyRow(title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func credentialRow(
        title: String,
        placeholder: String,
        isConfigured: Bool,
        value: Binding<String>,
        account: String,
        allowsSkip: Bool,
        skipped: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Label(
                        isConfigured ? "Configured" : skipped.wrappedValue ? "Skipped for now" : "Not configured",
                        systemImage: isConfigured ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.caption)
                    .foregroundStyle(isConfigured ? .green : skipped.wrappedValue ? .orange : .secondary)
                }

                SecureField(placeholder, text: value)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("\(title) API key")
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Button("Save") {
                    model.saveProviderKey(value.wrappedValue, account: account)
                    value.wrappedValue = ""
                    skipped.wrappedValue = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(value.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if allowsSkip && !isConfigured {
                    Button("Skip for now") {
                        value.wrappedValue = ""
                        skipped.wrappedValue = true
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }
        }
    }
}
