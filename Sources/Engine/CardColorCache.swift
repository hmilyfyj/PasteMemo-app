import AppKit
import SwiftUI

@MainActor
final class CardColorCache {
    static let shared = CardColorCache()
    
    private var colorCache: [String: CachedColors] = [:]
    private let cacheQueue = DispatchQueue(label: "com.lifedever.pastememo.colorcache", qos: .userInteractive)
    
    struct CachedColors {
        let gradientColors: [Color]
        let headerBaseColor: NSColor
        let timestamp: Date
    }
    
    private init() {}
    
    func getGradientColors(for item: ClipItem, icon: NSImage?) -> [Color] {
        let cacheKey = generateCacheKey(for: item)
        
        if let cached = colorCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < 300 {
            return cached.gradientColors
        }
        
        let baseColor = sampleHeaderBaseColor(from: icon, for: item)
        let colors = computeGradientColors(from: baseColor)
        
        colorCache[cacheKey] = CachedColors(
            gradientColors: colors,
            headerBaseColor: baseColor,
            timestamp: Date()
        )
        
        return colors
    }
    
    func getHeaderBaseColor(for item: ClipItem, icon: NSImage?) -> NSColor {
        let cacheKey = generateCacheKey(for: item)
        
        if let cached = colorCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < 300 {
            return cached.headerBaseColor
        }
        
        let baseColor = sampleHeaderBaseColor(from: icon, for: item)
        let colors = computeGradientColors(from: baseColor)
        
        colorCache[cacheKey] = CachedColors(
            gradientColors: colors,
            headerBaseColor: baseColor,
            timestamp: Date()
        )
        
        return baseColor
    }
    
    func clearCache() {
        colorCache.removeAll()
    }
    
    private func generateCacheKey(for item: ClipItem) -> String {
        "\(item.id)-\(item.sourceAppBundleID ?? "")-\(item.contentType.rawValue)"
    }
    
    private func sampleHeaderBaseColor(from icon: NSImage?, for item: ClipItem) -> NSColor {
        guard let icon = icon else {
            return defaultColor(for: item)
        }
        
        let sampleColor = sampleCenterColor(from: icon)
        return sampleColor ?? defaultColor(for: item)
    }
    
    private func defaultColor(for item: ClipItem) -> NSColor {
        NSColor(calibratedRed: 0.30, green: 0.49, blue: 0.95, alpha: 1)
    }
    
    private func computeGradientColors(from baseColor: NSColor) -> [Color] {
        let rgb = baseColor.usingColorSpace(.deviceRGB) ?? baseColor
        
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        if saturation < 0.15 {
            let start = NSColor(
                calibratedWhite: min(max(brightness + 0.12, 0.50), 0.95),
                alpha: 1
            )
            let end = NSColor(
                calibratedWhite: min(max(brightness - 0.06, 0.42), 0.85),
                alpha: 1
            )
            return [Color(nsColor: start), Color(nsColor: end)]
        }
        
        let tunedSaturation = min(max(saturation * 0.75, 0.25), 0.70)
        let start = NSColor(
            calibratedHue: hue,
            saturation: max(tunedSaturation - 0.05, 0),
            brightness: min(max(brightness + 0.05, 0.38), 0.65),
            alpha: 1
        )
        let end = NSColor(
            calibratedHue: hue,
            saturation: min(tunedSaturation + 0.05, 1),
            brightness: min(max(brightness - 0.12, 0.25), 0.52),
            alpha: 1
        )
        return [Color(nsColor: start), Color(nsColor: end)]
    }
    
    private func sampleCenterColor(from image: NSImage) -> NSColor? {
        let targetSize = NSSize(width: 36, height: 36)
        
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(targetSize.width),
            pixelsHigh: Int(targetSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        
        NSGraphicsContext.saveGraphicsState()
        if let context = NSGraphicsContext(bitmapImageRep: bitmap) {
            NSGraphicsContext.current = context
            context.imageInterpolation = .high
            image.draw(in: NSRect(origin: .zero, size: targetSize))
            context.flushGraphics()
        }
        NSGraphicsContext.restoreGraphicsState()
        
        let center = Int(targetSize.width / 2)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var count: CGFloat = 0
        
        for x in max(0, center - 2)...min(Int(targetSize.width) - 1, center + 2) {
            for y in max(0, center - 2)...min(Int(targetSize.height) - 1, center + 2) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.35 else { continue }
                red += color.redComponent
                green += color.greenComponent
                blue += color.blueComponent
                count += 1
            }
        }
        
        guard count > 0 else { return nil }
        
        return NSColor(
            calibratedRed: red / count,
            green: green / count,
            blue: blue / count,
            alpha: 1
        )
    }
}
