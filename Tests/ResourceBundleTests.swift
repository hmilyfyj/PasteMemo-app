import Foundation
import Testing
@testable import PasteMemo

struct ResourceBundleTests {
    @Test("Resource bundle loads through the Swift Testing helper")
    func resourceBundleLoadsLocalization() {
        let bundle = Bundle.pasteMemoResources
        #expect(bundle.bundleURL.lastPathComponent == "PasteMemo_PasteMemo.bundle")
        #expect(bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: "en.lproj") != nil)
    }
}
