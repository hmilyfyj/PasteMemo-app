import AppKit
import SwiftUI

/// Saturated header/border color for bottom-floating cards.
/// Brand colors win over type colors so Safari/Maps/Photos look like Paste
/// without sampling icon bitmaps on the main thread.
struct PasteCardAccent: Equatable, Hashable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    static func resolved(type: ClipContentType, bundleID: String?) -> PasteCardAccent {
        brandAccent(bundleID: bundleID) ?? typeAccent(type)
    }

    static func brandAccent(bundleID: String?) -> PasteCardAccent? {
        guard let raw = bundleID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        switch raw.lowercased() {
        case "com.apple.safari",
             "com.apple.safaritechnologypreview":
            return PasteCardAccent(red: 0.13, green: 0.55, blue: 0.97)
        case "com.apple.maps":
            return PasteCardAccent(red: 0.20, green: 0.78, blue: 0.45)
        case "com.apple.photos",
             "com.apple.photolibraryd":
            return PasteCardAccent(red: 0.96, green: 0.38, blue: 0.48)
        case "com.apple.preview":
            return PasteCardAccent(red: 0.98, green: 0.62, blue: 0.18)
        case "com.apple.ibooksx",
             "com.apple.books":
            return PasteCardAccent(red: 0.98, green: 0.62, blue: 0.18)
        case "com.apple.notes":
            return PasteCardAccent(red: 0.98, green: 0.80, blue: 0.18)
        case "com.apple.mail":
            return PasteCardAccent(red: 0.18, green: 0.62, blue: 0.96)
        case "com.apple.finder":
            return PasteCardAccent(red: 0.20, green: 0.56, blue: 0.94)
        case "com.google.chrome":
            return PasteCardAccent(red: 0.22, green: 0.58, blue: 0.96)
        case "com.microsoft.edgemac":
            return PasteCardAccent(red: 0.13, green: 0.53, blue: 0.93)
        case "com.microsoft.vscode":
            return PasteCardAccent(red: 0.18, green: 0.55, blue: 0.90)
        case "com.apple.dt.xcode":
            return PasteCardAccent(red: 0.22, green: 0.52, blue: 0.94)
        case "com.tencent.xinwechat":
            return PasteCardAccent(red: 0.18, green: 0.78, blue: 0.42)
        case "ru.keepcoder.telegram",
             "org.telegram.desktop":
            return PasteCardAccent(red: 0.20, green: 0.64, blue: 0.92)
        default:
            return nil
        }
    }

    static func typeAccent(_ type: ClipContentType) -> PasteCardAccent {
        switch type {
        case .text:
            return PasteCardAccent(red: 0.98, green: 0.78, blue: 0.18)
        case .code:
            return PasteCardAccent(red: 0.27, green: 0.55, blue: 0.96)
        case .link:
            return PasteCardAccent(red: 0.18, green: 0.62, blue: 0.98)
        case .image:
            return PasteCardAccent(red: 0.96, green: 0.38, blue: 0.48)
        case .video:
            return PasteCardAccent(red: 0.62, green: 0.42, blue: 0.96)
        case .audio:
            return PasteCardAccent(red: 0.93, green: 0.36, blue: 0.62)
        case .document:
            return PasteCardAccent(red: 0.36, green: 0.52, blue: 0.94)
        case .archive:
            return PasteCardAccent(red: 0.48, green: 0.52, blue: 0.60)
        case .application:
            return PasteCardAccent(red: 0.16, green: 0.70, blue: 0.62)
        case .color:
            return PasteCardAccent(red: 0.36, green: 0.78, blue: 0.69)
        case .email:
            return PasteCardAccent(red: 0.27, green: 0.73, blue: 0.87)
        case .phone:
            return PasteCardAccent(red: 0.96, green: 0.33, blue: 0.32)
        case .file:
            return PasteCardAccent(red: 0.72, green: 0.52, blue: 0.28)
        case .mixed:
            return PasteCardAccent(red: 0.50, green: 0.56, blue: 0.74)
        }
    }
}
