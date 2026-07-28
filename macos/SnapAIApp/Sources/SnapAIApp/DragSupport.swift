import AppKit
import UniformTypeIdentifiers

enum DragSupport {
    nonisolated static func provider(for url: URL) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = url.lastPathComponent
        provider.registerFileRepresentation(
            forTypeIdentifier: typeIdentifier(for: url),
            visibility: .all
        ) { completion in
            completion(url, false, nil)
            return Progress()
        }
        return provider
    }

    nonisolated static func typeIdentifier(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "png": return UTType.png.identifier
        case "jpg", "jpeg": return UTType.jpeg.identifier
        case "webp": return "org.webmproject.webp"
        default: return UTType.fileURL.identifier
        }
    }
}