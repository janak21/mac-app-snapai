import AppKit
import SwiftUI

struct CreateView: View {
    @ObservedObject var model: AppModel
    @State private var selectedResultID: ResultItem.ID?
    @State private var showingPromptTemplates = false
    @FocusState private var promptFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create")
                        .font(.title2.weight(.semibold))
                        .tracking(-0.015)
                    Text("Describe a direction, choose the constraints, and compare the results in one workspace.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if model.coreReady {
                    Label("Core ready", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Starting local core", systemImage: "circle.dotted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            GeometryReader { proxy in
                if proxy.size.width >= 1050 {
                    HStack(spacing: 0) {
                        formColumn
                            .frame(maxWidth: 700)

                        Divider()

                        resultsColumn
                            .frame(minWidth: 360, maxWidth: 520)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            formColumn
                            Divider()
                            resultsColumn
                        }
                        .padding(24)
                    }
                }
            }
            .overlay(alignment: .top) {
                ScrollEdgeFade(edge: .top)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Create")
        .onChange(of: model.results.count) { _, _ in
            selectedResultID = model.results.first?.id
        }
        .onChange(of: model.isGenerating) { wasGenerating, isGenerating in
            guard wasGenerating,
                  !isGenerating,
                  model.generationPhase == .completed,
                  !model.results.isEmpty
            else {
                return
            }

            selectedResultID = model.results.first?.id
            model.selectSection(.library)
        }
    }

    private var formColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if model.generationPhase.shouldShowStatus {
                    generationStatusCard
                }

                sessionSummaryCard
                promptCard
                controlsCard
                outputCard
                promptPreviewCard
            }
            .padding(24)
        }
        .overlay(alignment: .bottom) {
            ScrollEdgeFade(edge: .bottom)
        }
    }

    private var canRequestGeneration: Bool {
        let prompt = model.draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return !model.isGenerating && !prompt.isEmpty && prompt.count <= 1000
    }

    private func requestGeneration() {
        promptFocused = false
        model.requestGeneration()
    }

    private var resultsColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current results")
                        .font(.title3.weight(.semibold))
                        .tracking(-0.011)
                    Text(model.results.isEmpty ? "Your next generation will appear here." : "Select a direction to inspect and act on it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !model.results.isEmpty {
                    Text("\(model.results.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if model.results.isEmpty {
                ContentUnavailableView(
                    "No results yet",
                    systemImage: "square.grid.2x2",
                    description: Text("Generate a direction to compare it here without leaving Create.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                        ForEach(model.results) { result in
                            resultTile(result)
                        }
                    }

                    if let selectedResult {
                        resultInspector(selectedResult)
                            .padding(.top, 4)
                    }
                }
                .overlay(alignment: .bottom) {
                    ScrollEdgeFade(edge: .bottom, color: Color(nsColor: .underPageBackgroundColor))
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var selectedResult: ResultItem? {
        guard let selectedResultID else { return model.results.first }
        return model.results.first { $0.id == selectedResultID } ?? model.results.first
    }

    private func resultTile(_ result: ResultItem) -> some View {
        Button {
            selectedResultID = result.id
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                resultPreview(result)
                Text(result.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(result.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selectedResultID == result.id ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: selectedResultID == result.id ? 2 : 1)
            }
        }
        .buttonStyle(DeckTileButtonStyle())
        .contextMenu {
            resultActions(result)
        }
        .onDrag {
            if let url = result.outputURL {
                DragSupport.provider(for: url)
            } else {
                NSItemProvider()
            }
        }
        .accessibilityLabel("Generated result \(result.title)")
        .accessibilityValue(selectedResultID == result.id ? "Selected" : "Not selected")
        .help("Drag to Finder to copy, or Control-click for actions")
    }

    @ViewBuilder
    private func resultActions(_ result: ResultItem) -> some View {
        if let url = result.outputURL {
            Button("Quick Look") {
                QuickLookService.shared.show(url: url)
            }
            Button("Open") {
                NSWorkspace.shared.open(url)
            }
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            Button("Copy path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.path, forType: .string)
                model.statusMessage = "Copied the output path."
            }
        }
    }

    private func resultInspector(_ result: ResultItem) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Selected direction")
                    .font(.subheadline.weight(.semibold))
                Text(result.title)
                    .font(.headline)
                Text(result.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let url = result.outputURL {
                    Text(url.path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    HStack(spacing: 12) {
                        Button("Quick Look") {
                            QuickLookService.shared.show(url: url)
                        }
                        .buttonStyle(.bordered)

                        Button("Open") {
                            NSWorkspace.shared.open(url)
                        }
                        .buttonStyle(.link)

                        Button("Reveal") {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                        .buttonStyle(.link)

                        Button("Copy path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url.path, forType: .string)
                            model.statusMessage = "Copied the output path."
                        }
                        .buttonStyle(.link)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func resultPreview(_ result: ResultItem) -> some View {
        if let outputURL = result.outputURL {
            ThumbnailView(url: outputURL, maxDimension: 260, cornerRadius: 8)
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .aspectRatio(1, contentMode: .fit)
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
    }

    private var generationStatusCard: some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: 12) {
                if model.generationPhase.isActive {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Generation in progress")
                } else {
                    Image(systemName: model.generationPhase.systemImage)
                        .foregroundStyle(model.generationPhase.isFailure ? .red : .secondary)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.generationPhase.title)
                        .font(.headline)
                    Text(model.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer()

                if model.generationPhase.isActive {
                    Button("Cancel", role: .cancel) {
                        model.cancelGeneration()
                    }
                    .buttonStyle(.bordered)
                } else if model.generationPhase.isFailure || model.generationPhase == .cancelled {
                    Button("Retry", systemImage: "arrow.clockwise") {
                        model.retryGeneration()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var sessionSummaryCard: some View {
        SurfaceCard {
            HStack(spacing: 14) {
                Label(model.draft.model.displayName, systemImage: "cpu")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Divider()
                    .frame(height: 18)

                Label(
                    model.draft.outputFolder?.path ?? model.outputFolder?.path ?? "Choose an output folder",
                    systemImage: "folder"
                )
                .font(.caption)
                .foregroundStyle((model.draft.outputFolder ?? model.outputFolder) == nil ? .orange : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)

                Spacer(minLength: 0)

                Button((model.draft.outputFolder ?? model.outputFolder) == nil ? "Choose" : "Change") {
                    model.chooseOutputFolderForCurrentRun()
                }
                .buttonStyle(.link)
            }
            .help("Active model and output folder")
        }
    }

    private var promptCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    SectionHeading(title: "Prompt Composer", subtitle: "Describe your creative direction. Select preset style chips below.")
                    Spacer()
                    Button("Templates Catalog", systemImage: "text.badge.plus") {
                        showingPromptTemplates = true
                    }
                    .buttonStyle(.bordered)
                    .help("Insert a prompt idea or visual style from the built-in catalog")

                    Button {
                        requestGeneration()
                    } label: {
                        HStack(spacing: 6) {
                            if #available(macOS 15.0, *) {
                                Image(systemName: "sparkles")
                                    .symbolEffect(
                                        .variableColor.iterative.dimInactiveLayers.nonReversing,
                                        options: .repeat(.continuous),
                                        isActive: model.isGenerating
                                    )
                            } else {
                                Image(systemName: "sparkles")
                                    .symbolEffect(
                                        .variableColor.iterative.dimInactiveLayers.nonReversing,
                                        value: model.isGenerating
                                    )
                            }
                            Text(model.isGenerating ? "Generating" : "Generate")
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .foregroundStyle(.white)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(DeckTileButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canRequestGeneration)
                    .accessibilityLabel(model.isGenerating ? "Generating artwork" : "Generate artwork")
                    .accessibilityHint("Generates artwork from the current prompt and settings")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Preset Styles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            PillTag("Cinematic", icon: "film", isSelected: model.draft.style.contains("Cinematic")) {
                                toggleStyle("Cinematic")
                            }
                            PillTag("Cyberpunk", icon: "sparkles", isSelected: model.draft.style.contains("Cyberpunk")) {
                                toggleStyle("Cyberpunk")
                            }
                            PillTag("3D Icon", icon: "cube.fill", isSelected: model.draft.style.contains("3D Icon")) {
                                toggleStyle("3D Icon")
                            }
                            PillTag("Photorealistic", icon: "camera.fill", isSelected: model.draft.style.contains("Photorealistic")) {
                                toggleStyle("Photorealistic")
                            }
                            PillTag("UI Design", icon: "paintpalette.fill", isSelected: model.draft.style.contains("UI Design")) {
                                toggleStyle("UI Design")
                            }
                        }
                    }
                }

                TextEditor(text: $model.draft.prompt)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 140)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(promptFocused ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: promptFocused ? 1.5 : 1)
                    }
                    .accessibilityLabel("Artwork prompt")
                    .focused($promptFocused)

                HStack {
                    Label("Try: a secure finance symbol with a bold shield silhouette", systemImage: "lightbulb")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(model.draft.prompt.count) / 1000")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(model.draft.prompt.count > 1000 ? .red : .secondary)
                }
            }
        }
        .popover(isPresented: $showingPromptTemplates, arrowEdge: .top) {
            promptTemplatePopover
        }
    }

    private func toggleStyle(_ name: String) {
        if model.draft.style.contains(name) {
            model.draft.style = model.draft.style.replacingOccurrences(of: name, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            if model.draft.style.isEmpty {
                model.draft.style = name
            } else {
                model.draft.style += ", \(name)"
            }
        }
    }

    private var promptTemplatePopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prompt templates")
                        .font(.headline)
                    Text("Insert a starting point, then edit the prompt to fit your product.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(PromptTemplateCatalog.categories, id: \.self) { category in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)

                        ForEach(PromptTemplateCatalog.all.filter { $0.category == category }) { template in
                            Button {
                                insert(template)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(template.title)
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Label("Insert", systemImage: "arrow.down.left")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    Text(template.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                    Text(template.prompt)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            }
                            .buttonStyle(DeckTileButtonStyle())
                        }
                    }
                }
            }
            .padding(18)
        }
        .frame(width: 350, height: 480)
    }

    private func insert(_ template: PromptTemplate) {
        let existingPrompt = model.draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !template.prompt.isEmpty {
            model.draft.prompt = existingPrompt.isEmpty ? template.prompt : "\(existingPrompt)\n\n\(template.prompt)"
        }
        if let style = template.style {
            model.draft.style = style
        }
        model.promptPreview = ""
        model.statusMessage = "Inserted the \(template.title) template."
        showingPromptTemplates = false
        promptFocused = true
    }

    private var controlsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeading(title: "AI Model & Constraints", subtitle: "Select your engine: Google Gemini (Nano Banana) or OpenAI.")

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text("AI Model Engine")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(model.draft.model.provider.rawValue)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                                    .foregroundStyle(Color.accentColor)
                            }

                            Picker("Model", selection: $model.draft.model) {
                                Section("Google Gemini (Nano Banana)") {
                                    ForEach([ModelOption.banana2, .banana, .bananaPro]) { option in
                                        Text(option.displayName).tag(option)
                                    }
                                }
                                Section("OpenAI") {
                                    ForEach([ModelOption.gptImage2, .gpt15, .gpt1]) { option in
                                        Text(option.displayName).tag(option)
                                    }
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity)

                            Text(model.draft.model.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            Text("Quality")
                                .font(.subheadline.weight(.semibold))
                            Picker("Quality", selection: $model.draft.quality) {
                                ForEach(model.draft.model.qualityOptions, id: \.self) { value in
                                    Text(value).tag(value)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            Text("Variations")
                                .font(.subheadline.weight(.semibold))
                            Stepper(value: $model.draft.count, in: 1...10) {
                                Text("\(model.draft.count)")
                                    .monospacedDigit()
                                    .frame(minWidth: 24)
                            }
                            .disabled(!model.draft.model.supportsBatch)
                            Text(model.draft.model.supportsBatch ? "Up to 10" : "Single image")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: model.draft.model) { _, newModel in
                        model.adaptDraft(for: newModel)
                    }

                    DisclosureGroup("Advanced controls & thinking depth") {
                        VStack(alignment: .leading, spacing: 14) {
                            LabeledContent("Custom Style Modifier") {
                                TextField("e.g., octane render, 8k resolution", text: $model.draft.style)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 280)
                            }

                            HStack(spacing: 22) {
                                Toggle("Raw prompt", isOn: $model.draft.rawPrompt)
                                Toggle("Use icon words", isOn: $model.draft.useIconWords)
                            }
                            .toggleStyle(.checkbox)

                            HStack {
                                Text("Background")
                                    .font(.subheadline.weight(.semibold))
                                Picker("Background", selection: $model.draft.background) {
                                    Text("Auto").tag("Auto")
                                    Text("Opaque").tag("Opaque")
                                    Text("Transparent").tag("Transparent")
                                }
                                .labelsHidden()
                                .disabled(!model.draft.model.supportsTransparency)
                                if !model.draft.model.supportsTransparency {
                                    Text("Not supported by model")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if model.draft.model == .banana2 {
                                HStack {
                                    Text("Thinking Level")
                                        .font(.subheadline.weight(.semibold))
                                    Picker("Thinking", selection: $model.draft.thinking) {
                                        Text("Minimal").tag("Minimal")
                                        Text("Max").tag("Max")
                                    }
                                    .labelsHidden()
                                    Text("Controls Gemini reasoning steps for Nano Banana 2")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.top, 12)
                    }

                }
            }
        }
    }

    private var outputCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(title: "Output", subtitle: "Choose a destination for this run and give the files a useful base name.")

                HStack(alignment: .center, spacing: 12) {
                    Label(
                        model.draft.outputFolder?.path ?? "No folder selected",
                        systemImage: "folder"
                    )
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(model.draft.outputFolder == nil ? .secondary : .primary)

                    Spacer()

                    Button("Choose for this run") {
                        model.chooseOutputFolderForCurrentRun()
                    }
                    .buttonStyle(.bordered)

                    Button("Use default") {
                        model.useDefaultOutputFolder()
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.outputFolder == nil || model.draft.outputFolder?.path == model.outputFolder?.path)
                }

                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("File name")
                            .font(.subheadline.weight(.semibold))
                        TextField("Optional base name", text: $model.draft.fileName)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 300)
                        Text("Existing names are preserved with a numeric suffix.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Format")
                            .font(.subheadline.weight(.semibold))
                        Picker("Format", selection: $model.draft.outputFormat) {
                            ForEach(["PNG", "JPEG", "WEBP"], id: \.self, content: Text.init)
                        }
                        .labelsHidden()
                        .frame(width: 110)
                    }
                }
            }
        }
    }

    private var promptPreviewCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionHeading(title: "Prompt preview", subtitle: "Review the resolved direction before the provider request.")
                    Spacer()
                    Button("Preview") {
                        model.previewPrompt()
                    }
                    .buttonStyle(.bordered)
                }

                if model.promptPreview.isEmpty {
                    ContentUnavailableView("No preview yet", systemImage: "text.magnifyingglass", description: Text("Preview your prompt to see the current model and style direction."))
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    Text(model.promptPreview)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }
}
