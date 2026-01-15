import Foundation
import os.log

/// Performance logging for debugging launch and interaction times
/// Thread-safe for use from any actor context
enum PerfLog {
    private static let logger = Logger(subsystem: "com.claudit", category: "performance")
    private static let lock = NSLock()
    private nonisolated(unsafe) static var timestamps: [String: CFAbsoluteTime] = [:]

    /// Start timing an operation
    static func start(_ operation: String) {
        #if DEBUG
        lock.lock()
        timestamps[operation] = CFAbsoluteTimeGetCurrent()
        lock.unlock()
        #endif
    }

    /// End timing and log duration
    static func end(_ operation: String) {
        #if DEBUG
        lock.lock()
        guard let startTime = timestamps[operation] else {
            lock.unlock()
            return
        }
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        timestamps.removeValue(forKey: operation)
        lock.unlock()
        logger.info("⏱ \(operation): \(String(format: "%.1f", duration))ms")
        #endif
    }

    /// Log a simple message (debug only)
    static func log(_ message: String) {
        #if DEBUG
        logger.debug("\(message)")
        #endif
    }
}
