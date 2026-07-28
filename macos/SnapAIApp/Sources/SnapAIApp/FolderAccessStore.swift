import AppKit
import Foundation

final class FolderAccessStore {
    private let bookmarkKey = "snapai.output-folder-bookmark"

    func restoreFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }

        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else {
            return nil
        }

        if stale {
            persist(url)
        }
        _ = url.startAccessingSecurityScopedResource()
        return url
    }

    @MainActor
    func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose SnapAI Output Folder"
        panel.message = "SnapAI will save generated images here."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        _ = url.startAccessingSecurityScopedResource()
        persist(url)
        return url
    }

    private func persist(_ url: URL) {
        guard let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return
        }
        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
    }
}
