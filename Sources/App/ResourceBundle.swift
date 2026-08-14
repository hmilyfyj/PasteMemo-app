import Foundation

/// SwiftPM's generated `Bundle.module` accessor for executable targets only
/// checks two locations: `<App>.app/<name>.bundle` (the bundle ROOT, next to
/// Contents/) and the absolute build-machine path baked in at compile time.
/// Signed/notarized builds must keep resource bundles under
/// `Contents/Resources` — anything at the `.app` root fails codesign with
/// "unsealed contents present in the bundle root" — so the generated
/// accessor misses them and traps at startup (v1.7.15-beta.1 first signed
/// build: SIGTRAP in NSBundle.module before the UI ever appeared).
/// This resolver covers every layout we ship or run in.
extension Bundle {
    nonisolated static let pasteMemoResources: Bundle = {
        let name = "PasteMemo_PasteMemo.bundle"
        let main = Bundle.main
        let executableDir = main.executableURL?.deletingLastPathComponent()
        let candidates: [URL?] = [
            // Signed .app layout: Contents/Resources/
            main.resourceURL,
            main.bundleURL.appendingPathComponent("Contents/Resources"),
            executableDir?.appendingPathComponent("../Resources").standardized,
            // Legacy ad-hoc / Bundle.module layout: next to the .app root
            main.bundleURL,
            executableDir?.appendingPathComponent("../..").standardized,
            // CLI / `swift run` / test runners: next to the executable
            executableDir,
        ]
        for candidate in candidates {
            guard let url = candidate?.appendingPathComponent(name) else { continue }
            if let bundle = Bundle(url: url) ?? Bundle(path: url.path) {
                return bundle
            }
        }
        // Last resort: only touch the generated accessor when it can actually load.
        // Calling `.module` from a signed .app SIGTRAPs if the baked build-dir
        // path is gone (issue #38).
        let moduleURL = executableDir?.appendingPathComponent(name)
        if let moduleURL, let bundle = Bundle(url: moduleURL) {
            return bundle
        }
        fatalError("PasteMemo resource bundle not found. Searched around \(main.bundleURL.path)")
    }()
}
