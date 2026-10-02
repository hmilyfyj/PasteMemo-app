# Fork and Release

> 本仓是上游的 fork，本地改进定期合入，不回推上游。

## 远端

- `origin`：`https://github.com/hmilyfyj/PasteMemo-app.git`，日常推送和 PR 都走这里
- 上游仓库：`lifedever/PasteMemo-app`。可以 fetch / merge，不要 `push` 到 upstream
- 主干分支：`main`。没有 `develop`

## 合并上游

1. fetch 上游 tag 或 `main` / `develop`
2. 在 fork 的 feature 分支上合并，保留 fork 自己的更新器和其他本地改动
3. PR 开向 `origin/main`

FEATURE-347 已经按这条路径合过 `upstream v1.8.0`。

### 保留本地面板定制

上游经典面板与 fork 底部悬浮共用 QuickPanelView，不能只检查文本冲突：

- 上游列表命令菜单浮窗依赖行锚点；底部卡片保留自己的 popover，`syncCommandPalettePanel()` 必须排除底部样式。
- 图片网格键盘分支只供经典面板使用，`isImageGridActive` 必须包含 `!isBottomFloating`，否则底部图片卡片会吞掉空格/方向键。
- 上游原生右键菜单升级后，卡片使用 `nativeContextMenuMonitor` 与已有 `onRightClick` 选择处理；覆盖层版 `nativeContextMenu` 会吞掉卡片的双击/多选手势。
- Quick Look 合并时保留 fork 的 `closePreview`、按键监听与面板焦点恢复，同时使用上游纯判断的 `previewRoute` / `canOpenInPreviewApp`。

验收包含底部空格开/关预览、左右切卡片、右键先选中、双击粘贴，以及经典面板新增功能；保留不重写历史的 merge，使后续有明确共同基线。

### Swift 6.3 测试资源布局

Swift Testing 由工具链 `swiftpm-testing-helper` 承载，`Bundle.main` 指向工具链目录。资源查找须同时覆盖代码所在 bundle 的相邻目录（`Bundle(for: PasteMemoResourceBundleAnchor.self).bundleURL.deletingLastPathComponent()`），不能只依赖主进程 executableURL。

签名 app 仍从 `Contents/Resources` 查找；不要无条件回退到生成的 `Bundle.module`，否则搬走构建目录后正式 app 会再次 SIGTRAP。通过 `ResourceBundleTests` 验证测试进程可加载英语本地化资源，通过本机签名安装验证 app 布局。

## Sparkle

- 公钥：`sparkle_public_key.txt`（可提交）
- 私钥：`sparkle_private_key.pem`（已在 `.gitignore`）
- 更新说明见 `SPARKLE_INTEGRATION.md`、`SPARKLE_KEYS.md`、`RELEASE_PROCESS.md`
- `appcast.xml` 随发版更新

## 本机安装

构建好的 arm 应用装到本机。日常开发用 `./scripts/rebuild_and_open_stable.sh`。
