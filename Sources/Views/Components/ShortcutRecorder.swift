import SwiftUI
import Carbon

/// 快捷键录制控件：灰色圆角胶囊显示当前键位，点一下进入录制（参考 Raycast 设置里的
/// Hotkey 行）。录制逻辑和旧的 NSTextField 版一样：本地 keyDown 监听，裸 Esc 取消，
/// 非功能键必须带 ⌘ / ⌃ / ⌥ 之一。
struct ShortcutRecorder: View {
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    var onChanged: (() -> Void)?

    @State private var isRecording = false
    @State private var localMonitor: Any?
    @Environment(\.isEnabled) private var isEnabled

    init(keyCode: Binding<Int>, modifiers: Binding<Int>, onChanged: (() -> Void)? = nil) {
        _keyCode = keyCode
        _modifiers = modifiers
        self.onChanged = onChanged
    }

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            Text(displayText)
                .font(.system(size: 12, weight: hasShortcut || isRecording ? .medium : .regular))
                .foregroundStyle(textStyle)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(minWidth: 64, maxWidth: .infinity, minHeight: 24, maxHeight: 24)
                .background(Color.primary.opacity(isRecording ? 0.12 : 0.08), in: RoundedRectangle(cornerRadius: 7))
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .opacity(isEnabled ? 1 : 0.5)
        .fixedSize(horizontal: true, vertical: false)
        .onDisappear { stopRecording() }
    }

    private var hasShortcut: Bool { keyCode >= 0 && modifiers >= 0 }

    private var displayText: String {
        if isRecording { return L10n.tr("settings.shortcut.pressKey") }
        // 键位之间用空格分开（⌘ ⇧ V），和 Raycast 一致，比挤成一团好认
        let parts = shortcutDisplayParts(keyCode: keyCode, modifiers: modifiers)
        return parts.isEmpty ? L10n.tr("settings.shortcut.clickToRecord") : parts.joined(separator: " ")
    }

    private var textStyle: AnyShapeStyle {
        if isRecording { return AnyShapeStyle(Color.orange) }
        return hasShortcut ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary)
    }

    private func startRecording() {
        isRecording = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            if event.keyCode == 53 && mods.isEmpty { // 裸 Esc 取消录制；带修饰键的 Esc 当作快捷键键码
                stopRecording()
                return nil
            }

            let isFunctionKey = (0x60...0x7F).contains(Int(event.keyCode))
            // Require at least one modifier, unless it's a function key (F1-F12 etc.)
            if !isFunctionKey {
                guard mods.contains(.command) || mods.contains(.control) || mods.contains(.option) else {
                    return nil
                }
            }

            keyCode = Int(event.keyCode)
            modifiers = carbonModifiers(from: mods)
            onChanged?()
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}

/// 快捷键行右侧的圆形清除按钮，和录制胶囊配套。
struct ShortcutClearButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 24, height: 24)
                .background(Color.primary.opacity(0.08), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}

private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> Int {
    var result = 0
    if flags.contains(.command) { result |= cmdKey }
    if flags.contains(.shift) { result |= shiftKey }
    if flags.contains(.option) { result |= optionKey }
    if flags.contains(.control) { result |= controlKey }
    return result
}

/// True if `event` matches the given Carbon-style shortcut (keyCode + modifier mask).
/// Returns false if the shortcut is cleared (keyCode < 0).
func eventMatchesShortcut(event: NSEvent, keyCode: Int, modifiers: Int) -> Bool {
    guard keyCode >= 0, Int(event.keyCode) == keyCode else { return false }
    var pressed = 0
    if event.modifierFlags.contains(.command) { pressed |= cmdKey }
    if event.modifierFlags.contains(.shift) { pressed |= shiftKey }
    if event.modifierFlags.contains(.option) { pressed |= optionKey }
    if event.modifierFlags.contains(.control) { pressed |= controlKey }
    return pressed == modifiers
}

func shortcutDisplayString(keyCode: Int, modifiers: Int) -> String {
    shortcutDisplayParts(keyCode: keyCode, modifiers: modifiers).joined()
}

/// 修饰键符号 + 键名，按 ⌃⌥⇧⌘ 顺序；快捷键未设置时为空数组。
func shortcutDisplayParts(keyCode: Int, modifiers: Int) -> [String] {
    guard keyCode >= 0 && modifiers >= 0 else { return [] }
    var parts: [String] = []
    if modifiers & controlKey != 0 { parts.append("⌃") }
    if modifiers & optionKey != 0 { parts.append("⌥") }
    if modifiers & shiftKey != 0 { parts.append("⇧") }
    if modifiers & cmdKey != 0 { parts.append("⌘") }
    parts.append(keyName(for: keyCode))
    return parts
}

/// 把 Carbon 风格快捷键转成 NSMenuItem 的 keyEquivalent + modifierMask，
/// 让 AppKit 按系统菜单样式（右对齐、灰色）渲染快捷键提示。
/// 快捷键未设置或键位无法映射时返回 nil。
func menuKeyEquivalent(keyCode: Int, modifiers: Int) -> (key: String, mask: NSEvent.ModifierFlags)? {
    guard keyCode >= 0 && modifiers >= 0 else { return nil }
    var mask: NSEvent.ModifierFlags = []
    if modifiers & controlKey != 0 { mask.insert(.control) }
    if modifiers & optionKey != 0 { mask.insert(.option) }
    if modifiers & shiftKey != 0 { mask.insert(.shift) }
    if modifiers & cmdKey != 0 { mask.insert(.command) }

    let key: String
    switch keyCode {
    case 36: key = "\r"
    case 48: key = "\t"
    case 49: key = " "
    case 53: key = "\u{1b}"
    default:
        let name = keyName(for: keyCode)
        if name.hasPrefix("F"), let n = Int(name.dropFirst()), (1...20).contains(n) {
            guard let scalar = UnicodeScalar(NSF1FunctionKey + n - 1) else { return nil }
            key = String(Character(scalar))
        } else if name.count == 1 {
            // 字母必须小写，大写会被 AppKit 解读为隐含 Shift
            key = name.lowercased()
        } else {
            return nil
        }
    }
    return (key, mask)
}

private func keyName(for keyCode: Int) -> String {
    let mapping: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 10: "B", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
        24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
        32: "U", 33: "[", 34: "I", 35: "P", 36: "↵", 37: "L", 38: "J", 39: "'",
        40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        48: "⇥", 49: "Space", 50: "`", 53: "Esc",
        // Function keys
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18",
        80: "F19", 90: "F20",
    ]
    return mapping[keyCode] ?? "Key\(keyCode)"
}
