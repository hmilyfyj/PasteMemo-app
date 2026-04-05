import Foundation

@MainActor
final class AnimationLogger {
    static let shared = AnimationLogger()
    
    private let logFileURL: URL
    private let fileManager = FileManager.default
    private var isInitialized = false
    
    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.lifedever.pastememo"
        let logDir = appSupport.appendingPathComponent(bundleID)
        
        logFileURL = logDir.appendingPathComponent("animation_debug.log")
        
        do {
            try fileManager.createDirectory(at: logDir, withIntermediateDirectories: true)
            isInitialized = true
            NSLog("✅ AnimationLogger initialized, log path: \(logFileURL.path)")
        } catch {
            NSLog("❌ AnimationLogger failed to create directory: \(error)")
        }
        
        if fileManager.fileExists(atPath: logFileURL.path) {
            try? fileManager.removeItem(at: logFileURL)
        }
        
        fileManager.createFile(atPath: logFileURL.path, contents: nil)
    }
    
    func log(_ message: String) {
        guard isInitialized else {
            NSLog("❌ AnimationLogger not initialized, cannot log: \(message)")
            return
        }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        guard let data = logMessage.data(using: .utf8) else { return }
        
        do {
            let fileHandle = try FileHandle(forWritingTo: logFileURL)
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            try fileHandle.close()
        } catch {
            NSLog("❌ AnimationLogger failed to write: \(error)")
        }
    }
    
    func logPath() -> String {
        return logFileURL.path
    }
}
