import Foundation
import SwiftUI
import Combine

// MARK: - Cache Configuration

struct CacheConfiguration: Sendable {
    let memoryCapacity: Int
    let diskCapacity: Int
    let defaultExpiry: TimeInterval
    let maxRetryAttempts: Int
    
    static let `default` = CacheConfiguration(
        memoryCapacity: 50 * 1024 * 1024, // 50MB
        diskCapacity: 200 * 1024 * 1024,  // 200MB
        defaultExpiry: 15 * 60,           // 15 minutes
        maxRetryAttempts: 3
    )
}

// MARK: - Cache Entry Model

struct CacheEntry<T: Codable & Sendable>: Codable, Sendable {
    let data: T
    let timestamp: Date
    let expiry: TimeInterval
    let version: String

    nonisolated var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > expiry
    }

    nonisolated var remainingTime: TimeInterval {
        expiry - Date().timeIntervalSince(timestamp)
    }

    init(data: T, expiry: TimeInterval = CacheConfiguration.default.defaultExpiry, version: String = "1.0") {
        self.data = data
        self.timestamp = Date()
        self.expiry = expiry
        self.version = version
    }

    private enum CodingKeys: String, CodingKey {
        case data
        case timestampSeconds
        case expiry
        case version
    }

    // Provide a custom, nonisolated decoding init to avoid main-actor isolated conformance usage during decoding in non-main actors.
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.data = try container.decode(T.self, forKey: .data)
        let seconds = try container.decode(Double.self, forKey: .timestampSeconds)
        self.timestamp = Date(timeIntervalSince1970: seconds)
        self.expiry = try container.decode(TimeInterval.self, forKey: .expiry)
        self.version = try container.decode(String.self, forKey: .version)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        try container.encode(timestamp.timeIntervalSince1970, forKey: .timestampSeconds)
        try container.encode(expiry, forKey: .expiry)
        try container.encode(version, forKey: .version)
    }
}

// MARK: - Cache Manager Protocol

protocol CacheManaging {
    func get<T: Codable & Sendable>(_ key: String, type: T.Type) async -> T?
    func set<T: Codable & Sendable>(_ key: String, value: T, expiry: TimeInterval?) async
    func remove(_ key: String) async
    func clear() async
    func clearExpired() async
    func getCacheSize() async -> Int64
    func getCacheInfo() async -> CacheInfo
}

struct CacheInfo: Sendable {
    let totalSize: Int64
    let entryCount: Int
    let memoryHits: Int
    let diskHits: Int
    let misses: Int
    let hitRate: Double
}

// MARK: - Disk Cache Actor

actor DiskCacheActor {
    enum CacheError: Error {
        case notFound
        case expired
        case decodingError
        case encodingError
        case ioError
    }
    
    func loadEntry<T: Codable & Sendable>(key: String, type: T.Type, cacheDirectory: URL) async -> Result<CacheEntry<T>, CacheError> {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let entry = try JSONDecoder().decode(CacheEntry<T>.self, from: data)
            
            if entry.isExpired {
                return .failure(.expired)
            }
            
            return .success(entry)
        } catch {
            if (error as NSError).code == NSFileReadNoSuchFileError {
                return .failure(.notFound)
            }
            return .failure(.decodingError)
        }
    }
    
    func saveEntry<T: Codable & Sendable>(key: String, entry: CacheEntry<T>, cacheDirectory: URL) async {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        
        do {
            let data = try JSONEncoder().encode(entry)
            try data.write(to: fileURL)
        } catch {
            // Log error in production
            print("Failed to save cache entry for key \(key): \(error)")
        }
    }
    
    func removeEntry(key: String, cacheDirectory: URL) async {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func clearAll(cacheDirectory: URL) async {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in contents where fileURL.pathExtension == "cache" {
                try? FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            // Directory might not exist yet
        }
    }
    
    func clearExpiredEntries(cacheDirectory: URL) async -> [String] {
        var expiredKeys: [String] = []
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in contents where fileURL.pathExtension == "cache" {
                let key = fileURL.deletingPathExtension().lastPathComponent
                
                do {
                    let data = try Data(contentsOf: fileURL)
                    
                    // Try to decode as a generic entry to check expiration
                    if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let timestampDouble = jsonObject["timestamp"] as? Double,
                       let expiry = jsonObject["expiry"] as? Double {
                        
                        let timestamp = Date(timeIntervalSince1970: timestampDouble)
                        if Date().timeIntervalSince(timestamp) > expiry {
                            try? FileManager.default.removeItem(at: fileURL)
                            expiredKeys.append(key)
                        }
                    }
                } catch {
                    // If we can't read the file, consider it corrupted and remove it
                    try? FileManager.default.removeItem(at: fileURL)
                    expiredKeys.append(key)
                }
            }
        } catch {
            // Directory might not exist
        }
        
        return expiredKeys
    }
    
    func getCacheSize(cacheDirectory: URL) async -> Int64 {
        var totalSize: Int64 = 0
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            for fileURL in contents where fileURL.pathExtension == "cache" {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        } catch {
            // Directory might not exist
        }
        
        return totalSize
    }
    
    func getEntryCount(cacheDirectory: URL) async -> Int {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            return contents.filter { $0.pathExtension == "cache" }.count
        } catch {
            return 0
        }
    }
}

