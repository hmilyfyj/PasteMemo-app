import Foundation
import SwiftData

@MainActor
final class ClipItemCache {
    static let shared = ClipItemCache()
    
    private var itemsCache: [String: ClipItem] = [:]
    private var typeIndex: [ClipContentType: Set<String>] = [:]
    private var appIndex: [String: Set<String>] = [:]
    private var dateIndex: [(date: Date, id: String)] = []
    
    private var lastQuery: String = ""
    private var lastQueryResults: [String] = []
    
    private let maxCacheSize = 500
    private var cacheQueue = Set<String>()
    
    private init() {}
    
    // MARK: - Cache Management
    
    func cache(_ item: ClipItem) {
        guard itemsCache.count < maxCacheSize else { return }
        
        itemsCache[item.itemID] = item
        cacheQueue.insert(item.itemID)
        
        typeIndex[item.contentType, default: []].insert(item.itemID)
        
        if let app = item.sourceApp {
            appIndex[app, default: []].insert(item.itemID)
        }
        
        dateIndex.append((date: item.lastUsedAt, id: item.itemID))
        dateIndex.sort { $0.date > $1.date }
    }
    
    func cache(_ items: [ClipItem]) {
        for item in items {
            cache(item)
        }
    }
    
    func get(itemID: String) -> ClipItem? {
        return itemsCache[itemID]
    }
    
    func remove(itemID: String) {
        itemsCache.removeValue(forKey: itemID)
        cacheQueue.remove(itemID)
        
        for (type, var ids) in typeIndex {
            ids.remove(itemID)
            typeIndex[type] = ids
        }
        
        for (app, var ids) in appIndex {
            ids.remove(itemID)
            appIndex[app] = ids
        }
        
        dateIndex.removeAll { $0.id == itemID }
    }
    
    func clear() {
        itemsCache.removeAll()
        typeIndex.removeAll()
        appIndex.removeAll()
        dateIndex.removeAll()
        cacheQueue.removeAll()
        lastQuery = ""
        lastQueryResults.removeAll()
    }
    
    // MARK: - Index Queries
    
    func getIDs(byType type: ClipContentType) -> [String] {
        guard let ids = typeIndex[type] else { return [] }
        return Array(ids)
    }
    
    func getIDs(byApp app: String) -> [String] {
        guard let ids = appIndex[app] else { return [] }
        return Array(ids)
    }
    
    func getRecentIDs(limit: Int = 50) -> [String] {
        return Array(dateIndex.prefix(limit).map { $0.id })
    }
    
    // MARK: - Incremental Search
    
    func incrementalSearch(query: String, in items: [String]) -> [String] {
        let tokens = SearchMatcher.tokens(from: query)
        guard !tokens.isEmpty else { return items }
        
        if query.hasPrefix(lastQuery) && !lastQuery.isEmpty {
            let searchSpace = lastQueryResults.isEmpty ? items : lastQueryResults
            let results = searchSpace.filter { itemID in
                guard let item = itemsCache[itemID] else { return false }
                return tokens.allSatisfy { token in
                    item.content.localizedCaseInsensitiveContains(token) ||
                    (item.displayTitle?.localizedCaseInsensitiveContains(token) ?? false) ||
                    (item.linkTitle?.localizedCaseInsensitiveContains(token) ?? false) ||
                    (item.ocrText?.localizedCaseInsensitiveContains(token) ?? false)
                }
            }
            lastQuery = query
            lastQueryResults = results
            return results
        }
        
        let results = items.filter { itemID in
            guard let item = itemsCache[itemID] else { return false }
            return tokens.allSatisfy { token in
                item.content.localizedCaseInsensitiveContains(token) ||
                (item.displayTitle?.localizedCaseInsensitiveContains(token) ?? false) ||
                (item.linkTitle?.localizedCaseInsensitiveContains(token) ?? false) ||
                (item.ocrText?.localizedCaseInsensitiveContains(token) ?? false)
            }
        }
        lastQuery = query
        lastQueryResults = results
        return results
    }
    
    // MARK: - Statistics
    
    var cacheSize: Int {
        return itemsCache.count
    }
    
    var hitRate: Double {
        guard cacheQueue.count > 0 else { return 0 }
        return Double(itemsCache.count) / Double(maxCacheSize)
    }
}
