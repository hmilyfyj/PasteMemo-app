# PasteMemo

<p align="center">
  <img src="docs/readme-assets/logo.svg" width="128" height="128" alt="PasteMemo Icon">
</p>

<h3 align="center">PasteMemo</h3>

<p align="center">
  <strong>macOS 智能剪贴板管理器</strong><br>
  复制一次，随时访问，即刻粘贴。
</p>

<p align="center">
  <img src="docs/readme-assets/badge-platform.svg" alt="Platform">
  <img src="docs/readme-assets/badge-license.svg" alt="License">
</p>

<p align="center">
  <a href="https://github.com/hmilyfyj/PasteMemo-app/releases/latest">⬇️ 下载</a>
</p>

<p align="center">
  <a href="README_en.md">English</a>
</p>

---

## 截图

<p align="center">
  <img src="docs/paste-sytle-1.png" width="720" alt="PasteMemo 底部悬浮样式">
</p>

<p align="center">
  <img src="docs/paste-sytle-2.png" width="720" alt="PasteMemo 分栏样式">
</p>

<p align="center">
  <img src="docs/readme-assets/main-window.png" width="720" alt="PasteMemo 主窗口">
</p>

<p align="center">
  <img src="docs/readme-assets/quick-paste.png" width="720" alt="PasteMemo 快捷粘贴">
</p>

<p align="center">
  <img src="docs/readme-assets/quick-actions.png" width="720" alt="PasteMemo 快捷操作">
</p>

<p align="center">
  <img src="docs/readme-assets/relay-mode.png" width="720" alt="PasteMemo 接力模式">
</p>



## 亮点功能

- **复制即文件** -- 文本一键粘贴为 `.txt` 文件，截图直接粘贴为图片文件。可拖入访达或任何文件对话框。
- **AI 终端就绪** -- 无缝粘贴图片和文件到 AI 终端。为命令行和 AI 工作流而生的开发者利器。
- **智能识别** -- 自动检测内容类型——链接自动抓取图标、代码片段、颜色值、电话号码、文件路径——并进行智能预览。
- **不止复制粘贴** -- 粘贴路径、粘贴文件名、保存到文件夹、粘贴后自动回车。每条记录都是一把瑞士军刀。

## 功能特色

### 剪贴板管理

- **自动捕获** -- 实时监控系统剪贴板。文本、图片、文件、链接、代码，全部自动保存。
- **内容类型检测** -- 自动分类：文本、链接、图片、代码、颜色、电话号码、文件、文档、压缩包、音频、视频等。
- **丰富预览** -- 链接自动展示网页预览和图标，代码语法高亮，颜色显示色块，电话号码显示操作按钮。
- **OCR 支持** -- 使用内置 OCR 从图片中提取文字。支持中文、英文等多种语言。
- **置顶** -- 常用内容一键置顶，始终在列表最上方。
- **智能分组** -- 创建基于规则的智能分组，自动组织剪贴板内容。
- **搜索** -- 全文搜索所有剪贴板历史，搜索结果高亮显示，瞬间找到任何内容。
- **按类型筛选** -- 按内容类型过滤：文本、链接、图片、代码、颜色、文件等。
- **按应用筛选** -- 查看每条记录来自哪个应用，按来源过滤。
- **历史保留** -- 配置历史保留时长：永久保存，或 1-365 天后自动删除。

### 快捷粘贴面板

- **全局快捷键** -- 在任何应用中按下 Cmd+Shift+V（可自定义，支持 F1-F12）打开快捷粘贴面板。
- **面板样式可切换** -- 可在设置中切换经典分栏面板或新的底部悬浮样式，按你的使用习惯选择。
- **流畅动画** -- 精美的弹簧动画和微交互，带来流畅的使用体验。
- **键盘导航** -- Cmd+1 到 Cmd+9 直接粘贴，方向键导航，回车粘贴，全程键盘操作。
- **快捷操作（Cmd+K）** -- 命令面板，粘贴、复制、置顶、删除等操作一键完成。
- **粘贴+换行** -- Shift+Enter 粘贴后自动回车，终端命令和聊天工具的最佳搭档。

### 接力模式

