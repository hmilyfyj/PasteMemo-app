import AppKit
import ImageIO

final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, NSImage>()
    private let preloadQueue = DispatchQueue(label: "com.lifedever.pastememo.imagepreload", qos: .utility)
    private var preloadedKeys = Set<String>()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024
    }

    static func normalizedThumbnailDimension(_ dimension: CGFloat) -> CGFloat {
        quantizedDimension(dimension, step: dimension <= 120 ? 12 : 24, minimum: 24)
    }

    static func normalizedPreviewDimension(_ dimension: CGFloat) -> CGFloat {
        quantizedDimension(dimension, step: dimension <= 240 ? 32 : 64, minimum: 64)
    }

    func thumbnail(for data: Data, key: String, size: CGFloat = 36) -> NSImage? {
        let normalizedSize = Self.normalizedThumbnailDimension(size)
        let cacheKey = "\(key)_\(Int(normalizedSize))" as NSString
        if let cached = cache.object(forKey: cacheKey) { return cached }

        guard let source = downsample(data: data, maxPixelSize: normalizedSize * 2) ?? NSImage(data: data) else { return nil }
        let thumb = resize(source, to: normalizedSize)
        cache.setObject(thumb, forKey: cacheKey, cost: data.count)
        return thumb
    }

    func cachedPreview(for key: String, maxDimension: CGFloat) -> NSImage? {
        cache.object(forKey: previewCacheKey(for: key, maxDimension: maxDimension))
    }

    func preview(for data: Data, key: String, maxDimension: CGFloat) -> NSImage? {
        let cacheKey = previewCacheKey(for: key, maxDimension: maxDimension)
        if let cached = cache.object(forKey: cacheKey) { return cached }

        guard let image = downsample(data: data, maxPixelSize: maxDimension * 2) ?? NSImage(data: data) else {
            return nil
        }
        cache.setObject(image, forKey: cacheKey, cost: data.count)
        return image
    }

    func imageDimensions(for data: Data) -> NSSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }
        return NSSize(width: width, height: height)
    }

    func favicon(for data: Data, key: String) -> NSImage? {
        let cacheKey = "fav_\(key)" as NSString
        if let cached = cache.object(forKey: cacheKey) { return cached }
        guard let img = NSImage(data: data) else { return nil }
        cache.setObject(img, forKey: cacheKey, cost: data.count)
        return img
    }

    func fileIcon(forPath path: String) -> NSImage {
        let cacheKey = "file_\(path)" as NSString
        if let cached = cache.object(forKey: cacheKey) { return cached }
        let icon = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(icon, forKey: cacheKey, cost: 1024)
        return icon
    }

    func videoThumbnail(forPath path: String) -> NSImage? {
        let cacheKey = "video_\(path)" as NSString
        return cache.object(forKey: cacheKey)
    }

    func setVideoThumbnail(_ image: NSImage, forPath path: String) {
        let cacheKey = "video_\(path)" as NSString
        cache.setObject(image, forKey: cacheKey, cost: 4096)
    }
    
    func preloadImages(for items: [(key: String, data: Data)], maxDimension: CGFloat = 36) {
        preloadQueue.async { [weak self] in
            guard let self = self else { return }
            for (key, data) in items {
                guard !self.preloadedKeys.contains(key) else { continue }
                _ = self.thumbnail(for: data, key: key, size: maxDimension)
                self.preloadedKeys.insert(key)
            }
        }
    }
    
    func clearPreloadTracking() {
        preloadedKeys.removeAll()
    }

    private func previewCacheKey(for key: String, maxDimension: CGFloat) -> NSString {
        let normalized = Self.normalizedPreviewDimension(maxDimension)
        return "preview_\(key)_\(Int(normalized))" as NSString
    }

    private func downsample(data: Data, maxPixelSize: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize.rounded(.up)))
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
    }

    private func resize(_ image: NSImage, to maxDimension: CGFloat) -> NSImage {
        let original = image.size
        guard original.width > 0, original.height > 0 else { return image }
        let scale = min(maxDimension * 2 / original.width, maxDimension * 2 / original.height)
        let targetSize = NSSize(width: original.width * scale, height: original.height * scale)
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize),
                   from: NSRect(origin: .zero, size: original),
                   operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    private static func quantizedDimension(_ dimension: CGFloat, step: CGFloat, minimum: CGFloat) -> CGFloat {
        let clamped = max(dimension, minimum)
        return max(minimum, (clamped / step).rounded() * step)
    }
}
