import Foundation
import SwiftData
import Testing
@testable import PasteMemo

@Suite("RelayRecirculation")
struct RelayRecirculationTests {

    @MainActor private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ClipItem.self, SmartGroup.self, AutomationRule.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("Text item recirculates into clipboard history as new ClipItem")
    @MainActor func recirculateTextInsertsNew() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let item = RelayItem(
            content: "hello world",
            contentKind: .text,
            sourceAppBundleID: "com.apple.Safari"
        )

        let handle = RelayRecirculation.recirculate(item, originalIndex: 0, context: context)
        try context.save()

        let clips = try context.fetch(FetchDescriptor<ClipItem>())
        #expect(clips.count == 1)
        #expect(clips[0].content == "hello world")
        #expect(clips[0].sourceAppBundleID == "com.apple.Safari")
        #expect(handle.insertedClipID != nil)
        #expect(handle.originalIndex == 0)
    }

    @Test("Duplicate text item bumps lastUsedAt without creating a new row")
    @MainActor func recirculateTextDedupes() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let existing = ClipItem(
            content: "hello",
            contentType: .text,
            createdAt: Date(timeIntervalSince1970: 100),
            lastUsedAt: Date(timeIntervalSince1970: 100)
        )
        context.insert(existing)
        try context.save()
        let existingID = existing.persistentModelID

        let item = RelayItem(content: "hello", contentKind: .text)
        let handle = RelayRecirculation.recirculate(item, originalIndex: 2, context: context)
        try context.save()

        let clips = try context.fetch(FetchDescriptor<ClipItem>())
        #expect(clips.count == 1)
        #expect(clips[0].persistentModelID == existingID)
        #expect(clips[0].lastUsedAt > Date(timeIntervalSince1970: 100))
        #expect(handle.insertedClipID == nil, "should not mark as newly inserted when deduped")
    }

    @Test("Image item recirculates with imageData")
    @MainActor func recirculateImage() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let item = RelayItem(
            content: "[Image]",
            imageData: data,
            contentKind: .image
        )

        let handle = RelayRecirculation.recirculate(item, originalIndex: 0, context: context)
        try context.save()

        let clips = try context.fetch(FetchDescriptor<ClipItem>())
        #expect(clips.count == 1)
        #expect(clips[0].contentType == .image)
        #expect(clips[0].imageData == data)
        #expect(handle.insertedClipID != nil)
    }

    @Test("File item recirculates as .file contentType")
    @MainActor func recirculateFile() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let item = RelayItem(
            content: "/Users/foo/bar.txt",
            contentKind: .file
        )

        _ = RelayRecirculation.recirculate(item, originalIndex: 0, context: context)
        try context.save()

        let clips = try context.fetch(FetchDescriptor<ClipItem>())
        #expect(clips.count == 1)
        #expect(clips[0].contentType == .file)
        #expect(clips[0].content == "/Users/foo/bar.txt")
    }

    @Test("File-kind item with image extension and imageData recirculates as .image")
    @MainActor func recirculateImageFileAsImage() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let thumb = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let item = RelayItem(
            content: "/tmp/CleanShot.png",
            imageData: thumb,
            contentKind: .file
        )

        _ = RelayRecirculation.recirculate(item, originalIndex: 0, context: context)
        try context.save()

        let clips = try context.fetch(FetchDescriptor<ClipItem>())
        #expect(clips.count == 1)
        #expect(clips[0].contentType == .image)
        #expect(clips[0].imageData == thumb)
    }

    @Test("File-kind item with non-image extension stays as .file")
    @MainActor func recirculateNonImageFileStaysFile() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let item = RelayItem(
            content: "/tmp/report.pdf",
            contentKind: .file
        )

        _ = RelayRecirculation.recirculate(item, originalIndex: 0, context: context)
        try context.save()

        let clips = try context.fetch(FetchDescriptor<ClipItem>())
        #expect(clips.count == 1)
        #expect(clips[0].contentType == .file)
    }

    @Test("Undo removes newly-inserted clip")
    @MainActor func undoRemovesInsertedClip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let item = RelayItem(content: "tmp", contentKind: .text)
        let handle = RelayRecirculation.recirculate(item, originalIndex: 0, context: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<ClipItem>()).count == 1)

        RelayRecirculation.undoClipInsertion(handle, context: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<ClipItem>()).count == 0)
    }

    @Test("Undo on deduped insertion is no-op for clipboard history")
    @MainActor func undoDedupedIsNoop() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let existing = ClipItem(content: "hello", contentType: .text)
        context.insert(existing)
        try context.save()

        let item = RelayItem(content: "hello", contentKind: .text)
        let handle = RelayRecirculation.recirculate(item, originalIndex: 0, context: context)
        try context.save()

        RelayRecirculation.undoClipInsertion(handle, context: context)
        try context.save()

        // Existing item stays.
        let clips = try context.fetch(FetchDescriptor<ClipItem>())
        #expect(clips.count == 1)
        #expect(clips[0].content == "hello")
    }
}
