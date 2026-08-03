import Foundation
import Testing

/// .strings 是运行时才解析的数据文件，语法错误（引号不配对等）没有编译期防线：
/// 一个坏引号会让整个语言文件解析失败、该语言全部静默回退英文，构建照常成功。
/// （TaskTick 的德语文件曾因一个 ASCII 收尾引号整体失效近两个月。）
@Suite("Localization files")
struct LocalizationFilesTests {
    /// Tests/ → 仓库根 → Sources/Localization
    private static let localizationDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // Tests/
        .deletingLastPathComponent()   // repo root
        .appendingPathComponent("Sources/Localization")

    private static func lprojDirs() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: localizationDir, includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "lproj" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func strings(for lproj: URL) throws -> [String: String] {
        let file = lproj.appendingPathComponent("Localizable.strings")
        let dict = try #require(
            NSDictionary(contentsOf: file) as? [String: String],
            "\(lproj.lastPathComponent)/Localizable.strings 解析失败——检查引号/分号"
        )
        return dict
    }

    @Test("所有语言的 Localizable.strings 都能被 Foundation 解析")
    func allFilesParse() throws {
        let dirs = try Self.lprojDirs()
        #expect(dirs.count >= 11, "语言目录数异常：\(dirs.count)")
        for dir in dirs {
            let dict = try Self.strings(for: dir)
            #expect(!dict.isEmpty, "\(dir.lastPathComponent) 解析结果为空")
        }
    }

    @Test("所有语言的 key 集合与 en 完全一致")
    func keySetsMatchEnglish() throws {
        let en = try Self.strings(
            for: Self.localizationDir.appendingPathComponent("en.lproj")
        )
        let enKeys = Set(en.keys)
        for dir in try Self.lprojDirs() where dir.lastPathComponent != "en.lproj" {
            let keys = Set(try Self.strings(for: dir).keys)
            let missing = enKeys.subtracting(keys).sorted()
            let extra = keys.subtracting(enKeys).sorted()
            #expect(missing.isEmpty, "\(dir.lastPathComponent) 缺少 key：\(missing)")
            #expect(extra.isEmpty, "\(dir.lastPathComponent) 多出 key：\(extra)")
        }
    }

    @Test("格式化占位符与 en 一致（%d/%@ 数量与类型）")
    func formatPlaceholdersMatchEnglish() throws {
        func placeholders(_ s: String) -> [String] {
            var result: [String] = []
            var iter = s.makeIterator()
            while let c = iter.next() {
                guard c == "%" else { continue }
                if let next = iter.next(), next != "%" {
                    result.append("%\(next)")
                }
            }
            return result.sorted()
        }
        let en = try Self.strings(
            for: Self.localizationDir.appendingPathComponent("en.lproj")
        )
        for dir in try Self.lprojDirs() where dir.lastPathComponent != "en.lproj" {
            let dict = try Self.strings(for: dir)
            for (key, enValue) in en {
                guard let value = dict[key] else { continue }
                #expect(
                    placeholders(value) == placeholders(enValue),
                    "\(dir.lastPathComponent) 的 \(key) 占位符与 en 不一致：\(value) vs \(enValue)"
                )
            }
        }
    }
}
