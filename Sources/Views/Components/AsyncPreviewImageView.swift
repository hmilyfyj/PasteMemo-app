import SwiftUI
import AppKit

struct AsyncPreviewImageView: View {
    let data: Data?
    let cacheKey: String
    var maxPixelSize: CGFloat = 1200
    var cornerRadius: CGFloat = 8
    var onDoubleClick: (() -> Void)? = nil

    @State private var image: NSImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else if data != nil {
                placeholder
            } else {
                unavailableState
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onDoubleClick?()
        }
        .task(id: taskID) {
            await loadImage()
        }
    }

    private var taskID: String {
        let normalizedSize = ImageCache.normalizedPreviewDimension(maxPixelSize)
        return "\(cacheKey)_\(Int(normalizedSize))_\(data?.count ?? 0)"
    }

    @MainActor
    private func loadImage() async {
        guard let data else {
            image = nil
            isLoading = false
            return
        }

        if let cached = ImageCache.shared.cachedPreview(for: cacheKey, maxDimension: maxPixelSize) {
            image = cached
            isLoading = false
            return
        }

        image = nil
        isLoading = true

        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                _ = ImageCache.shared.preview(for: data, key: cacheKey, maxDimension: maxPixelSize)
                continuation.resume()
            }
        }

        guard !Task.isCancelled else { return }
        image = ImageCache.shared.cachedPreview(for: cacheKey, maxDimension: maxPixelSize)
        isLoading = false
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.primary.opacity(0.05))

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var unavailableState: some View {
        HStack(spacing: 6) {
            Image(systemName: "photo")
                .foregroundStyle(.tertiary)
            Text("[Image]")
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 13))
    }
}
