import SwiftUI
import SwiftData
import ServiceManagement
import Carbon

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label(L10n.tr("settings.general"), systemImage: "gear") }
            PreferencesTab()
                .tabItem { Label(L10n.tr("settings.preferences"), systemImage: "slider.horizontal.3") }
            RelayTab()
                .tabItem { Label(L10n.tr("relay.tab"), systemImage: "arrow.forward") }
            PrivacyTab()
                .tabItem { Label(L10n.tr("settings.privacy"), systemImage: "lock.shield") }
            if ProManager.AUTOMATION_ENABLED {
                AutomationTab()
                    .tabItem { Label(L10n.tr("settings.automation"), systemImage: "gearshape.2") }
            }
            DataTab()
                .tabItem { Label(L10n.tr("dataPorter.section"), systemImage: "externaldrive") }
            SponsorTab()
                .tabItem { Label(L10n.tr("settings.sponsor"), systemImage: "heart") }
            AboutTab()
                .tabItem { Label(L10n.tr("settings.about"), systemImage: "info.circle") }
        }
        .frame(width: 540)
        .fixedSize(horizontal: false, vertical: true)
        .scrollDisabled(true)
        .localized()
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("menuBarIconStyle") private var menuBarIconStyle = "outline"
    @ObservedObject private var languageManager = LanguageManager.shared
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("hideDockIcon") private var hideDockIcon = false
    @State private var showHideDockConfirm = false
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("copySoundName") private var copySoundName = "custom:sound2"
    @AppStorage("pasteSoundName") private var pasteSoundName = "custom:sound1"
    @State private var previousLanguage = LanguageManager.shared.current

    var body: some View {
        Form {
            Section(L10n.tr("settings.general")) {
                Toggle(L10n.tr("settings.launchAtLogin"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) {
                        if launchAtLogin {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    }
                Toggle(L10n.tr("settings.hideDockIcon"), isOn: Binding(
                    get: { hideDockIcon },
                    set: { newValue in
                        if newValue {
                            showHideDockConfirm = true
                        } else {
                            hideDockIcon = false
                            NSApp.setActivationPolicy(.regular)
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
                ))
                .alert(L10n.tr("settings.hideDockIcon.confirm.title"), isPresented: $showHideDockConfirm) {
                    Button(L10n.tr("settings.hideDockIcon.confirm.ok")) {
                        hideDockIcon = true
                        for window in NSApp.windows where window.isVisible && window.canBecomeMain {
                            window.close()
                        }
                        NSApp.setActivationPolicy(.accessory)
                    }
                    Button(L10n.tr("action.cancel"), role: .cancel) {}
                } message: {
                    Text(L10n.tr("settings.hideDockIcon.confirm.message"))
                }
                Text(L10n.tr("settings.hideDockIcon.hint"))
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }

            Section(L10n.tr("settings.appearance")) {
                Picker(L10n.tr("settings.theme"), selection: $appearanceMode) {
                    Text(L10n.tr("settings.theme.system")).tag("system")
                    Text(L10n.tr("settings.theme.light")).tag("light")
                    Text(L10n.tr("settings.theme.dark")).tag("dark")
                }
                .onChange(of: appearanceMode) {
                    AppDelegate.applyAppearance(appearanceMode)
                }

                Picker(L10n.tr("settings.menuBarIconStyle"), selection: $menuBarIconStyle) {
                    Label {
                        Text(L10n.tr("settings.menuBarIconStyle.outline"))
                    } icon: {
                        if let img = PasteMemoApp.menuBarIconPreview(filled: false) {
                            Image(nsImage: img)
                        }
                    }
                    .tag("outline")
                    Label {
                        Text(L10n.tr("settings.menuBarIconStyle.filled"))
                    } icon: {
                        if let img = PasteMemoApp.menuBarIconPreview(filled: true) {
                            Image(nsImage: img)
                        }
                    }
                    .tag("filled")
                }

                Picker(L10n.tr("settings.language"), selection: $languageManager.current) {
                    ForEach(L10n.supportedLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                .onChange(of: languageManager.current) {
                    guard languageManager.current != previousLanguage else { return }
                    previousLanguage = languageManager.current
                    showLanguageRestartAlert()
                }

            }

            Section(L10n.tr("settings.sound")) {
                Toggle(L10n.tr("settings.sound.enabled"), isOn: $soundEnabled)
                if soundEnabled {
                    soundPicker(
                        label: L10n.tr("settings.sound.copy"),
                        selection: $copySoundName
                    )
                    soundPicker(
                        label: L10n.tr("settings.sound.paste"),
                        selection: $pasteSoundName
                    )
                }
            }

            Section {
                Button(L10n.tr("settings.showGuide")) {
                    showOnboardingWindow()
                }
                .pointerCursor()
            }
        }
        .formStyle(.grouped)
    }


    private func soundPicker(label: String, selection: Binding<String>) -> some View {
        Picker(label, selection: selection) {
            Section(L10n.tr("settings.sound.section.custom")) {
                ForEach(SoundManager.CUSTOM_SOUNDS, id: \.storageKey) { source in
                    Text(source.displayName).tag(source.storageKey)
                }
            }
            Section(L10n.tr("settings.sound.section.system")) {
                ForEach(SoundManager.SYSTEM_SOUNDS, id: \.storageKey) { source in
                    Text(source.displayName).tag(source.storageKey)
                }
            }
        }
        .onChange(of: selection.wrappedValue) {
            SoundManager.preview(.from(storageKey: selection.wrappedValue))
        }
    }

    private func showLanguageRestartAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.tr("settings.language.restart_title")
        alert.informativeText = L10n.tr("settings.language.restart_message")
        alert.addButton(withTitle: L10n.tr("settings.language.restart_now"))
        alert.addButton(withTitle: L10n.tr("settings.language.restart_later"))
        if alert.runModal() == .alertFirstButtonReturn {
            relaunchApp()
        }
    }

    private func relaunchApp() {
        let path = Bundle.main.bundleURL.path
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1 && open \"\(path)\""]
        try? task.launch()
        AppDelegate.shouldReallyQuit = true
        NSApp.terminate(nil)
    }
}

// MARK: - Data Tab

struct DataTab: View {
    var body: some View {
        Form {
            BackupSettingsSection()
            DataPorterSection()
        }
        .formStyle(.grouped)
    }
}

// MARK: - Preferences Tab

struct PreferencesTab: View {
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    @AppStorage("hotkeyKeyCode") private var hotkeyKeyCode = 0x09
    @AppStorage("hotkeyModifiers") private var hotkeyModifiers = cmdKey | shiftKey
    @AppStorage("managerHotkeyKeyCode") private var managerKeyCode = -1
    @AppStorage("managerHotkeyModifiers") private var managerModifiers = -1
    @AppStorage("doubleTapEnabled") private var doubleTapEnabled = false
    @AppStorage("doubleTapModifier") private var doubleTapModifier = 0
    @AppStorage("retentionDays") private var retentionDays = 90
    @AppStorage("addNewLineAfterPaste") private var addNewLineAfterPaste = false
    @AppStorage("showLinkURL") private var showLinkURL = false
    @AppStorage("webPreviewEnabled") private var webPreviewEnabled = true
    @AppStorage(QuickPanelStyle.storageKey) private var quickPanelStyle = QuickPanelStyle.classic.rawValue
    private let allRetentionOptions = [1, 3, 7, 14, 30, 60, 90, 180, 365]

    private var availableOptions: [Int] { allRetentionOptions }

    private var showForever: Bool { true }

    var body: some View {
        Form {
            Section(L10n.tr("settings.shortcuts")) {
                HStack {
                    Text(L10n.tr("settings.quickPanelShortcut"))
                    Spacer()
                    if hotkeyManager.isCleared {
                        Text(L10n.tr("settings.shortcut.none"))
                            .foregroundStyle(.tertiary)
                            .font(.callout)
                    }
                    ShortcutRecorder(keyCode: $hotkeyKeyCode, modifiers: $hotkeyModifiers, onChanged: applyShortcut)
                        .frame(width: 140, height: 24)
                    Button {
                        hotkeyManager.clearShortcut()
                        hotkeyKeyCode = -1
                        hotkeyModifiers = -1
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                }

                HStack {
                    Text(L10n.tr("settings.managerShortcut"))
                    Spacer()
                    if hotkeyManager.isManagerCleared {
                        Text(L10n.tr("settings.shortcut.none"))
                            .foregroundStyle(.tertiary)
                            .font(.callout)
                    }
                    ShortcutRecorder(keyCode: $managerKeyCode, modifiers: $managerModifiers, onChanged: applyManagerShortcut)
                        .frame(width: 140, height: 24)
                    Button {
                        hotkeyManager.clearManagerShortcut()
                        managerKeyCode = -1
                        managerModifiers = -1
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                }

                Toggle(L10n.tr("settings.doubleTap"), isOn: $doubleTapEnabled)
                    .onChange(of: doubleTapEnabled) {
                        DoubleTapDetector.shared.restart()
                    }
                if doubleTapEnabled {
                    Picker(L10n.tr("settings.doubleTap.modifier"), selection: $doubleTapModifier) {
                        ForEach(DoubleTapModifier.allCases, id: \.rawValue) { mod in
                            Text(mod.label).tag(mod.rawValue)
                        }
                    }
                    .onChange(of: doubleTapModifier) {
                        DoubleTapDetector.shared.restart()
                    }
                }
            }

            Section(L10n.tr("settings.behavior")) {
                Toggle(L10n.tr("settings.addNewLine"), isOn: $addNewLineAfterPaste)
                Toggle(L10n.tr("settings.showLinkURL"), isOn: $showLinkURL)
                Toggle(L10n.tr("settings.webPreview"), isOn: $webPreviewEnabled)
                Picker(L10n.tr("settings.quickPanelStyle"), selection: $quickPanelStyle) {
                    Text(L10n.tr("settings.quickPanelStyle.classic")).tag(QuickPanelStyle.classic.rawValue)
                    Text(L10n.tr("settings.quickPanelStyle.bottomFloating")).tag(QuickPanelStyle.bottomFloating.rawValue)
                }
                .onChange(of: quickPanelStyle) { _, newValue in
                    if newValue == QuickPanelStyle.bottomFloating.rawValue {
                        QuickPanelBottomDefaults.resetStoredSizing()
                    } else if newValue == QuickPanelStyle.classic.rawValue {
                        QuickPanelBottomDefaults.resetClassicSizing()
                    }
                }
                if quickPanelStyle == QuickPanelStyle.bottomFloating.rawValue {
                    BottomFloatingHeightSettingView()
                }
            }

            OCRSettingsSection()
            
            AnimationSettingsSection()

            Section(L10n.tr("settings.history")) {
                Picker(L10n.tr("settings.retentionDays"), selection: $retentionDays) {
                    if showForever {
                        Text(L10n.tr("settings.retentionDays.forever")).tag(0)
                    }
                    ForEach(availableOptions, id: \.self) { days in
                        Text(L10n.tr("settings.retentionDays.days", days)).tag(days)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func applyShortcut() {
        HotkeyManager.shared.updateShortcut(keyCode: hotkeyKeyCode, modifiers: hotkeyModifiers)
    }

    private func applyManagerShortcut() {
        HotkeyManager.shared.updateManagerShortcut(keyCode: managerKeyCode, modifiers: managerModifiers)
    }
}

struct BottomFloatingHeightSettingView: View {
    @AppStorage(QuickPanelBottomDefaults.compactHeightPreferenceKey) private var compactHeightPreference = 0.0
    @State private var sliderValue = 0.0

    private var visibleFrame: CGRect {
        NSScreen.screenWithMouse?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private var resolvedHeight: Double {
        Double(QuickPanelBottomDefaults.storedDefaultCompactHeight(visibleFrame: visibleFrame))
    }

    private var heightRange: ClosedRange<Double> {
        let minimum = Double(QuickPanelBottomGeometry.minimumHeight(for: .compact))
        let maximum = Double(
            QuickPanelBottomGeometry.clampedHeight(
                visibleFrame.height - QuickPanelBottomGeometry.bottomInset,
                visibleFrame: visibleFrame,
                mode: .compact
            )
        )
        return minimum...max(minimum, maximum)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.tr("settings.quickPanelStyle.bottomFloating.height"))
                Spacer()
                Text("\(Int(sliderValue.rounded())) pt")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $sliderValue, in: heightRange, step: 4)
        }
        .onAppear {
            sliderValue = resolvedHeight
        }
        .onChange(of: compactHeightPreference) {
            sliderValue = resolvedHeight
        }
        .onChange(of: sliderValue) { _, newValue in
            applyCompactHeight(newValue)
        }
    }

    private func applyCompactHeight(_ newValue: Double) {
        let clamped = QuickPanelBottomGeometry.clampedHeight(
            CGFloat(newValue),
            visibleFrame: visibleFrame,
            mode: .compact
        )
        compactHeightPreference = Double(clamped)
        UserDefaults.standard.set(
            Double(clamped),
            forKey: "\(QuickPanelBottomDefaults.sizeStorageKey).compact.height"
        )
        QuickPanelWindowController.shared.setBottomFloatingMode(
            QuickPanelWindowController.shared.bottomMode,
            animated: false
        )
    }
}

struct OCRSettingsSection: View {
    @AppStorage(OCRTaskCoordinator.enableOCRKey) private var ocrEnabled = true
    @AppStorage(OCRTaskCoordinator.autoOCRKey) private var autoProcess = true
    @ObservedObject private var coordinator = OCRTaskCoordinator.shared

    var body: some View {
        Section(L10n.tr("settings.ocr")) {
            Toggle(L10n.tr("settings.ocr.enable"), isOn: $ocrEnabled)
            if ocrEnabled {
                Toggle(L10n.tr("settings.ocr.auto"), isOn: $autoProcess)

                if coordinator.isScanning {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: Double(coordinator.scanCompleted), total: Double(max(coordinator.scanTotal, 1)))
                        Text("\(coordinator.scanCompleted) / \(coordinator.scanTotal)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button(L10n.tr("settings.ocr.scanExisting")) {
                        OCRTaskCoordinator.shared.scanExistingImages()
                    }
                    .pointerCursor()
                }

                Text(L10n.tr("settings.ocr.hint"))
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct AnimationSettingsSection: View {
    @ObservedObject var preferences = AnimationPreferences.shared
    
    var body: some View {
        Section(L10n.tr("settings.animation")) {
            Picker(L10n.tr("settings.animation.style"), selection: $preferences.style) {
                ForEach(AnimationStyle.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.tr("settings.animation.speed"))
                    Spacer()
                    Text("\(Int(preferences.animationSpeed * 100))%")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                Slider(value: $preferences.animationSpeed, in: 0.5...2.0, step: 0.1)
            }
            
            Toggle(L10n.tr("settings.animation.microInteractions"), isOn: $preferences.enableMicroInteractions)
            
            Toggle(L10n.tr("settings.animation.transitions"), isOn: $preferences.enableTransitions)
            
            Text(L10n.tr("settings.animation.hint"))
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Relay Tab

struct RelayTab: View {
    @AppStorage("relayPasteKeyCode") private var relayPasteKeyCode = 0x09
    @AppStorage("relayPasteModifiers") private var relayPasteModifiers = controlKey
    @AppStorage("relayAlertDismissed") private var relayAlertDismissed = false

    private var pasteShortcut: String {
        shortcutDisplayString(keyCode: relayPasteKeyCode, modifiers: relayPasteModifiers)
    }

    var body: some View {
        Form {
            Section {
                Text(L10n.tr("relay.settings.description"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(L10n.tr("relay.settings.shortcuts")) {
                HStack {
                    Text(L10n.tr("relay.settings.pasteKey"))
                    Spacer()
                    ShortcutRecorder(keyCode: $relayPasteKeyCode, modifiers: $relayPasteModifiers)
                        .frame(width: 140, height: 24)
                        .disabled(RelayManager.shared.isActive && !RelayManager.shared.isPaused)
                }
                Text(RelayManager.shared.isActive && !RelayManager.shared.isPaused
                    ? L10n.tr("relay.settings.pauseToChange")
                    : L10n.tr("relay.settings.pasteKeyNote"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.tr("relay.settings.operations")) {
                HStack {
                    Text(L10n.tr("relay.settings.op.paste"))
                    Spacer()
                    Text(pasteShortcut)
                        .foregroundStyle(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
            }

            Section {
                if relayAlertDismissed {
                    Button(L10n.tr("relay.settings.resetAlert")) {
                        relayAlertDismissed = false
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

// MARK: - Privacy Tab

struct PrivacyTab: View {
    @AppStorage("sensitiveDetectionEnabled") private var isSensitiveDetectionEnabled = true

    var body: some View {
        Form {
            Section(L10n.tr("settings.privacy.sensitive")) {
                Toggle(L10n.tr("settings.privacy.sensitiveDetection"), isOn: $isSensitiveDetectionEnabled)
                Text(L10n.tr("settings.privacy.sensitiveHint"))
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }

            IgnoredAppsSection()
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

// MARK: - Automation Tab

struct AutomationTab: View {
    @AppStorage("automationEnabled") private var automationEnabled = true
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AutomationRule.sortOrder) private var rules: [AutomationRule]
    private var enabledCount: Int { rules.filter(\.enabled).count }

    var body: some View {
        Form {
            automationContent
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    private var automationContent: some View {
        Group {
            Section {
                Toggle(L10n.tr("settings.automation.enabled"), isOn: $automationEnabled)
            }

            Section(L10n.tr("settings.automation.ruleCount", rules.count, enabledCount)) {
                ForEach(rules) { rule in
                    Toggle(isOn: Binding(
                        get: { rule.enabled },
                        set: { rule.enabled = $0; try? modelContext.save() }
                    )) {
                        HStack {
                            Text(rule.isBuiltIn ? L10n.tr(rule.name) : rule.name)
                            Spacer()
                            Text(rule.triggerMode == .automatic
                                ? L10n.tr("settings.automation.auto")
                                : L10n.tr("settings.automation.manual"))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Section {
                Button(L10n.tr("settings.automation.manage")) {
                    AutomationManagerWindow.show()
                }
                .pointerCursor()

                Text(L10n.tr("settings.automation.hint"))
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
        }
    }

}

// MARK: - Pro Tab

struct SponsorTab: View {
    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.pink)

                    Text(L10n.tr("sponsor.title"))
                        .font(.headline)

                    Text(L10n.tr("sponsor.desc"))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                Link(destination: URL(string: "https://www.lifedever.com")!) {
                    Label(L10n.tr("sponsor.donate"), systemImage: "cup.and.saucer")
                }
                Link(destination: URL(string: "https://github.com/lifedever/PasteMemo-app")!) {
                    Label(L10n.tr("sponsor.star"), systemImage: "star")
                }
                Link(destination: URL(string: "https://github.com/lifedever/PasteMemo-app/issues")!) {
                    Label(L10n.tr("sponsor.feedback"), systemImage: "bubble.left")
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

// MARK: - About Tab

struct AboutTab: View {
    @ObservedObject private var updateChecker = UpdateChecker.shared

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    if let icon = NSApp.applicationIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 64, height: 64)
                    }
                    Text("PasteMemo")
                        .font(.title2.bold())
                    Text(L10n.tr("about.description"))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                HStack {
                    Text(L10n.tr("settings.currentVersion"))
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                        .foregroundStyle(.secondary)
                }
                Button(L10n.tr("menu.checkForUpdates")) {
                    Task { await updateChecker.checkForUpdates(userInitiated: true) }
                }
                .disabled(updateChecker.isChecking)
            }

            Section {
                Link(L10n.tr("about.website"), destination: URL(string: "https://www.lifedever.com/PasteMemo/")!)
                Link(L10n.tr("about.help"), destination: URL(string: "https://www.lifedever.com/PasteMemo/help/")!)
                Link(L10n.tr("menu.reportIssue"), destination: URL(string: "https://github.com/lifedever/PasteMemo-app/issues")!)
            }

            Section {
                HStack {
                    Text(L10n.tr("about.license"))
                    Spacer()
                    Text("GPL-3.0")
                        .foregroundStyle(.secondary)
                }
                Link(L10n.tr("about.sourceCode"), destination: URL(string: "https://github.com/lifedever/PasteMemo-app")!)
            }

            Section {
                Text("© 2026 lifedever.")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
