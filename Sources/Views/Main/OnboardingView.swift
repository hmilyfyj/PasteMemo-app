import SwiftUI
import AppKit
import Carbon

struct OnboardingView: View {
    @State private var currentStep = initialStep()
    @State private var isAccessibilityGranted = AXIsProcessTrusted()
    @State private var accessibilityTimer: Timer?
    @AppStorage("hotkeyKeyCode") private var hotkeyCode = 9
    @AppStorage("hotkeyModifiers") private var hotkeyModifiers = cmdKey | shiftKey
    @AppStorage("addNewLineAfterPaste") private var addNewLineAfterPaste = false
    @AppStorage("retentionDays") private var retentionDays = 90
    @AppStorage("sensitiveDetectionEnabled") private var sensitiveDetectionEnabled = true
    @AppStorage("soundEnabled") private var soundEnabled = false
    @AppStorage(QuickPanelStyle.storageKey) private var quickPanelStyle = QuickPanelStyle.bottomFloating.rawValue
    @State private var detectedManagers: [(bundleID: String, name: String, icon: NSImage)] = []
    @State private var selectedManagerIDs: Set<String> = []
    @State private var hasPasteApp = false
    @State private var pasteAppItemCount = 0
    @State private var isMigrating = false
    @State private var migrationProgress = ""
    @State private var migrationResult: String?

    private let totalSteps = 7
    private let allRetentionOptions = [1, 3, 7, 14, 30, 60, 90, 180, 365]

    private var availableOptions: [Int] { allRetentionOptions }

