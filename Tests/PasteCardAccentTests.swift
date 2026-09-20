import Testing
@testable import PasteMemo

@Suite("Paste card accent")
struct PasteCardAccentTests {

    @Test("Safari link uses Safari blue instead of the generic type color")
    func safariBrandOverridesType() {
        let safari = PasteCardAccent.resolved(type: .link, bundleID: "com.apple.Safari")
        let generic = PasteCardAccent.resolved(type: .link, bundleID: nil)
        #expect(safari != generic)
        #expect(safari == PasteCardAccent.brandAccent(bundleID: "com.apple.Safari"))
    }

    @Test("bundle id matching ignores case and surrounding whitespace")
    func bundleIDNormalized() {
        let a = PasteCardAccent.brandAccent(bundleID: "COM.APPLE.SAFARI")
        let b = PasteCardAccent.brandAccent(bundleID: "  com.apple.Safari  ")
        let c = PasteCardAccent.brandAccent(bundleID: "com.apple.safari")
        #expect(a == b)
        #expect(b == c)
        #expect(a != nil)
    }

    @Test("unknown or empty bundle falls back to type color")
    func unknownFallsBackToType() {
        #expect(PasteCardAccent.resolved(type: .text, bundleID: "com.example.unknown") == PasteCardAccent.typeAccent(.text))
        #expect(PasteCardAccent.resolved(type: .image, bundleID: "") == PasteCardAccent.typeAccent(.image))
        #expect(PasteCardAccent.resolved(type: .link, bundleID: nil) == PasteCardAccent.typeAccent(.link))
        #expect(PasteCardAccent.brandAccent(bundleID: "com.example.unknown") == nil)
    }

    @Test("Maps, Photos and Books keep distinct brand colors")
    func knownBrandsAreDistinct() {
        let maps = PasteCardAccent.brandAccent(bundleID: "com.apple.Maps")
        let photos = PasteCardAccent.brandAccent(bundleID: "com.apple.Photos")
        let books = PasteCardAccent.brandAccent(bundleID: "com.apple.iBooksX")
        #expect(maps != nil)
        #expect(photos != nil)
        #expect(books != nil)
        #expect(Set([maps!, photos!, books!]).count == 3)
    }

    @Test("every visible type has a non-black accent")
    func visibleTypeColorsExist() {
        for type in ClipContentType.defaultVisibleCases {
            let accent = PasteCardAccent.typeAccent(type)
            #expect(accent.red + accent.green + accent.blue > 0.2)
        }
    }
}