// MARK: - Smart Cache Manager

@MainActor
class SmartCacheManager: ObservableObject, CacheManaging {
    static let shared = SmartCacheManager(configuration: .default)
    
    private let memoryCache = NSCache<NSString, CacheEntryWrapper>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let configuration: CacheConfiguration
    
    // Analytics
    @Published private(set) var cacheStats = CacheStats()
    
    // Background actor for disk operations
    private let diskActor = DiskCacheActor()
    
    private init(configuration: CacheConfiguration) {
        self.configuration = configuration
        
        // Setup cache directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cachesDirectory.appendingPathComponent("SmartCache")
        
        setupCache()
        scheduleCleanup()
    }
    
    private func setupCache() {
        // Configure memory cache
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = configuration.memoryCapacity
        
        // Create cache directory
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Setup background cleanup
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.clearExpired()
            }
        }
    }
    
    // MARK: - Public API
    
    func get<T: Codable & Sendable>(_ key: String, type: T.Type) async -> T? {
        // Try memory cache first
        if let wrapper = memoryCache.object(forKey: key as NSString) {
            if let entry = wrapper.entry as? CacheEntry<T>, !entry.isExpired {
                updateStats(memoryHit: true)
                return entry.data
            } else {
                // Remove expired entry
                memoryCache.removeObject(forKey: key as NSString)
            }
        }
        
        // Try disk cache
        let result = await diskActor.loadEntry(key: key, type: type, cacheDirectory: cacheDirectory)
        
        switch result {
        case .success(let entry):
            // Cache in memory for faster future access
            let wrapper = CacheEntryWrapper(entry: entry)
            memoryCache.setObject(wrapper, forKey: key as NSString)
            updateStats(diskHit: true)
            return entry.data
        case .failure(.expired):
            await diskActor.removeEntry(key: key, cacheDirectory: cacheDirectory)
            updateStats(miss: true)
            return nil
        case .failure(.notFound),
             .failure(.decodingError),
             .failure(.ioError),
             .failure(.encodingError):
            updateStats(miss: true)
            return nil
        }
    }
    
    func set<T: Codable & Sendable>(_ key: String, value: T, expiry: TimeInterval? = nil) async {
        let entry = CacheEntry(data: value, expiry: expiry ?? configuration.defaultExpiry)
        let wrapper = CacheEntryWrapper(entry: entry)
        
        // Store in memory
        memoryCache.setObject(wrapper, forKey: key as NSString)
        
        // Store on disk
        await diskActor.saveEntry(key: key, entry: entry, cacheDirectory: cacheDirectory)
    }
    
    func remove(_ key: String) async {
        memoryCache.removeObject(forKey: key as NSString)
        await diskActor.removeEntry(key: key, cacheDirectory: cacheDirectory)
    }
    
    func clear() async {
        memoryCache.removeAllObjects()
        await diskActor.clearAll(cacheDirectory: cacheDirectory)
        resetStats()
    }
    
    func clearExpired() async {
        let expiredKeys = await diskActor.clearExpiredEntries(cacheDirectory: cacheDirectory)
        
        // Remove expired entries from memory cache
        for key in expiredKeys {
            memoryCache.removeObject(forKey: key as NSString)
        }
    }
    
    nonisolated func getCacheSize() async -> Int64 {
        await diskActor.getCacheSize(cacheDirectory: cacheDirectory)
    }
    
    nonisolated func getCacheInfo() async -> CacheInfo {
        let size = await getCacheSize()
        let entryCount = await diskActor.getEntryCount(cacheDirectory: cacheDirectory)
        
        return await MainActor.run {
            let stats = self.cacheStats
            let totalRequests = stats.memoryHits + stats.diskHits + stats.misses
            let hitRate = totalRequests > 0 ? Double(stats.memoryHits + stats.diskHits) / Double(totalRequests) : 0
            
            return CacheInfo(
                totalSize: size,
                entryCount: entryCount,
                memoryHits: stats.memoryHits,
                diskHits: stats.diskHits,
                misses: stats.misses,
                hitRate: hitRate
            )
        }
    }
    
    // MARK: - Private Helpers
    
    private func scheduleCleanup() {
        Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in // Every 30 minutes
            guard let self = self else { return }
            Task { @MainActor in
                await self.clearExpired()
            }
        }
    }
    
    @MainActor
    private func updateStats(memoryHit: Bool = false, diskHit: Bool = false, miss: Bool = false) {
        if memoryHit {
            cacheStats.memoryHits += 1
        } else if diskHit {
            cacheStats.diskHits += 1
        } else if miss {
            cacheStats.misses += 1
        }
    }
    
    @MainActor
    private func resetStats() {
        cacheStats = CacheStats()
    }
}

// MARK: - Helper Classes

private class CacheEntryWrapper: NSObject {
    let entry: Any
    
    init(entry: Any) {
        self.entry = entry
    }
}

struct CacheStats {
    var memoryHits = 0
    var diskHits = 0
    var misses = 0
}

// MARK: - DispatchQueue Extension

private extension DispatchQueue {
    func run<T>(_ work: @escaping () -> T) async -> T {
        return await withCheckedContinuation { continuation in
            self.async {
                let result = work()
                continuation.resume(returning: result)
            }
        }
    }
}

