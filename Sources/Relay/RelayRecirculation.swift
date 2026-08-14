import Foundation
import SwiftData

/// Writes a `RelayItem` back into clipboard history when the user deletes it from the
/// relay queue, so the clip isn't lost — they can still recover it from the main
/// window / quick panel. Supports undo (remove the freshly-inserted ClipItem) so the
/// deletion can be reverted from a toast.
///
/// This type is deliberately narrow: it only touches clipboard history. Splicing the
/// item back into the relay queue on undo, and any UI (toast / animation), are
/// someone else's responsibility.
@MainActor
enum RelayRecirculation {

    /// Handle returned from `recirculate` so callers can splice the relay item back
    /// into its queue position and (optionally) remove the freshly-inserted ClipItem.
    struct UndoHandle {
        let relayItem: RelayItem
        let originalIndex: Int
        /// `nil` when recirculation deduplicated into an existing ClipItem —
        /// in that case there is nothing to remove from clipboard history on undo.
        let insertedClipID: PersistentIdentifier?
    }

    /// Write `item` back into clipboard history so the user can recover it from the
    /// main app window / quick panel after deleting from the relay queue. If the
    /// content already exists as a ClipItem, only bump `lastUsedAt` (avoids a
    /// duplicate row on repeated copy-relay-delete cycles).
    static func recirculate(
        _ item: RelayItem,
        originalIndex: Int,
        context: ModelContext
    ) -> UndoHandle {
        let staging = ClipItem(
            content: item.content,
            contentType: clipContentType(for: item),
            imageData: item.imageData,
            sourceAppBundleID: item.sourceAppBundleID,
            pasteboardSnapshot: item.pasteboardSnapshot
        )

        if let existing = ClipboardManager.shared.findExistingDuplicate(for: staging, in: context) {
            ClipboardManager.shared.reuseExistingDuplicate(existing, with: staging, in: context)
            return UndoHandle(
                relayItem: item,
                originalIndex: originalIndex,
                insertedClipID: nil
            )
        }

        context.insert(staging)
        // Persist now so `persistentModelID` is stable (permanent, not temporary).
        // Without this, `context.model(for: temporaryID)` after a later save returns
        // an invalid future-backing stub and crashes on the next save.
        try? context.save()
        return UndoHandle(
            relayItem: item,
            originalIndex: originalIndex,
            insertedClipID: staging.persistentModelID
        )
    }

    /// Undo `recirculate`: remove the ClipItem that `recirculate` inserted. When
    /// recirculation deduplicated into an existing row (`insertedClipID == nil`) we
    /// intentionally leave clipboard history alone — the existing row pre-dates the
    /// user's deletion.
    static func undoClipInsertion(_ handle: UndoHandle, context: ModelContext) {
        guard let id = handle.insertedClipID else { return }
        guard let clip = context.model(for: id) as? ClipItem else { return }
        context.delete(clip)
    }

    // MARK: - Helpers

    /// Recognized image file extensions for recirculation. Keep lowercase.
    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "heic", "heif", "webp", "tiff", "bmp"
    ]

    private static func clipContentType(for item: RelayItem) -> ClipContentType {
        switch item.contentKind {
        case .image: return .image
        case .text:  return .text
        case .file:
            // File-kind may wrap an image file (Finder-copied PNG/JPEG). Restore as .image
            // so clipboard history shows a thumbnail instead of a generic doc icon.
            if item.imageData != nil {
                let ext = (item.content as NSString).pathExtension.lowercased()
                if imageExtensions.contains(ext) {
                    return .image
                }
            }
            return .file
        }
    }
}