    private var showForever: Bool { true }
    private var isReturningUser: Bool { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch currentStep {
                case 0: welcomeStep
                case 1: accessibilityStep
                case 2: privacyAppsStep
                case 3: preferencesStep
                case 4: migrationStep
                case 5: relayIntroStep
                case 6: shortcutStep
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                if currentStep > 0 {
                    Button(L10n.tr("onboarding.back")) {
                        withAnimation { currentStep -= 1 }
                    }
                    .pointerCursor()
                }

                if isReturningUser && currentStep != 1 {
                    Button(L10n.tr("onboarding.skip")) {
                        completeOnboarding()
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .pointerCursor()
                }

                Spacer()
                stepIndicator
                Spacer()

                if currentStep < totalSteps - 1 {
                    let isDisabled = currentStep == 1 && !isAccessibilityGranted
                    Button(L10n.tr("onboarding.next")) {
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isDisabled)
                    .pointerCursor()
                } else {
                    Button(L10n.tr("onboarding.done")) {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .pointerCursor()
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
        .frame(width: 480, height: 420)
        .onAppear {
            // Only unregister hotkey on first-time onboarding (shortcut setup step)
            // so ShortcutRecorder can capture the key combo.
            // Skip when re-opening from settings — user already has shortcuts configured.
            if currentStep == 0, !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                HotkeyManager.shared.unregister()
            }
        }
        .onDisappear {
            stopAccessibilityPolling()
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 80, height: 80)
            }

            Text(L10n.tr("onboarding.welcome.title"))
                .font(.title2)
                .fontWeight(.bold)

            Text(L10n.tr("onboarding.welcome.desc"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding(28)
    }

    private var accessibilityStep: some View {
        VStack(spacing: 0) {
            Spacer()

            if isAccessibilityGranted {
                accessibilityGrantedView
            } else if isReturningUser {
                accessibilityUpdateView
            } else {
                accessibilityFirstInstallView
            }

            Spacer()
        }
        .padding(28)
        .onAppear {
            isAccessibilityGranted = AXIsProcessTrusted()
            if !isAccessibilityGranted { startAccessibilityPolling() }
        }
    }

    private var accessibilityGrantedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text(L10n.tr("onboarding.accessibility.title"))
                .font(.title2.bold())
            Label(L10n.tr("onboarding.accessibility.granted"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
        }
    }

    private var accessibilityFirstInstallView: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text(L10n.tr("onboarding.accessibility.title"))
                .font(.title2.bold())
            Text(L10n.tr("onboarding.accessibility.desc"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            accessibilityActionButton
        }
    }

    private var accessibilityUpdateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text(L10n.tr("accessibility.lost.title"))
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                accessibilityStepRow("1") {
                    Text(L10n.tr("accessibility.step1.prefix"))
                        .foregroundStyle(.secondary)
                    + Text(" ")
                    + Text(L10n.tr("accessibility.step1.path"))
                        .bold()
                        .foregroundStyle(.primary)
                }
                accessibilityStepRow("2") {
                    HStack(spacing: 3) {
                        Text(L10n.tr("accessibility.step2.find"))
                            .foregroundStyle(.secondary)
                        appLogoMini
                        Text("PasteMemo").bold()
                        Text(L10n.tr("accessibility.step2.separator")).foregroundStyle(.secondary)
                        Text(L10n.tr("accessibility.step2.pre"))
                            .foregroundStyle(.secondary)
                        Image(systemName: "trash").foregroundStyle(.secondary)
                        Text(L10n.tr("accessibility.step2.delete"))
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
                accessibilityStepRow("3") {
                    HStack(spacing: 3) {
                        Text(L10n.tr("accessibility.step3.add"))
                            .foregroundStyle(.secondary)
                        Image(systemName: "plus").foregroundStyle(.secondary)
                        Text(L10n.tr("accessibility.step3.readd"))
                            .foregroundStyle(.secondary)
                        appLogoMini
                        Text("PasteMemo").bold()
                    }
                    .font(.callout)
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            accessibilityActionButton
        }
    }

    private var accessibilityActionButton: some View {
        VStack(spacing: 8) {
            Button(L10n.tr("onboarding.accessibility.grant")) {
                ClipboardManager.shared.requestAccessibilityPermission()
                startAccessibilityPolling()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .pointerCursor()

            Text(L10n.tr("onboarding.accessibility.hint"))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var appLogoMini: some View {
        if let icon = NSApp.applicationIconImage {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 16, height: 16)
        }
    }

    private func accessibilityStepRow<V: View>(_ number: String, @ViewBuilder content: () -> V) -> some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.orange, in: Circle())
            content()
                .font(.callout)
        }
    }

    private var privacyAppsStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text(L10n.tr("onboarding.privacy.title"))
                .font(.title2)
                .fontWeight(.bold)

            Text(L10n.tr("onboarding.privacy.desc"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            if detectedManagers.isEmpty {
                Label(L10n.tr("onboarding.privacy.none"), systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                    .font(.callout)
                    .padding(.top, 4)
            } else {
                privacyAppsList
            }
        }
        .padding(28)
        .onAppear {
            detectedManagers = SensitiveDetector.installedPasswordManagers()
            // For returning users: check which are already ignored; for new users: select all
            if isReturningUser {
                selectedManagerIDs = Set(detectedManagers.filter { IgnoredAppsManager.shared.isIgnored($0.bundleID) }.map(\.bundleID))
            } else {
                selectedManagerIDs = Set(detectedManagers.map(\.bundleID))
            }
        }
    }

    private var privacyAppsList: some View {
        VStack(spacing: 6) {
            ForEach(Array(detectedManagers.enumerated()), id: \.element.bundleID) { _, app in
                let isSelected = selectedManagerIDs.contains(app.bundleID)
                Button {
                    if isSelected {
                        selectedManagerIDs.remove(app.bundleID)
                    } else {
                        selectedManagerIDs.insert(app.bundleID)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text(app.name)
                            .font(.system(size: 13))
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                            .font(.system(size: 16))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
        .frame(maxWidth: 320)
        .padding(.top, 4)
    }

    private var preferencesStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.orange, in: Circle())

            Text(L10n.tr("onboarding.preferences.title"))
                .font(.title2)
                .fontWeight(.bold)

            Text(L10n.tr("onboarding.preferences.desc"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            VStack(spacing: 0) {
                preferenceRow(
                    icon: "return",
                    title: L10n.tr("settings.addNewLine"),
                    isOn: $addNewLineAfterPaste
                )
                Divider().padding(.leading, 42)
                preferenceRow(
                    icon: "lock.shield",
                    title: L10n.tr("settings.privacy.sensitiveDetection"),
                    isOn: $sensitiveDetectionEnabled
                )
                Divider().padding(.leading, 42)
                preferenceRow(
                    icon: "speaker.wave.2",
                    title: L10n.tr("settings.sound.enabled"),
                    isOn: $soundEnabled
                )
                Divider().padding(.leading, 42)
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.3.group")
                        .frame(width: 20)
                        .foregroundStyle(.secondary)
                    Text(L10n.tr("settings.quickPanelStyle"))
                    Spacer()
                    Picker("", selection: $quickPanelStyle) {
                        Text(L10n.tr("settings.quickPanelStyle.classic")).tag(QuickPanelStyle.classic.rawValue)
                        Text(L10n.tr("settings.quickPanelStyle.bottomFloating")).tag(QuickPanelStyle.bottomFloating.rawValue)
                    }
                    .labelsHidden()
                    .onChange(of: quickPanelStyle) { _, newValue in
                        if newValue == QuickPanelStyle.bottomFloating.rawValue {
                            QuickPanelBottomDefaults.resetStoredSizing()
                        } else if newValue == QuickPanelStyle.classic.rawValue {
                            QuickPanelBottomDefaults.resetClassicSizing()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                Divider().padding(.leading, 42)
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .frame(width: 20)
                        .foregroundStyle(.secondary)
                    Text(L10n.tr("settings.retentionDays"))
                    Spacer()
                    Picker("", selection: $retentionDays) {
                        if showForever {
                            Text(L10n.tr("settings.retentionDays.forever")).tag(0)
                        }
                        ForEach(availableOptions, id: \.self) { days in
                            Text(L10n.tr("settings.retentionDays.days", days)).tag(days)
                        }
                    }
                    .labelsHidden()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: 340)
            .padding(.top, 4)
        }
        .padding(28)
    }

    private func preferenceRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(title)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var migrationStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.orange, in: Circle())

            Text(L10n.tr("onboarding.migration.title"))
                .font(.title2)
                .fontWeight(.bold)

            Text(L10n.tr("onboarding.migration.desc"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            if isMigrating {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(migrationProgress)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            } else if let result = migrationResult {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.green)
                    Text(result)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 4)
            } else if hasPasteApp {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "externaldrive.fill.badge.icloud")
                            .font(.system(size: 20))
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Paste.app")
                                .font(.callout)
                                .fontWeight(.medium)
                            Text(L10n.tr("onboarding.migration.found", pasteAppItemCount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: 320)

                    Button(L10n.tr("onboarding.migration.import")) {
                        performMigration()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .pointerCursor()
                }
                .padding(.top, 4)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(.green)
                    Text(L10n.tr("onboarding.migration.none"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(28)
        .onAppear {
            checkPasteApp()
        }
    }

    private func checkPasteApp() {
        hasPasteApp = PasteAppMigrator.checkPasteAppDatabaseExists()
        if hasPasteApp {
            pasteAppItemCount = PasteAppMigrator.getPasteAppItemCount()
        }
    }

    @MainActor
    private func performMigration() {
        guard !isMigrating else { return }
        
        isMigrating = true
        migrationProgress = ""
        migrationResult = nil
        
        Task {
            let container = PasteMemoApp.sharedModelContainer
            let context = container.mainContext
            
            let result = await PasteAppMigrator.migrate(
                into: context
            ) { current, total, status in
                Task { @MainActor in
                    migrationProgress = "\(current) / \(total) - \(status)"
                }
            }
            
            isMigrating = false
            migrationProgress = ""
            
            var message = L10n.tr("onboarding.migration.success", result.imported)
            if result.skipped > 0 {
                message += " " + L10n.tr("onboarding.migration.skipped", result.skipped)
            }
            migrationResult = message
        }
    }

    private var relayIntroStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.forward")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.orange, in: Circle())

            Text(L10n.tr("onboarding.relay.title"))
                .font(.title2)
                .fontWeight(.bold)

            Text(L10n.tr("onboarding.relay.desc"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            VStack(alignment: .leading, spacing: 8) {
                relayFeatureRow(icon: "doc.on.doc", text: L10n.tr("onboarding.relay.feature1"))
                relayFeatureRow(icon: "scissors", text: L10n.tr("onboarding.relay.feature2"))
                relayFeatureRow(icon: "keyboard", text: L10n.tr("onboarding.relay.feature3"))
            }
            .padding(.top, 4)
        }
        .padding(28)
    }

    private func relayFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.orange)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var shortcutStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "command")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.orange, in: Circle())

            Text(L10n.tr("onboarding.shortcut.title"))
                .font(.title2)
                .fontWeight(.bold)

            Text(L10n.tr("onboarding.shortcut.desc"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            VStack(spacing: 8) {
                Text(L10n.tr("onboarding.shortcut.current"))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                ShortcutRecorder(keyCode: $hotkeyCode, modifiers: $hotkeyModifiers)
                    .frame(width: 200, height: 28)
            }
            .padding(.top, 4)

            Text(L10n.tr("onboarding.helpHint"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding(28)
    }

    // If already completed onboarding but accessibility is off, jump to step 1
    private static func initialStep() -> Int {
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if hasCompleted && !AXIsProcessTrusted() { return 1 }
        return 0
    }

    // MARK: - Components

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Circle()
                    .fill(i == currentStep ? Color.orange : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
    }

    // MARK: - Accessibility Polling

    private func startAccessibilityPolling() {
        stopAccessibilityPolling()
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                let granted = AXIsProcessTrusted()
                if granted != isAccessibilityGranted {
                    withAnimation { isAccessibilityGranted = granted }
                }
                if granted { stopAccessibilityPolling() }
            }
        }
    }

    private func stopAccessibilityPolling() {
        accessibilityTimer?.invalidate()
        accessibilityTimer = nil
    }

    private func completeOnboarding() {
        // Sync password manager ignore list with selections
        for app in detectedManagers {
            if selectedManagerIDs.contains(app.bundleID) {
                IgnoredAppsManager.shared.addApp(bundleID: app.bundleID, name: app.name)
            } else {
                IgnoredAppsManager.shared.removeApp(bundleID: app.bundleID)
            }
        }

        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        HotkeyManager.shared.register()
        WindowManager.shared.close(id: "onboarding")

        // 直接打开剪贴板列表（QuickPanel），而不是管理器窗口
        // 让用户立即看到剪贴板历史，提供更好的首次使用体验
        QuickPanelWindowController.shared.show(
            clipboardManager: ClipboardManager.shared,
            modelContainer: PasteMemoApp.sharedModelContainer
        )
        
        // 首次完成时显示帮助窗口
        if !UserDefaults.standard.bool(forKey: "hasShownFirstHelp") {
            UserDefaults.standard.set(true, forKey: "hasShownFirstHelp")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showHelpWindow()
            }
        }

        // Start update checks
        Task {
            await UpdateChecker.shared.checkForUpdates()
            UpdateChecker.shared.startPeriodicChecks()
        }
    }
}
