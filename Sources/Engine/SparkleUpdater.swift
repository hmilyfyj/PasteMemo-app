import AppKit
import Foundation
import Sparkle

@MainActor
final class SparkleUpdater: ObservableObject {
    static let shared = SparkleUpdater()

    private let updaterController: SPUStandardUpdaterController
    private let updater: SPUUpdater

    @Published var canCheckForUpdates = false

    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updater = updaterController.updater

        Task { @MainActor in
            self.canCheckForUpdates = await updater.canCheckForUpdates
        }
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    func checkForUpdatesInBackground() {
        Task {
            await updater.checkForUpdates()
        }
    }

    func startUpdater() {
        updaterController.startUpdater()
    }
}
