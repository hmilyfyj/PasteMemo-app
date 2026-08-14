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
        let candidates: [URL?] = [
            // Signed .app layout: Contents/Resources/
            Bundle.main.resourceURL,
            // Legacy ad-hoc .app layout: bundle root
            Bundle.main.bundleURL,
            // CLI / `swift run` / test runners: next to the executable
            Bundle.main.executableURL?.deletingLastPathComponent(),
        ]
        for candidate in candidates {
            if let url = candidate?.appendingPathComponent(name),
               let bundle = Bundle(url: url) {
                return bundle
            }
        }
        // Dev fallback: the generated accessor knows the local build dir.
        return .module
    }()
}