- **批量粘贴** -- 复制多条内容，按顺序逐条粘贴。适合填表、数据录入等场景。
- **文本拆分** -- 按分隔符（逗号、换行等）拆分文本，快速构建粘贴队列。
- **可视队列** -- 清晰的队列列表，当前条目高亮，进度可追踪。
- **队列管理** -- 重排、编辑、跳过或删除队列中的项目。一键反转整个队列。

### 剪贴板自动化

- **规则引擎** -- 定义条件+动作，自动处理剪贴板内容。
- **自动触发** -- 复制时静默执行规则。例如自动清理 URL 追踪参数。
- **手动触发** -- 通过命令面板或右键菜单应用转换。
- **内置规则** -- 清理 URL 追踪参数、邮箱自动转小写、去除多余空行等。
- **特殊操作** -- 剥离富文本、分配分组、标记为敏感、置顶项目或完全跳过捕获。

### 备份与同步

- **本地备份** -- 自动备份到本地文件夹，可配置保留策略。
- **WebDAV 支持** -- 同步备份到任何 WebDAV 服务器（NAS、云存储等）。
- **多槽位轮转** -- 保留多个备份版本（最多 10 个槽位），自动轮转。
- **加密备份** -- 所有备份均经过加密，确保安全。
- **轻松恢复** -- 从任意备份恢复，支持合并或覆盖选项。

### AI 就绪功能

- **AI 终端粘贴** -- 为 AI 终端和聊天界面优化的粘贴格式。
- **智能格式化** -- 链接转为 Markdown，长文本包裹在引用块中，图片优雅处理。
- **开发者友好** -- 专为 AI 助手、终端命令和代码片段工作流打造。

### 隐私与安全

- **敏感内容检测** -- 自动检测密码和敏感数据，在界面中遮罩显示。
- **忽略应用** -- 排除特定应用（如密码管理器）的剪贴板监控。
- **开源** -- 完整源代码公开，你清楚知道 Mac 上运行的是什么。

### 数据迁移

- **从 Paste.app 导入** -- 无缝迁移 Paste.app 的剪贴板历史。
- **导出与导入** -- 导出数据并在另一台 Mac 上导入。

### 自动更新

- **Sparkle 集成** -- 内置自动更新框架，无缝升级。
- **后台更新** -- 后台下载更新，准备就绪后安装。

### 自定义

- **主题** -- 跟随系统、浅色或深色模式。
- **音效** -- 可自定义的复制和粘贴音效，或完全关闭。
- **动画设置** -- 配置动画速度或完全关闭动画。
- **11 种语言** -- English、简体中文、繁体中文、日本語、한국어、Deutsch、Francais、Espanol、Italiano、Русский、Bahasa Indonesia

## 快捷键

| 快捷键 | 操作 |
|--------|------|
| Cmd+Shift+V（可自定义） | 打开/关闭快捷粘贴面板 |
| Cmd+1 - Cmd+9 | 直接粘贴第 N 条 |
| 上/下方向键 | 浏览历史 |
| 回车 | 粘贴选中项 |
| Shift+回车 | 粘贴并回车 |
| Cmd+K | 打开快捷操作 |
| Cmd+F | 聚焦搜索 |
| Esc | 关闭面板 |

## 系统要求

- macOS 14 (Sonoma) 或更高版本
- Apple Silicon 或 Intel Mac

## 安装

### 下载

从 [Releases](https://github.com/hmilyfyj/PasteMemo-app/releases) 下载最新 `.dmg`：

| 文件 | 架构 |
|------|------|
| `PasteMemo-x.x.x-arm64.dmg` | Apple Silicon (M1/M2/M3/M4) |
| `PasteMemo-x.x.x-x86_64.dmg` | Intel Mac |

> 首次打开时：**右键点击 PasteMemo.app -> 打开 -> 打开**
>
> 或在终端执行：`xattr -cr /Applications/PasteMemo.app`

### 从源码构建

```bash
git clone https://github.com/hmilyfyj/PasteMemo-app.git
cd PasteMemo-app
swift build
```

## 许可协议

本项目基于 [GPL-3.0](LICENSE) 协议开源。

Copyright (c) 2026 lifedever.
