import AppKit
import SwiftUI

struct ResultsView: View {
    @ObservedObject var model: AppModel
    @State private var selectedResultID: ResultItem.ID?
    @State private var searchText = ""

    private var selectedResult: ResultItem? {
        guard let selectedResultID else { return model.results.first }
        return model.results.first { $0.id == selectedResultID } ?? model.results.first
    }

    private var filteredResults: [ResultItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return model.results
        }
        return model.results.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.detail.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                PageHeader(
                    eyebrow: "RESULTS GALLERY",
                    title: "Generated Masterpieces",
                    subtitle: "Compare, inspect, and export artwork created during your session."
                )

                Spacer()

                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search results...", text: $searchText)
                            .textFieldStyle(.plain)
                            .frame(width: 160)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

                    if !model.results.isEmpty {
                        Text("\(filteredResults.count) items")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }
                }
            }
            .padding(28)

            if model.results.isEmpty {
                VStack(spacing: 24) {
                    EmptySectionView(
                        section: .library,
                        description: "Your generated variations will appear here in a high-resolution comparison grid.",
                        actionTitle: "Start Creating Artwork",
                        action: { model.selectSection(.create) }
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Creative Inspiration Starters")
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            inspirationCard(
                                title: "3D Glass Icon",
                                prompt: "Glossy 3D squircle app icon, translucent glass, vibrant neon gradient",
                                style: "3D Icon",
                                model: .banana2
                            )
                            inspirationCard(
                                title: "Cyberpunk City",
                                prompt: "Futuristic synthwave cityscape at night, rain-slicked streets, towering skyscrapers",
                                style: "Cyberpunk",
                                model: .bananaPro
                            )
                            inspirationCard(
                                title: "Studio Portrait",
                                prompt: "Photorealistic portrait, warm rim lighting, soft bokeh background, 8k detail",
                                style: "Photorealistic",
                                model: .gptImage2
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            } else {
                HStack(alignment: .top, spacing: 20) {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 16)], spacing: 16) {
                            ForEach(filteredResults) { result in
                                resultCard(result)
                            }
                        }
                        .padding(.leading, 28)
                        .padding(.bottom, 28)
                    }
                    .overlay(alignment: .top) {
                        ScrollEdgeFade(edge: .top)
                    }

                    if let selectedResult {
                        inspector(selectedResult)
                            .frame(width: 300)
                            .padding(.trailing, 28)
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Results Gallery")
        .onChange(of: model.results.count) { _, _ in
            selectedResultID = model.results.first?.id
        }
    }

    private func resultCard(_ result: ResultItem) -> some View {
        Button {
            selectedResultID = result.id
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                resultPreview(result)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(result.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selectedResultID == result.id ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: selectedResultID == result.id ? 2 : 1)
            }
            .shadow(color: selectedResultID == result.id ? Color.accentColor.opacity(0.25) : Color.black.opacity(0.05), radius: selectedResultID == result.id ? 8 : 4)
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
        .help("Drag to Finder to copy, or Control-click for actions")
    }

    @ViewBuilder
    private func resultActions(_ result: ResultItem) -> some View {
        if let url = result.outputURL {
            Button("Quick Look") { QuickLookService.shared.show(url: url) }
            Button("Open") { NSWorkspace.shared.open(url) }
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.path, forType: .string)
                model.statusMessage = "Copied output path to clipboard."
            }
        }
    }

    private func inspector(_ result: ResultItem) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Selected Asset")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Text("INSPECTOR")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                resultPreview(result)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Filename")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(result.title)
                        .font(.headline.weight(.bold))
                        .textSelection(.enabled)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Model & Detail")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(result.detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }

                if let url = result.outputURL {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("File Path")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(url.path)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(3)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    VStack(spacing: 8) {
                        Button {
                            QuickLookService.shared.show(url: url)
                        } label: {
                            Label("Quick Look", systemImage: "eye.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        HStack(spacing: 8) {
                            Button("Open") { NSWorkspace.shared.open(url) }
                                .buttonStyle(.bordered)
                            Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                                .buttonStyle(.bordered)
                        }
                    }
                    .padding(.top, 6)
                }
            }
        }
    }

    @ViewBuilder
    private func resultPreview(_ result: ResultItem) -> some View {
        if let outputURL = result.outputURL {
            ThumbnailView(url: outputURL, maxDimension: 380, cornerRadius: 10)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .aspectRatio(1, contentMode: .fit)
                .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary))
        }
    }

    private func inspirationCard(title: String, prompt: String, style: String, model modelOption: ModelOption) -> some View {
        Button {
            model.draft.prompt = prompt
            model.draft.style = style
            model.draft.model = modelOption
            model.selectSection(.create)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Image(systemName: "arrow.up.forward.app")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
                Text(prompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(DeckTileButtonStyle())
    }
}


