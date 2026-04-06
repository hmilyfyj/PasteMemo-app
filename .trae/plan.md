# 项目升级机制调查报告

## 📋 调查结果

**结论：项目的升级不是基于 Sparkle 框架，而是使用自定义的更新机制。**

## 🔍 详细分析

### 1. 项目类型
- **项目名称**: PasteMemo
- **开发语言**: Swift (SwiftUI)
- **平台**: macOS 14+
- **包管理**: Swift Package Manager (Package.swift)

### 2. 当前更新机制

项目使用自定义的 `UpdateChecker` 类实现自动更新功能：

#### 核心特性：
- ✅ **GitHub Releases API 集成**
  - API 端点: `https://api.github.com/repos/hmilyfyj/PasteMemo-app/releases/latest`
  - 支持版本比较和更新检测

- ✅ **智能缓存机制**
  - 使用 ETag 避免重复请求
  - 缓存 release 信息到 UserDefaults

- ✅ **自动下载和安装**
  - 支持 DMG 和 ZIP 格式
  - 自动挂载 DMG 并提取 .app 文件
  - 自动替换旧版本应用

- ✅ **定期检查**
  - 每 24 小时自动检查一次更新
  - 支持用户手动触发检查

#### 关键文件：
1. **Sources/Engine/UpdateChecker.swift** - 核心更新逻辑
2. **Sources/Views/Main/UpdateDialogView.swift** - 更新对话框 UI

### 3. 为什么搜索到 "sparkle"？

搜索到的 "sparkle" 实际上是：
- SF Symbols 图标名称 `"sparkles"` (用于 UI 显示)
- 位于 `SearchSuggestionManager.swift` 和 `GroupEditorPanel.swift`
- **不是** Sparkle 自动更新框架

### 4. Sparkle vs 当前方案对比

| 特性 | Sparkle | 当前自定义方案 |
|------|---------|---------------|
| 实现复杂度 | 低（成熟框架） | 高（自行维护） |
| 更新源 | Appcast RSS/Atom | GitHub Releases API |
| 安全性 | 内置签名验证 | 需自行实现 |
| 用户体验 | 成熟完善 | 基础功能 |
| 维护成本 | 低 | 高 |
| 自定义能力 | 中等 | 完全可控 |

## 💡 建议

### 如果要迁移到 Sparkle：

**优点**：
- ✅ 更成熟稳定的更新体验
- ✅ 内置安全验证机制
- ✅ 支持增量更新（Delta Updates）
- ✅ 更好的用户界面和交互
- ✅ 社区支持和文档完善

**缺点**：
- ❌ 需要配置 Appcast feed
- ❌ 可能需要调整发布流程
- ❌ 增加外部依赖

### 如果保持当前方案：

**优点**：
- ✅ 完全自主可控
- ✅ 与 GitHub Releases 深度集成
- ✅ 无需额外配置

**缺点**：
- ❌ 需要自行维护和测试
- ❌ 缺少签名验证等安全机制
- ❌ 功能相对基础

## 🎯 推荐方案

基于项目现状，建议：

1. **短期**：保持当前方案，但增加以下改进：
   - 添加代码签名验证
   - 改进错误处理和用户提示
   - 添加更新回滚机制

2. **长期**：考虑迁移到 Sparkle：
   - 更专业的更新体验
   - 更好的安全性和可靠性
   - 减少维护负担

## 📝 相关代码位置

- 更新检查器: [Sources/Engine/UpdateChecker.swift](file:///Users/fengit/workspace/PasteMemo-app/Sources/Engine/UpdateChecker.swift)
- 更新对话框: [Sources/Views/Main/UpdateDialogView.swift](file:///Users/fengit/workspace/PasteMemo-app/Sources/Views/Main/UpdateDialogView.swift)
- 包配置: [Package.swift](file:///Users/fengit/workspace/PasteMemo-app/Package.swift)
