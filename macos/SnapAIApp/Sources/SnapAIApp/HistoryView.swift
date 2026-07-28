import AppKit
import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: AppModel
    @State private var entryToDelete: StoredHistoryEntry?
    @State private var showingClearConfirmation = false
    @State private var searchQuery = ""

    private var filteredHistory: [StoredHistoryEntry] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return model.history }
        return model.history.filter { entry in
            [entry.prompt, entry.finalPrompt, entry.model, entry.provider]
                .joined(separator: " ")
                .lowercased()
                .contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(
                eyebrow: "HISTORY",
                title: "Return to good directions.",
                subtitle: "Every run will keep its prompt, model, options, and output paths locally."
            )
            .padding(32)

            HStack(spacing: 12) {
                TextField("Search prompts, models, and providers", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 360)
                    .accessibilityLabel("Search history")
                Spacer()
                Text("\(filteredHistory.count) run\(filteredHistory.count == 1 ? "" : "s")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 14)

            if model.history.isEmpty {
                EmptySectionView(
                    section: .history,
                    description: "Your local generation history will be logged here automatically after your first run.",
                    actionTitle: "Open Create Studio",
                    action: { model.selectSection(.create) }
                )
            } else if filteredHistory.isEmpty {
                ContentUnavailableView("No matching runs", systemImage: "magnifyingglass", description: Text("Try a different prompt, model, or provider.") )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredHistory) { entry in
                        HStack(spacing: 14) {
                            historyThumbnail(entry)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.prompt)
                                    .font(.headline)
                                    .lineLimit(2)
                                Text("\(entry.model) · \(entry.provider) · \(entry.displayDate)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(entry.outputPaths.count) saved image\(entry.outputPaths.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()

                            Button("Reuse") {
                                model.rerun(entry)
                            }
                            .buttonStyle(.bordered)

                            Button("Delete", role: .destructive) {
                                entryToDelete = entry
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.inset)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Clear History", role: .destructive) {
                    showingClearConfirmation = true
                }
                .disabled(model.history.isEmpty)
            }
        }
        .confirmationDialog(
            "Delete this history entry?",
            isPresented: Binding(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Entry", role: .destructive) {
                if let entryToDelete {
                    model.deleteHistory(entryToDelete)
                }
                entryToDelete = nil
            }
        } message: {
            Text("The saved image files will remain on disk.")
        }
        .confirmationDialog(
            "Clear all history?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) {
                model.clearHistory()
            }
        } message: {
            Text("The saved image files will remain on disk.")
        }
    }

    @ViewBuilder
    private func historyThumbnail(_ entry: StoredHistoryEntry) -> some View {
        if let firstPath = entry.outputPaths.first {
            ThumbnailView(
                url: URL(fileURLWithPath: firstPath),
                maxDimension: 52,
                cornerRadius: 8,
                aspectFill: true
            )
            .frame(width: 52, height: 52)
            .accessibilityLabel("Preview for history entry")
        } else {
            Image(systemName: "photo.on.rectangle")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 52, height: 52)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
        }
    }
}
