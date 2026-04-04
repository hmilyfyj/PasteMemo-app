import AppKit
import os

@MainActor
final class MemoryMonitor {
    static let shared = MemoryMonitor()
    
    private let log = OSLog(subsystem: "com.lifedever.pastememo", category: "Memory")
    
    private init() {}
    
    func startMonitoring() {
        os_log("Memory monitoring started", log: log, type: .info)
    }
    
    func stopMonitoring() {
        os_log("Memory monitoring stopped", log: log, type: .info)
    }
    
    // MARK: - Memory Statistics
    
    func getMemoryUsage() -> MemoryUsage {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return MemoryUsage(resident: 0, virtual: 0)
        }
        
        let resident = Double(info.resident_size) / 1024.0 / 1024.0
        let virtual = Double(info.virtual_size) / 1024.0 / 1024.0
        
        return MemoryUsage(resident: resident, virtual: virtual)
    }
    
    func logMemoryUsage() {
        let usage = getMemoryUsage()
        os_log("Memory usage - Resident: %.2f MB, Virtual: %.2f MB", log: log, type: .info, usage.resident, usage.virtual)
    }
    
    func performCacheCleanup() {
        ImageCache.shared.clearPreloadTracking()
        os_log("Cache cleanup performed", log: log, type: .info)
    }
}

struct MemoryUsage {
    let resident: Double
    let virtual: Double
}


