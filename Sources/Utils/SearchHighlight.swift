import SwiftUI

struct HighlightedText: View {
    let text: String
    let query: String
    let highlightColor: Color
    
    init(_ text: String, query: String, highlightColor: Color = .yellow) {
        self.text = text
        self.query = query
        self.highlightColor = highlightColor
    }
    
    var body: some View {
        if query.isEmpty {
            Text(text)
        } else {
            Text(highlightedAttributedString())
        }
    }
    
    private func highlightedAttributedString() -> AttributedString {
        var result = AttributedString(text)
        let lowercasedText = text.lowercased()
        let lowercasedQuery = query.lowercased()
        
        var searchStartIndex = lowercasedText.startIndex
        
        while searchStartIndex < lowercasedText.endIndex,
              let range = lowercasedText[searchStartIndex...].range(of: lowercasedQuery),
              !range.isEmpty {
            
            let lowerBound = range.lowerBound
            let upperBound = range.upperBound
            
            if let resultRange = Range(lowerBound..<upperBound, in: result) {
                result[resultRange].backgroundColor = highlightColor.opacity(0.3)
                result[resultRange].font = .body.weight(.medium)
            }
            
            searchStartIndex = upperBound
        }
        
        return result
    }
}

struct RegexHighlightedText: View {
    let text: String
    let pattern: String
    let highlightColor: Color
    
    init(_ text: String, pattern: String, highlightColor: Color = .yellow) {
        self.text = text
        self.pattern = pattern
        self.highlightColor = highlightColor
    }
    
    var body: some View {
        if pattern.isEmpty {
            Text(text)
        } else {
            Text(highlightedAttributedString())
        }
    }
    
    private func highlightedAttributedString() -> AttributedString {
        var result = AttributedString(text)
        
        let matches = SearchMatcher.regexMatches(pattern: pattern, in: text)
        
        for match in matches.reversed() {
            if let range = Range(match.range, in: text),
               let resultRange = Range(range, in: result) {
                result[resultRange].backgroundColor = highlightColor.opacity(0.3)
                result[resultRange].font = .body.weight(.medium)
            }
        }
        
        return result
    }
}

extension View {
    func searchHighlight(_ query: String, color: Color = .yellow) -> some View {
        self.overlay(
            SearchHighlightOverlay(query: query, color: color)
        )
    }
}

private struct SearchHighlightOverlay: View {
    let query: String
    let color: Color
    
    var body: some View {
        EmptyView()
    }
}

struct MultiFieldSearchHighlight: View {
    let fields: [(text: String, label: String)]
    let query: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(fields.indices, id: \.self) { index in
                if !fields[index].text.isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        if fields.count > 1 {
                            Text(fields[index].label + ":")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HighlightedText(fields[index].text, query: query)
                            .font(.body)
                    }
                }
            }
        }
    }
}
