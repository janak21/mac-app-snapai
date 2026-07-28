import Combine
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedSection: AppSection = .create
    @Published private(set) var navigationHistory: [AppSection] = []
    @Published var draft = GenerationDraft()
    @Published var promptPreview = ""
    @Published var statusMessage = "Ready when you are."
    @Published var isGenerating = false
    @Published var generationPhase: GenerationPhase = .idle
    @Published var results: [ResultItem] = []
    @Published private(set) var profiles: [StoredProfile] = []
    @Published private(set) var history: [StoredHistoryEntry] = []
    @Published var openAIConfigured = false
    @Published var geminiConfigured = false
    @Published var outputFolder: URL?
    @Published var coreReady = false
    @Published var coreStatus = "Starting local generation core…"
    @Published private(set) var onboardingComplete = false

    let toast = ToastCenter()

    var reduceMotion = false

    private var sectionAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.3, dampingFraction: 1.0)
    }

    private var stateAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.85)
    }

    private func runAnimated(_ body: () -> Void) {
        withAnimation(stateAnimation, body)
    }

    let keychain = KeychainStore()
    let folderAccess = FolderAccessStore()
    let store: NativeStore
    private var coreProcess: LocalCoreProcess?
    private var coreClient: LocalCoreClient?
    private var generationTask: Task<Void, Never>?

    var canGoBack: Bool {
        !navigationHistory.isEmpty
    }

    init() {
        let store = NativeStore()
        self.store = store
        let savedState = store.load()
        onboardingComplete = savedState.hasCompletedOnboarding
        var loadedProfiles = savedState.profiles
        if loadedProfiles.isEmpty {
            loadedProfiles = AppModel.defaultProfiles
        }
        profiles = loadedProfiles
        history = savedState.history
        openAIConfigured = keychain.contains(account: "openai-api-key")
        geminiConfigured = keychain.contains(account: "google-api-key")
        outputFolder = folderAccess.restoreFolder()
        draft.outputFolder = outputFolder
        coreProcess = LocalCoreProcess()
        Task { @MainActor in
            await bootstrapCore()
        }
    }

    static var defaultProfiles: [StoredProfile] {
        [
            StoredProfile(
                id: UUID(),
                name: "3D App Icon Studio",
                prompt: "A glossy 3D icon of a futuristic rocket ship, smooth metallic surfaces, neon accent lighting, isometric perspective",
                draft: PersistedDraft(
                    style: "3D Icon",
                    model: ModelOption.banana2.rawValue,
                    quality: "1K",
                    count: 1,
                    background: "Auto",
                    outputFormat: "PNG",
                    outputFolderPath: nil,
                    fileName: "3d_rocket_icon",
                    rawPrompt: false,
                    useIconWords: true,
                    thinking: "Minimal"
                ),
                createdAt: Date()
            ),
            StoredProfile(
                id: UUID(),
                name: "Cyberpunk Character Studio",
                prompt: "A breathtaking cyberpunk street character with glowing neon implants, rain-slicked dark alley background",
                draft: PersistedDraft(
                    style: "Cyberpunk",
                    model: ModelOption.bananaPro.rawValue,
                    quality: "1K",
                    count: 1,
                    background: "Auto",
                    outputFormat: "PNG",
                    outputFolderPath: nil,
                    fileName: "cyberpunk_hero",
                    rawPrompt: false,
                    useIconWords: false,
                    thinking: "Minimal"
                ),
                createdAt: Date()
            ),
            StoredProfile(
                id: UUID(),
                name: "Glassmorphism UI Studio",
                prompt: "Clean frosted glass UI element card, rounded squircle frame, translucent blur backdrop, elegant minimal aesthetic",
                draft: PersistedDraft(
                    style: "UI Design",
                    model: ModelOption.gptImage2.rawValue,
                    quality: "Auto",
                    count: 1,
                    background: "Transparent",
                    outputFormat: "PNG",
                    outputFolderPath: nil,
                    fileName: "glass_ui_card",
                    rawPrompt: false,
                    useIconWords: true,
                    thinking: "Minimal"
                ),
                createdAt: Date()
            ),
            StoredProfile(
                id: UUID(),
                name: "Photorealistic Portrait Studio",
                prompt: "Photorealistic studio portrait, soft warm key lighting, shallow depth of field, 8k resolution, cinematic atmosphere",
                draft: PersistedDraft(
                    style: "Photorealistic",
                    model: ModelOption.gpt15.rawValue,
                    quality: "High",
                    count: 1,
                    background: "Opaque",
                    outputFormat: "PNG",
                    outputFolderPath: nil,
                    fileName: "studio_portrait",
                    rawPrompt: false,
                    useIconWords: false,
                    thinking: "Minimal"
                ),
                createdAt: Date()
            )
        ]
    }

    func selectSection(_ section: AppSection) {
        guard section != selectedSection else { return }
        navigationHistory.append(selectedSection)
        selectedSection = section
    }

    func goBack() {
        guard let previousSection = navigationHistory.popLast() else { return }
        selectedSection = previousSection
    }

    func previewPrompt() {
        let trimmedPrompt = draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            promptPreview = "Enter a prompt to preview the resolved generation instructions."
            statusMessage = "A prompt is required before previewing."
            return
        }

        if let coreClient {
            let currentDraft = draft
            Task { @MainActor in
                do {
                    promptPreview = try await coreClient.preview(prompt: trimmedPrompt, draft: currentDraft)
                    statusMessage = "Prompt preview updated by the shared core."
                } catch {
                    statusMessage = "Prompt preview failed: \(error.localizedDescription)"
                }
            }
            return
        }

        var lines = [trimmedPrompt]
        if !draft.style.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Style: \(draft.style.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        lines.append("Model: \(draft.model.rawValue)")
        lines.append("Square output: 1024 × 1024")
        promptPreview = lines.joined(separator: "\n\n")
        statusMessage = "Prompt preview updated."
    }

    func requestGeneration() {
        guard !isGenerating else {
            return
        }

        let trimmedPrompt = draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            statusMessage = "Add a prompt before generating."
            return
        }

        guard trimmedPrompt.count <= 1000 else {
            statusMessage = "Keep the prompt to 1,000 characters or fewer."
            return
        }

        guard draft.outputFolder != nil || outputFolder != nil else {
            statusMessage = "Choose an output folder before generating."
            selectSection(.settings)
            return
        }

        let needsOpenAI = draft.model.provider == .openAI
        let providerConfigured = needsOpenAI ? openAIConfigured : geminiConfigured
        guard providerConfigured else {
            statusMessage = "Configure the selected provider before generating."
            selectSection(.settings)
            return
        }

        let selectedCredential = keychain.read(account: needsOpenAI ? "openai-api-key" : "google-api-key")
        guard let selectedCredential, !selectedCredential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let providerName = needsOpenAI ? "OpenAI" : "Google Gemini"
            generationPhase = .idle
            statusMessage = "SnapAI couldn't access your \(providerName) API key. Unlock Keychain or re-save it in Settings, then try again."
            selectSection(.settings)
            return
        }

        guard let coreClient else {
            statusMessage = coreStatus
            return
        }

        isGenerating = true
        runAnimated { generationPhase = .preparing }
        statusMessage = "Preparing \(draft.model.displayName)…"

        var currentDraft = draft
        if currentDraft.outputFolder == nil {
            currentDraft.outputFolder = outputFolder
        }
        let credentials = CoreCredentials(
            openai: needsOpenAI ? selectedCredential : nil,
            google: needsOpenAI ? nil : selectedCredential
        )

        generationTask = Task { @MainActor in
            do {
                runAnimated { generationPhase = .generating }
                statusMessage = "Generating with \(currentDraft.model.displayName)…"
                let result = try await coreClient.generate(
                    prompt: trimmedPrompt,
                    draft: currentDraft,
                    credentials: credentials
                )
                runAnimated { generationPhase = .saving }
                statusMessage = "Saving generated artwork…"
                runAnimated {
                    results = result.outputPaths.map { outputPath in
                        let url = outputPath.hasPrefix("/")
                            ? URL(fileURLWithPath: outputPath)
                            : URL(fileURLWithPath: outputPath, relativeTo: coreClient.rootDirectory).standardizedFileURL
                        return ResultItem(
                            title: url.deletingPathExtension().lastPathComponent,
                            detail: "\(result.model) · \(result.provider)",
                            outputURL: url
                        )
                    }
                }
                let historyEntry = StoredHistoryEntry(
                    id: UUID(),
                    createdAt: Date(),
                    prompt: trimmedPrompt,
                    finalPrompt: result.finalPrompt,
                    provider: result.provider,
                    model: result.model,
                    draft: currentDraft.persisted,
                    outputPaths: results.compactMap { $0.outputURL?.path }
                )
                history.insert(historyEntry, at: 0)
                saveState()
                statusMessage = "Saved \(result.outputPaths.count) image\(result.outputPaths.count == 1 ? "" : "s") to the selected folder."
                runAnimated { generationPhase = .completed }
                toast.success("Saved \(result.outputPaths.count) image\(result.outputPaths.count == 1 ? "" : "s") to the selected folder.")
                selectSection(.create)
            } catch {
                let phase: GenerationPhase = if Task.isCancelled || Self.isCancellation(error) {
                    .cancelled
                } else {
                    .failed(error.localizedDescription)
                }
                runAnimated { generationPhase = phase }
                if Task.isCancelled || Self.isCancellation(error) {
                    statusMessage = "Generation cancelled. Your prompt and options were kept."
                    toast.info("Generation cancelled. Your work was preserved.")
                } else {
                    statusMessage = "Generation failed: \(error.localizedDescription)"
                    toast.error("Generation failed: \(error.localizedDescription)")
                }
            }
            isGenerating = false
            generationTask = nil
        }
    }

    func cancelGeneration() {
        guard isGenerating else {
            return
        }
        statusMessage = "Cancelling generation…"
        generationTask?.cancel()
    }

    func retryGeneration() {
        guard !isGenerating else {
            return
        }
        requestGeneration()
    }

    func bootstrapCore() async {
        guard let coreProcess else {
            coreStatus = "Local generation core is unavailable."
            return
        }

        do {
            coreClient = try await coreProcess.start()
            coreReady = true
            coreStatus = "Connected to the local generation core."
            statusMessage = coreStatus
        } catch {
            coreReady = false
            coreStatus = "Local core unavailable: \(error.localizedDescription)"
            statusMessage = coreStatus
        }
    }

    func restartCore() {
        cancelGeneration()
        coreProcess?.stop()
        coreClient = nil
        coreReady = false
        coreStatus = "Restarting local generation core…"
        Task { @MainActor in
            await bootstrapCore()
        }
    }

    func createProfile(named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusMessage = "Profile name is required."
            return
        }

        profiles.insert(
            StoredProfile(
                id: UUID(),
                name: trimmedName,
                prompt: draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.prompt,
                draft: draft.persisted,
                createdAt: Date()
            ),
            at: 0
        )
        saveState()
        statusMessage = "Profile \"\(trimmedName)\" saved."
    }

    func activateProfile(_ profile: StoredProfile) {
        let profilePrompt = profile.prompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var nextDraft = GenerationDraft(persisted: profile.draft, prompt: profilePrompt.isEmpty ? draft.prompt : profilePrompt)
        if nextDraft.outputFolder == nil {
            nextDraft.outputFolder = outputFolder
        }
        draft = nextDraft
        statusMessage = "Profile \"\(profile.name)\" applied."
        selectSection(.create)
    }

    func updateProfile(_ profile: StoredProfile, name: String, prompt: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusMessage = "Profile name is required."
            return
        }

        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            statusMessage = "Profile not found."
            return
        }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        profiles[index].name = trimmedName
        profiles[index].prompt = trimmedPrompt.isEmpty ? nil : trimmedPrompt
        saveState()
        statusMessage = "Profile \"\(trimmedName)\" updated."
    }

    func duplicateProfile(_ profile: StoredProfile) {
        profiles.insert(
            StoredProfile(
                id: UUID(),
                name: "\(profile.name) copy",
                prompt: profile.prompt,
                draft: profile.draft,
                createdAt: Date()
            ),
            at: 0
        )
        saveState()
        statusMessage = "Profile duplicated."
    }

    func deleteProfile(_ profile: StoredProfile) {
        profiles.removeAll { $0.id == profile.id }
        saveState()
        statusMessage = "Profile \"\(profile.name)\" deleted."
    }

    func rerun(_ entry: StoredHistoryEntry) {
        var nextDraft = GenerationDraft(persisted: entry.draft, prompt: entry.prompt)
        if nextDraft.outputFolder == nil {
            nextDraft.outputFolder = outputFolder
        }
        draft = nextDraft
        promptPreview = entry.finalPrompt
        statusMessage = "Restored \(entry.displayDate) into Create."
        selectSection(.create)
    }

    func deleteHistory(_ entry: StoredHistoryEntry) {
        history.removeAll { $0.id == entry.id }
        saveState()
        statusMessage = "History entry deleted. Files were kept."
    }

    func reloadSharedState() {
        let savedState = store.load()
        profiles = savedState.profiles
        history = savedState.history
    }

    func clearHistory() {
        history.removeAll()
        saveState()
        statusMessage = "History cleared. Files were kept."
    }

    func chooseOutputFolder() {
        guard let folder = folderAccess.chooseFolder() else {
            return
        }
        outputFolder = folder
        draft.outputFolder = folder
        statusMessage = "Default output folder set to \(folder.path)."
    }

    func chooseOutputFolderForCurrentRun() {
        guard let folder = folderAccess.chooseFolder() else {
            return
        }
        draft.outputFolder = folder
        statusMessage = "This run will save to \(folder.path)."
    }

    var canCompleteOnboarding: Bool {
        (openAIConfigured || geminiConfigured) && outputFolder != nil
    }

    func completeOnboarding() {
        guard canCompleteOnboarding else {
            statusMessage = "Finish provider setup and choose an output folder first."
            return
        }

        if !openAIConfigured, geminiConfigured {
            draft.model = .banana2
        } else {
            draft.model = .gptImage2
        }
        onboardingComplete = true
        saveState()
        statusMessage = coreReady ? "Setup complete. Ready to create." : "Setup complete. The local core is still starting."
    }

    func useDefaultOutputFolder() {
        guard let outputFolder else {
            statusMessage = "Choose a default output folder in Settings first."
        selectSection(.settings)
            return
        }
        draft.outputFolder = outputFolder
        statusMessage = "This run will use the default output folder."
    }

    func adaptDraft(for model: ModelOption) {
        draft.quality = model.qualityOptions.first ?? "Auto"
        draft.count = min(draft.count, model.supportsBatch ? 10 : 1)
        if !model.supportsTransparency {
            draft.background = "Auto"
        }
        if model != .banana2 {
            draft.thinking = "Minimal"
        }
    }

    func saveProviderKey(_ value: String, account: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = "Enter a key before saving."
            return
        }

        do {
            try keychain.save(trimmed, account: account)
            if account == "openai-api-key" {
                openAIConfigured = true
            } else if account == "google-api-key" {
                geminiConfigured = true
            }
            statusMessage = "Credential saved securely in Keychain."
            toast.success("Credential saved securely in Keychain.")
        } catch {
            statusMessage = error.localizedDescription
            toast.error("Failed to save credential: \(error.localizedDescription)")
        }
    }

    func removeProviderKey(account: String) {
        do {
            try keychain.delete(account: account)
            if account == "openai-api-key" {
                openAIConfigured = false
            } else if account == "google-api-key" {
                geminiConfigured = false
            }
            statusMessage = "Credential removed from Keychain."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func saveState() {
        _ = store.save(
            NativeStoreState(
                hasCompletedOnboarding: onboardingComplete,
                profiles: profiles,
                history: history
            )
        )
        NotificationCenter.default.post(name: .snapAISharedStateChanged, object: nil)
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .cancelled
        }
        return false
    }
}
