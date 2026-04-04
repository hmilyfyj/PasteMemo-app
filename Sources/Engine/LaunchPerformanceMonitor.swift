import Foundation
import os.signpost

@MainActor
final class LaunchPerformanceMonitor {
    static let shared = LaunchPerformanceMonitor()
    
    private var launchStartTime: Date?
    private var stages: [LaunchStage] = []
    private let log = OSLog(subsystem: "com.lifedever.pastememo", category: "Launch")
    
    struct LaunchStage {
        let name: String
        let startTime: Date
        var duration: TimeInterval?
    }
    
    private init() {}
    
    func startMonitoring() {
        launchStartTime = Date()
        os_signpost(.begin, log: log, name: "App Launch")
    }
    
    func beginStage(_ name: String) {
        let stage = LaunchStage(name: name, startTime: Date())
        stages.append(stage)
        os_signpost(.begin, log: log, name: "Stage")
    }
    
    func endStage(_ name: String) {
        guard let index = stages.firstIndex(where: { $0.name == name }) else { return }
        stages[index].duration = Date().timeIntervalSince(stages[index].startTime)
        os_signpost(.end, log: log, name: "Stage")
    }
    
    func endMonitoring() {
        guard let launchStartTime else { return }
        let totalDuration = Date().timeIntervalSince(launchStartTime)
        os_signpost(.end, log: log, name: "App Launch")
        
        #if DEBUG
        print("🚀 [Launch Performance Report]")
        print("   Total launch time: \(String(format: "%.2f", totalDuration * 1000))ms")
        for stage in stages {
            if let duration = stage.duration {
                print("   - \(stage.name): \(String(format: "%.2f", duration * 1000))ms")
            }
        }
        #endif
    }
    
    func generateReport() -> LaunchReport {
        let totalDuration = launchStartTime.map { Date().timeIntervalSince($0) } ?? 0
        return LaunchReport(
            totalDuration: totalDuration,
            stages: stages.compactMap { stage in
                stage.duration.map { StageReport(name: stage.name, duration: $0) }
            }
        )
    }
}

struct LaunchReport {
    let totalDuration: TimeInterval
    let stages: [StageReport]
    
    var summary: String {
        let total = String(format: "%.2f", totalDuration * 1000)
        let critical = stages.filter { $0.duration > 0.1 }
            .map { "\($0.name): \(String(format: "%.2f", $0.duration * 1000))ms" }
            .joined(separator: "\n   ")
        
        return """
        🚀 Launch Performance Report
        Total: \(total)ms
        Critical Stages:
           \(critical)
        """
    }
}

struct StageReport {
    let name: String
    let duration: TimeInterval
}
