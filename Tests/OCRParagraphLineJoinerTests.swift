import CoreGraphics
import Testing
@testable import PasteMemo

@Suite("OCR paragraph line joiner (wrap vs hard break)")
struct OCRParagraphLineJoinerTests {

    /// Real geometry from issue repro: a meme image whose 9 short lines Vision
    /// groups into ONE paragraph (its own transcript already glues them).
    /// Every visual line is an intentional hard break and must survive.
    /// Note lines 6/7 run flush to the block edge — only the block-level
    /// "mostly hard breaks" rule keeps their breaks too.
    @Test("Line-structured CJK block keeps every line break")
    func memeBlockKeepsAllBreaks() {
        let lines = [
            OCRParagraphLine(text: "AI的尽头是算力", minX: 0.035, maxX: 0.701),
            OCRParagraphLine(text: "算力的尽头是电力", minX: 0.035, maxX: 0.796),
            OCRParagraphLine(text: "电力的尽头是储能", minX: 0.042, maxX: 0.803),
            OCRParagraphLine(text: "储能的尽头是电池", minX: 0.037, maxX: 0.800),
            OCRParagraphLine(text: "电池的尽头是锂矿", minX: 0.045, maxX: 0.803),
            OCRParagraphLine(text: "锂矿的尽头是开采", minX: 0.035, maxX: 0.805),
            OCRParagraphLine(text: "开采的尽头是人情世故", minX: 0.035, maxX: 0.993),
            OCRParagraphLine(text: "人情世故的尽头是白酒", minX: 0.032, maxX: 0.990),
            OCRParagraphLine(text: "所以重仓白酒！", minX: 0.036, maxX: 0.692),
        ]

        #expect(OCRParagraphLineJoiner.join(lines) == """
        AI的尽头是算力
        算力的尽头是电力
        电力的尽头是储能
        储能的尽头是电池
        电池的尽头是锂矿
        锂矿的尽头是开采
        开采的尽头是人情世故
        人情世故的尽头是白酒
        所以重仓白酒！
        """)
    }

    @Test("Wrapped CJK prose merges into one line without spaces")
    func wrappedCJKProseMerges() {
        let lines = [
            OCRParagraphLine(text: "这是一个很长的段落它会自动折行", minX: 0.03, maxX: 0.97),
            OCRParagraphLine(text: "并且继续下去直到结束为止的文字", minX: 0.03, maxX: 0.97),
            OCRParagraphLine(text: "最后一行比较短。", minX: 0.03, maxX: 0.53),
        ]

        #expect(OCRParagraphLineJoiner.join(lines)
            == "这是一个很长的段落它会自动折行并且继续下去直到结束为止的文字最后一行比较短。")
    }

    /// Real geometry from a rendered wrapped paragraph: the last line mixes
    /// CJK and Latin ("…关注。The"), whose plain per-character average width
    /// underestimates a CJK unit — without CJK-equivalent weighting the middle
    /// break was misjudged hard and flipped the whole block to line-structured.
    @Test("Mixed-script wrapped prose still merges")
    func mixedScriptWrappedProseMerges() {
        let lines = [
            OCRParagraphLine(text: "人工智能的发展速度令人惊叹，从大模型到多", minX: 0.039, maxX: 0.957),
            OCRParagraphLine(text: "模态再到智能体，每一年都有新的突破，行", minX: 0.039, maxX: 0.913),
            OCRParagraphLine(text: "业格局也在不断变化，值得持续关注。The", minX: 0.043, maxX: 0.909),
        ]

        #expect(OCRParagraphLineJoiner.join(lines)
            == "人工智能的发展速度令人惊叹，从大模型到多模态再到智能体，每一年都有新的突破，行业格局也在不断变化，值得持续关注。The")
    }

    @Test("Wrapped Latin prose merges with spaces")
    func wrappedLatinProseMerges() {
        let lines = [
            OCRParagraphLine(text: "The quick brown fox jumps over", minX: 0.03, maxX: 0.97),
            OCRParagraphLine(text: "the lazy dog and keeps running", minX: 0.03, maxX: 0.97),
            OCRParagraphLine(text: "until it stops.", minX: 0.03, maxX: 0.50),
        ]

        #expect(OCRParagraphLineJoiner.join(lines)
            == "The quick brown fox jumps over the lazy dog and keeps running until it stops.")
    }

    /// Two prose paragraphs Vision merged into one block: the short line ending
    /// the first paragraph is the only hard break; wraps still merge.
    @Test("Mixed block keeps only the paragraph-boundary break")
    func mixedBlockKeepsParagraphBoundary() {
        let lines = [
            OCRParagraphLine(text: "第一段第一行文字文字文字文字文", minX: 0.03, maxX: 0.97),
            OCRParagraphLine(text: "字第一段结束。", minX: 0.03, maxX: 0.47),
            OCRParagraphLine(text: "第二段第一行文字文字文字文字文", minX: 0.03, maxX: 0.97),
            OCRParagraphLine(text: "字第二段的收尾。", minX: 0.03, maxX: 0.53),
        ]

        #expect(OCRParagraphLineJoiner.join(lines)
            == "第一段第一行文字文字文字文字文字第一段结束。\n第二段第一行文字文字文字文字文字第二段的收尾。")
    }

    @Test("Latin list keeps line breaks, including after its longest line")
    func latinListKeepsBreaks() {
        let lines = [
            OCRParagraphLine(text: "- apples", minX: 0.03, maxX: 0.20),
            OCRParagraphLine(text: "- bananas and pears", minX: 0.03, maxX: 0.45),
            OCRParagraphLine(text: "- oranges", minX: 0.03, maxX: 0.22),
        ]

        #expect(OCRParagraphLineJoiner.join(lines) == "- apples\n- bananas and pears\n- oranges")
    }

    @Test("Single line and empty input pass through")
    func degenerateInputs() {
        #expect(OCRParagraphLineJoiner.join([]) == "")
        #expect(OCRParagraphLineJoiner.join([
            OCRParagraphLine(text: "只有一行", minX: 0.1, maxX: 0.5)
        ]) == "只有一行")
    }

    @Test("Space insertion follows CJK adjacency rule")
    func spaceInsertionRule() {
        #expect(OCRParagraphLineJoiner.shouldInsertSpace(between: "hello", and: "world"))
        #expect(!OCRParagraphLineJoiner.shouldInsertSpace(between: "中文", and: "english"))
        #expect(!OCRParagraphLineJoiner.shouldInsertSpace(between: "english", and: "中文"))
        #expect(!OCRParagraphLineJoiner.shouldInsertSpace(between: "中文", and: "继续"))
    }
}
