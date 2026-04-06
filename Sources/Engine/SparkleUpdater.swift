import AppKit
import Foundation
import Sparkle

@MainActor
final class SparkleUpdater: ObservableObject {
    static let shared = SparkleUpdater()

    private let delegateProxy: SparkleUpdaterDelegateProxy
    private let updaterController: SPUStandardUpdaterController
    private let updater: SPUUpdater

    @Published var canCheckForUpdates = false

    private init() {
        delegateProxy = SparkleUpdaterDelegateProxy()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: delegateProxy,
            userDriverDelegate: nil
        )
        updater = updaterController.updater

        canCheckForUpdates = true
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    func checkForUpdatesInBackground() {
        Task {
            await updater.checkForUpdates()
        }
    }
}

private final class SparkleUpdaterDelegateProxy: NSObject, SPUUpdaterDelegate {
    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        AppDelegate.shouldReallyQuit = true
    }
}
