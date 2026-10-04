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

### 悬浮面板内容尺寸与提示

- `QuickPanelBottomContentGeometry(panelHeight:chromeHeight:mode:)` 根据实测搜索/分类栏高度分配卡片与预览；悬浮没有底栏，chrome 为 header + 双侧8pt padding + 单个4pt间距。紧凑态填满轨道，展开态卡片高度上限220pt，预览吃剩余空间。不要再用整窗高度减固定100pt计算卡片。
- 只测量轻量 header，渲染和最低高度更新仅等待 header > 0；保留 `isBottomRailArmed`，不要让30k卡片在 warm-up 阶段参与布局，也不要给整个轨道增加 GeometryReader 的反馈循环。
- 悬浮卡片始终为正方形，`cardWidth == cardHeight`；宽度跟随轨道派生的卡片高度，不独立限制宽度或套用纵向比例。紧凑和展开模式及瞬时小尺寸均由几何回归覆盖。
- `updateBottomChromeHeight(_:)` 下一轮主线程更新最小窗口高度；`positionBottomFloating` 在程序化模式切换后同步 `layoutState.height`，因为 `didEndLiveResize` 仅响应用户拖拽。`didResize` 中仍只同步宽度，避免 AppKit 布局重入。
- 底部样式：←→选卡片、↑↓切分类、⌘O展开/收起、空搜索且无IME组字时Space预览。预览、展开/收起、快捷操作、快捷键和设置在右上角；快捷说明使用 popover，不占常驻高度，不显示粘贴目标。快捷操作使用直接按钮，两个弹窗入口在另一个弹窗打开时禁用，不从说明 popover 内关闭并立即打开另一 popover，避免旧弹窗的异步关闭误关新弹窗。经典保留底栏及既有键义，共享提示文案按样式分支。
- 悬浮标签栏在类型模式下同时追加全部自定义分组（包含空分组），经典样式仍按类型/分组设置二选一；分组模式仍只显示分组。`showsGroupTabs` 同时用于标签生成与记住上次筛选的校验，键盘导航沿用 `filterItems`，避免可见分组在重开时因类型模式被重置。
- 样式切换只重建窗口，不清尺寸；显式恢复默认才调用 `QuickPanelStyle.resetStoredSizing(in:)`，仅清当前样式的尺寸，保留另一样式及展开模式。
- 用 `QuickPanelBottomGeometryTests` 验证无底栏高度守恒、最小预览空间、不同 header 高度和独立偏好域。新本地化键须在全部11种语言补齐，`LocalizationFilesTests` 强制检查键集合与占位符一致。

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
