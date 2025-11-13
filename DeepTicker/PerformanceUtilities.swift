import Foundation
import UIKit

// MARK: - Performance Monitoring

/// Utility for measuring performance of operations
@MainActor
final class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private init() {}
    
    /// Measure async operation performance
    func measureAsync<T>(
        _ name: String,
        operation: () async throws -> T
    ) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - start
            #if DEBUG
            print("⏱️ [\(name)] completed in \(String(format: "%.3f", duration))s")
            #endif
        }
        return try await operation()
    }
    
    /// Measure sync operation performance
    func measureSync<T>(
        _ name: String,
        operation: () throws -> T
    ) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - start
            #if DEBUG
            print("⏱️ [\(name)] completed in \(String(format: "%.3f", duration))s")
            #endif
        }
        return try operation()
    }
    
    /// Log memory usage
    func logMemoryUsage(tag: String = "") {
        #if DEBUG
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size) / 1024.0 / 1024.0
            print("💾 [\(tag.isEmpty ? "Memory" : tag)] \(String(format: "%.2f", usedMemory)) MB")
        }
        #endif
    }
}

// MARK: - Request Deduplication

/// Prevents duplicate network requests for the same resource
@MainActor
final class RequestDeduplicator {
    static let shared = RequestDeduplicator()
    
    private var ongoingRequests: [String: Task<Any, Error>] = [:]
    
    private init() {}
    
    /// Execute a request, or return the result of an ongoing identical request
    func deduplicate<T>(
        key: String,
        request: @escaping () async throws -> T
    ) async throws -> T {
        // If request is already ongoing, wait for it
        if let existingTask = ongoingRequests[key] {
            #if DEBUG
            print("🔄 [Dedupe] Reusing ongoing request: \(key)")
            #endif
            return try await existingTask.value as! T
        }
        
        // Create new task
        let task = Task<Any, Error> {
            defer {
                ongoingRequests.removeValue(forKey: key)
                #if DEBUG
                print("✅ [Dedupe] Completed request: \(key)")
                #endif
            }
            return try await request()
        }
        
        ongoingRequests[key] = task
        #if DEBUG
        print("🆕 [Dedupe] Starting new request: \(key)")
        #endif
        
        return try await task.value as! T
    }
    
    /// Cancel an ongoing request
    func cancel(key: String) {
        ongoingRequests[key]?.cancel()
        ongoingRequests.removeValue(forKey: key)
    }
    
    /// Cancel all ongoing requests
    func cancelAll() {
        for task in ongoingRequests.values {
            task.cancel()
        }
        ongoingRequests.removeAll()
    }
}

// MARK: - Image Cache Manager

/// Manages cached images with memory pressure awareness
@MainActor
final class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        configureCache()
        setupMemoryWarningHandler()
    }
    
    private func configureCache() {
        // Max 100 images
        cache.countLimit = 100
        
        // Max 50MB for images
        cache.totalCostLimit = 50 * 1024 * 1024
        
        // Evict automatically when low memory
        cache.evictsObjectsWithDiscardedContent = true
    }
    
    private func setupMemoryWarningHandler() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearCache()
        }
    }
    
    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }
    
    func setImage(_ image: UIImage, forKey key: String) {
        // Calculate cost based on image size (width × height × scale × scale)
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    @objc func clearCache() {
        cache.removeAllObjects()
        #if DEBUG
        print("⚠️ [ImageCache] Cleared due to memory warning")
        #endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Throttle Helper

/// Throttles function calls to prevent excessive execution
actor Throttler {
    private var lastExecutionTime: [String: Date] = [:]
    
    /// Execute function only if minimum interval has passed
    func execute<T>(
        key: String,
        interval: TimeInterval,
        allowFirstCall: Bool = true,
        operation: () async throws -> T
    ) async throws -> T? {
        let now = Date()
        
        if let lastTime = lastExecutionTime[key] {
            let timeSinceLastExecution = now.timeIntervalSince(lastTime)
            
            if timeSinceLastExecution < interval {
                #if DEBUG
                print("⏸️ [Throttle] Skipping '\(key)' - too soon (\(String(format: "%.1f", timeSinceLastExecution))s < \(interval)s)")
                #endif
                return nil
            }
        } else if !allowFirstCall {
            // First call but not allowed
            lastExecutionTime[key] = now
            return nil
        }
        
        lastExecutionTime[key] = now
        return try await operation()
    }
    
    func reset(key: String) {
        lastExecutionTime.removeValue(forKey: key)
    }
    
    func resetAll() {
        lastExecutionTime.removeAll()
    }
}

// MARK: - Debounce Helper

/// Debounces function calls (executes after delay, cancels previous)
actor Debouncer {
    private var pendingTasks: [String: Task<Void, Never>] = [:]
    
    /// Execute function after delay, canceling any pending execution
    func debounce(
        key: String,
        delay: TimeInterval,
        operation: @escaping () async -> Void
    ) {
        // Cancel previous task
        pendingTasks[key]?.cancel()
        
        // Schedule new task
        let task = Task {
            try? await Task.sleep(for: .seconds(delay))
            
            if !Task.isCancelled {
                await operation()
            }
        }
        
        pendingTasks[key] = task
    }
    
    func cancel(key: String) {
        pendingTasks[key]?.cancel()
        pendingTasks.removeValue(forKey: key)
    }
    
    func cancelAll() {
        for task in pendingTasks.values {
            task.cancel()
        }
        pendingTasks.removeAll()
    }
}

// MARK: - Memory Pressure Monitor

/// Monitors system memory pressure and notifies
@MainActor
final class MemoryPressureMonitor {
    static let shared = MemoryPressureMonitor()
    
    enum PressureLevel {
        case normal
        case warning
        case critical
    }
    
    private(set) var currentLevel: PressureLevel = .normal
    private var source: DispatchSourceMemoryPressure?
    
    private init() {
        setupMonitoring()
    }
    
    private func setupMonitoring() {
        source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        
        source?.setEventHandler { [weak self] in
            guard let self = self, let source = self.source else { return }
            
            let event = source.data
            
            if event.contains(.critical) {
                self.currentLevel = .critical
                self.handleCriticalMemoryPressure()
            } else if event.contains(.warning) {
                self.currentLevel = .warning
                self.handleMemoryWarning()
            }
        }
        
        source?.resume()
    }
    
    private func handleMemoryWarning() {
        #if DEBUG
        print("⚠️ [Memory Pressure] Warning level")
        #endif
        
        // Post notification for other components to react
        NotificationCenter.default.post(
            name: NSNotification.Name("MemoryPressureWarning"),
            object: nil
        )
    }
    
    private func handleCriticalMemoryPressure() {
        #if DEBUG
        print("🚨 [Memory Pressure] Critical level")
        #endif
        
        // Aggressive cleanup
        ImageCacheManager.shared.clearCache()
        
        // Post notification
        NotificationCenter.default.post(
            name: NSNotification.Name("MemoryPressureCritical"),
            object: nil
        )
    }
    
    deinit {
        source?.cancel()
    }
}

// MARK: - Extensions

extension Notification.Name {
    static let memoryPressureWarning = Notification.Name("MemoryPressureWarning")
    static let memoryPressureCritical = Notification.Name("MemoryPressureCritical")
}

