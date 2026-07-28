import SwiftUI

struct AppShellView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        ZStack {
            workspaceView
                .opacity(model.onboardingComplete ? 1 : 0)
                .allowsHitTesting(model.onboardingComplete)
                .accessibilityHidden(!model.onboardingComplete)

            if !model.onboardingComplete {
                OnboardingView(model: model)
                    .zIndex(1)
            }

            ToastOverlay(center: model.toast)
        }
        .animation(
            reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.35),
            value: model.onboardingComplete
        )
        .onAppear { model.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, newValue in model.reduceMotion = newValue }
        .background(Color(nsColor: .underPageBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .snapAINavigate)) { notification in
            guard let rawValue = notification.userInfo?["section"] as? String,
                  let section = AppSection(rawValue: rawValue) else {
                return
            }
            model.selectSection(section)
        }
        .onReceive(NotificationCenter.default.publisher(for: .snapAIPreviewPrompt)) { _ in
            model.previewPrompt()
        }
        .onReceive(NotificationCenter.default.publisher(for: .snapAIGenerate)) { _ in
            model.requestGeneration()
        }
        .onReceive(NotificationCenter.default.publisher(for: .snapAISharedStateChanged)) { _ in
            model.reloadSharedState()
        }
    }

    private var workspaceView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(model: model)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var detailView: some View {
        Group {
            switch model.selectedSection {
            case .create:
                CreateView(model: model)
            case .library:
                ResultsView(model: model)
            case .history:
                HistoryView(model: model)
            case .profiles:
                ProfilesView(model: model)
            case .settings:
                SettingsView(model: model)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if model.canGoBack {
                    Button {
                        model.goBack()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .help("Return to the previous section")
                    .accessibilityLabel("Back to previous section")
                }
            }
        }
    }
}

private struct SidebarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        List(selection: Binding(
            get: { model.selectedSection },
            set: { if let section = $0 { model.selectSection(section) } }
        )) {
            Section("Workspace") {
                ForEach([AppSection.create, .library, .history, .profiles]) { section in
                    HStack {
                        Label(section.title, systemImage: section.symbolName)
                        Spacer()
                        if let count = badgeCount(for: section) {
                            Text("\(count)")
                                .font(.caption2.monospacedDigit().weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.1), in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .tag(section)
                }
            }

            Section("Utility") {
                HStack {
                    Label(AppSection.settings.title, systemImage: AppSection.settings.symbolName)
                    Spacer()
                }
                .contentShape(Rectangle())
                .tag(AppSection.settings)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            headerView
        }
        .safeAreaInset(edge: .bottom) {
            footerView
        }
        .frame(minWidth: 220, idealWidth: 240, maxWidth: 280)
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .shadow(color: Color.purple.opacity(0.4), radius: 6, x: 0, y: 3)
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text("SnapAI")
                        .font(.headline.weight(.bold))
                        .tracking(-0.015)
                    Text("PRO")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(Color.accentColor)
                }
                Text("Native Creative Studio")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var footerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            StatusBadge(
                title: model.isGenerating ? "Generating artwork..." : (model.coreReady ? "Core Ready" : "Initializing..."),
                icon: model.isGenerating ? "sparkles" : "checkmark.shield",
                isOnline: model.coreReady
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private func badgeCount(for section: AppSection) -> Int? {
        switch section {
        case .library:
            return model.results.isEmpty ? nil : model.results.count
        case .history:
            return model.history.isEmpty ? nil : model.history.count
        case .profiles:
            return model.profiles.isEmpty ? nil : model.profiles.count
        default:
            return nil
        }
    }
}


