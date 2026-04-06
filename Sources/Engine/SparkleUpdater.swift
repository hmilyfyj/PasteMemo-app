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
