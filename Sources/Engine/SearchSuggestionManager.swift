import Foundation
import SwiftUI

@MainActor
class SearchSuggestionManager: ObservableObject {
    static let shared = SearchSuggestionManager()
    
    @Published var suggestions: [SearchSuggestion] = []
    @Published var recentSearches: [String] = []
    
    private let maxRecentSearches = 10
    private let maxSuggestions = 5
    private let recentSearchesKey = "recentSearches"
    
    private init() {
        loadRecentSearches()
    }
    
    // MARK: - Public Methods
    
    func getSuggestions(for query: String) -> [SearchSuggestion] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedQuery.isEmpty {
            return recentSearches.map { SearchSuggestion(text: $0, type: .recent) }
        }
        
        var allSuggestions: [SearchSuggestion] = []
        
        let recentMatches = recentSearches
            .filter { $0.localizedCaseInsensitiveContains(trimmedQuery) }
            .map { SearchSuggestion(text: $0, type: .recent) }
        allSuggestions.append(contentsOf: recentMatches)
        
        let quickActions = getQuickActionSuggestions(for: trimmedQuery)
        allSuggestions.append(contentsOf: quickActions)
        
        let advancedSuggestions = getAdvancedSearchSuggestions(for: trimmedQuery)
        allSuggestions.append(contentsOf: advancedSuggestions)
        
        suggestions = Array(allSuggestions.prefix(maxSuggestions))
        return suggestions
    }
    
    func recordSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if let existingIndex = recentSearches.firstIndex(of: trimmed) {
            recentSearches.remove(at: existingIndex)
        }
        
        recentSearches.insert(trimmed, at: 0)
        
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        
        saveRecentSearches()
    }
    
    func clearRecentSearches() {
        recentSearches.removeAll()
        saveRecentSearches()
        suggestions = []
    }
    
    // MARK: - Private Methods
    
    private func getQuickActionSuggestions(for query: String) -> [SearchSuggestion] {
        var suggestions: [SearchSuggestion] = []
        
        let lowercased = query.lowercased()
        
        if "type:".hasPrefix(lowercased) || "类型:".hasPrefix(lowercased) {
            suggestions.append(SearchSuggestion(text: "type:image", type: .quickAction, description: "搜索图片"))
            suggestions.append(SearchSuggestion(text: "type:link", type: .quickAction, description: "搜索链接"))
            suggestions.append(SearchSuggestion(text: "type:text", type: .quickAction, description: "搜索文本"))
        }
        
        if "fuzzy:".hasPrefix(lowercased) || "模糊:".hasPrefix(lowercased) {
            suggestions.append(SearchSuggestion(text: "fuzzy:\(query)", type: .quickAction, description: "模糊搜索"))
        }
        
        if "regex:".hasPrefix(lowercased) || "正则:".hasPrefix(lowercased) {
            suggestions.append(SearchSuggestion(text: "regex:.*", type: .quickAction, description: "正则搜索"))
        }
        
        return suggestions
    }
    
    private func getAdvancedSearchSuggestions(for query: String) -> [SearchSuggestion] {
        var suggestions: [SearchSuggestion] = []
        
        if query.contains("@") {
            suggestions.append(SearchSuggestion(text: query, type: .advanced, description: "邮箱地址"))
        }
        
        if query.range(of: "\\d{11}", options: .regularExpression) != nil {
            suggestions.append(SearchSuggestion(text: query, type: .advanced, description: "手机号码"))
        }
        
        if query.hasPrefix("http") || query.hasPrefix("www") {
            suggestions.append(SearchSuggestion(text: query, type: .advanced, description: "网址链接"))
        }
        
        return suggestions
    }
    
    private func loadRecentSearches() {
        if let saved = UserDefaults.standard.stringArray(forKey: recentSearchesKey) {
            recentSearches = saved
        }
    }
    
    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: recentSearchesKey)
    }
}

struct SearchSuggestion: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    let description: String?
    
    init(text: String, type: SuggestionType, description: String? = nil) {
        self.text = text
        self.type = type
        self.description = description
    }
    
    enum SuggestionType {
        case recent
        case quickAction
        case advanced
        case popular
        
        var icon: String {
            switch self {
            case .recent: return "clock.arrow.circlepath"
            case .quickAction: return "bolt.fill"
            case .advanced: return "sparkles"
            case .popular: return "flame.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .recent: return .secondary
            case .quickAction: return .blue
            case .advanced: return .purple
            case .popular: return .orange
            }
        }
    }
    
    static func == (lhs: SearchSuggestion, rhs: SearchSuggestion) -> Bool {
        lhs.text == rhs.text && lhs.type == rhs.type
    }
}

struct SearchSuggestionsView: View {
    let suggestions: [SearchSuggestion]
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions) { suggestion in
                Button {
                    onSelect(suggestion.text)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: suggestion.type.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(suggestion.type.color)
                            .frame(width: 16)
                        
                        Text(suggestion.text)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                        
                        if let description = suggestion.description {
                            Text("(\(description))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                if suggestion.id != suggestions.last?.id {
                    Divider()
                        .padding(.leading, 36)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}
