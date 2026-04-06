import Foundation

enum SearchMatcher {
    static func tokens(from query: String) -> [String] {
        query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func matches(query: String, in fields: [String?]) -> Bool {
        let tokens = tokens(from: query)
        guard !tokens.isEmpty else { return false }
        return matches(tokens: tokens, in: fields)
    }

    static func matches(tokens: [String], in fields: [String?]) -> Bool {
        guard !tokens.isEmpty else { return false }
        return tokens.allSatisfy { token in
            fields.contains { field in
                guard let field, !field.isEmpty else { return false }
                return field.localizedCaseInsensitiveContains(token)
            }
        }
    }

    static func firstMatchingToken(in text: String, query: String) -> String? {
        let tokens = tokens(from: query)
        guard !tokens.isEmpty else { return nil }
        return tokens.first { text.localizedCaseInsensitiveContains($0) }
    }
    
    // MARK: - Fuzzy Search
    
    static func fuzzyMatch(query: String, in text: String, threshold: Double = 0.6) -> Bool {
        let normalizedQuery = query.lowercased()
        let normalizedText = text.lowercased()
        
        if normalizedText.contains(normalizedQuery) {
            return true
        }
        
        let score = fuzzyScore(query: query, in: text)
        return score >= threshold
    }
    
    static func fuzzyScore(query: String, in text: String) -> Double {
        let s = query.lowercased()
        let t = text.lowercased()
        
        if s.isEmpty { return 1.0 }
        if t.isEmpty { return 0.0 }
        
        if s == t { return 1.0 }
        
        let distance = levenshteinDistance(s, t)
        let maxLength = Double(max(s.count, t.count))
        
        return 1.0 - (Double(distance) / maxLength)
    }
    
    private static func levenshteinDistance(_ s: String, _ t: String) -> Int {
        let sArray = Array(s)
        let tArray = Array(t)
        let sCount = sArray.count
        let tCount = tArray.count
        
        if sCount == 0 { return tCount }
        if tCount == 0 { return sCount }
        
        var matrix = Array(repeating: Array(repeating: 0, count: tCount + 1), count: sCount + 1)
        
        for i in 0...sCount {
            matrix[i][0] = i
        }
        
        for j in 0...tCount {
            matrix[0][j] = j
        }
        
        for i in 1...sCount {
            for j in 1...tCount {
                let cost = sArray[i - 1] == tArray[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }
        
        return matrix[sCount][tCount]
    }
    
    // MARK: - Regex Search
    
    static func regexMatch(pattern: String, in text: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines])
            let range = NSRange(text.startIndex..., in: text)
            return regex.firstMatch(in: text, options: [], range: range) != nil
        } catch {
            return false
        }
    }
    
    static func regexMatches(pattern: String, in text: String) -> [NSTextCheckingResult] {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(text.startIndex..., in: text)
            return regex.matches(in: text, options: [], range: range)
        } catch {
            return []
        }
    }
    
    // MARK: - Advanced Search
    
    static func advancedMatch(query: String, in fields: [String?], options: SearchOptions = SearchOptions()) -> Bool {
        let processedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !processedQuery.isEmpty else { return false }
        
        if processedQuery.hasPrefix("regex:") {
            let pattern = String(processedQuery.dropFirst(6))
            return fields.contains { field in
                guard let field, !field.isEmpty else { return false }
                return regexMatch(pattern: pattern, in: field)
            }
        }
        
        if processedQuery.hasPrefix("fuzzy:") {
            let fuzzyQuery = String(processedQuery.dropFirst(6))
            return fields.contains { field in
                guard let field, !field.isEmpty else { return false }
                return fuzzyMatch(query: fuzzyQuery, in: field, threshold: options.fuzzyThreshold)
            }
        }
        
        if options.enableFuzzy {
            return fields.contains { field in
                guard let field, !field.isEmpty else { return false }
                return fuzzyMatch(query: processedQuery, in: field, threshold: options.fuzzyThreshold)
            }
        }
        
        return matches(query: processedQuery, in: fields)
    }
}

struct SearchOptions {
    var enableFuzzy: Bool = false
    var fuzzyThreshold: Double = 0.6
    var enableRegex: Bool = false
    var caseSensitive: Bool = false
    
    static let `default` = SearchOptions()
    static let fuzzy = SearchOptions(enableFuzzy: true, fuzzyThreshold: 0.6)
    static let strict = SearchOptions(enableFuzzy: false, caseSensitive: true)
}
