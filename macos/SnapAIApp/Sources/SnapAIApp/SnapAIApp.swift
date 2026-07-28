import SwiftUI

extension Notification.Name {
    static let snapAINavigate = Notification.Name("snapAI.navigate")
    static let snapAIPreviewPrompt = Notification.Name("snapAI.previewPrompt")
    static let snapAIGenerate = Notification.Name("snapAI.generate")
    static let snapAISharedStateChanged = Notification.Name("snapAI.sharedStateChanged")
}

@main
struct SnapAIApp: App {
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("SnapAI", id: "project") {
            AppWindowView()
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New project window") {
                    openWindow(id: "project")
                }
                .keyboardShortcut("n", modifiers: [.command])
            }

            CommandGroup(after: .textEditing) {
                Button("Preview prompt") {
                    NotificationCenter.default.post(name: .snapAIPreviewPrompt, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button("Generate") {
                    NotificationCenter.default.post(name: .snapAIGenerate, object: nil)
                }
                .keyboardShortcut(.return, modifiers: [.command])
            }

            CommandMenu("Navigate") {
                Button("Create") {
                    navigate(to: .create)
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Library") {
                    navigate(to: .library)
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("History") {
                    navigate(to: .history)
                }
                .keyboardShortcut("3", modifiers: [.command])

                Button("Profiles") {
                    navigate(to: .profiles)
                }
                .keyboardShortcut("4", modifiers: [.command])

                Button("Settings") {
                    navigate(to: .settings)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }

    private func navigate(to section: AppSection) {
        NotificationCenter.default.post(
            name: .snapAINavigate,
            object: nil,
            userInfo: ["section": section.rawValue]
        )
    }
}

struct AppWindowView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        AppShellView(model: model)
    }
}
