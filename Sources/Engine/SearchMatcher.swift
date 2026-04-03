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
}
