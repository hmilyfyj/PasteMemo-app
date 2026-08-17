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
            Text(makeHighlightedText())
        }
    }

    private func makeHighlightedText() -> AttributedString {
        var result = AttributedString(text)
        let lowercasedText = text.lowercased()
        let lowercasedQuery = query.lowercased()
        guard !lowercasedQuery.isEmpty else { return result }

        var searchStartIndex = lowercasedText.startIndex
        var ranges: [Range<String.Index>] = []
        while searchStartIndex < lowercasedText.endIndex {
            if let range = lowercasedText[searchStartIndex...].range(of: lowercasedQuery) {
                ranges.append(range)
                searchStartIndex = range.upperBound
            } else {
                break
            }
        }

        for range in ranges.reversed() {
            if let resultRange = Range(range, in: result) {
                result[resultRange].backgroundColor = highlightColor
                result[resultRange].font = .system(size: 13, weight: .bold)
                result[resultRange].foregroundColor = .black
            }
        }
        return result
    }
}
