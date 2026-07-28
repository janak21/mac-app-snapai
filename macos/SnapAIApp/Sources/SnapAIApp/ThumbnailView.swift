import AppKit
import ImageIO
import SwiftUI

@MainActor
private final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private var entries: [String: CGImage] = [:]
    private var order: [String] = []
    private let limit = 64

    func image(for key: String) -> CGImage? { entries[key] }

    func store(_ image: CGImage, for key: String) {
        if entries[key] == nil {
            order.append(key)
            while order.count > limit, let evicted = order.first {
                order.removeFirst()
                entries.removeValue(forKey: evicted)
            }
        }
        entries[key] = image
    }
}

struct ThumbnailView: View {
    let url: URL
    var maxDimension: CGFloat = 260
    var cornerRadius: CGFloat = 10
    var aspectFill: Bool = false

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                if aspectFill {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .aspectRatio(1, contentMode: .fit)
                }
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: "\(url.path)#\(Int(maxDimension))") {
            await load()
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay {
                if aspectFill {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                }
            }
    }

    private func load() async {
        let key = "\(url.path)@\(Int(maxDimension))"
        if let cached = ThumbnailCache.shared.image(for: key) {
            setImage(cached)
            return
        }

        let path = url.path
        let dim = maxDimension
        let result = await Task.detached(priority: .userInitiated) {
            Self.decodeThumbnail(path: path, maxDimension: dim)
        }.value

        guard let result else { return }
        ThumbnailCache.shared.store(result, for: key)
        setImage(result)
    }

    private func setImage(_ cg: CGImage) {
        image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }

    nonisolated static func decodeThumbnail(path: String, maxDimension: CGFloat) -> CGImage? {
        let url = URL(fileURLWithPath: path) as CFURL
        guard let source = CGImageSourceCreateWithURL(url, nil) else { return nil }
        let pixelSize = max(1, Int(maxDimension * 2))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelSize,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}