# Directory Structure

> 当前布局以 Swift Package 可执行目标 `PasteMemo` 为准。

## 目录布局

```text
Package.swift                 # Swift 6，macOS 14+，目标 PasteMemo / pastememo-mcp / PasteMemoTests
Sources/
    App/                      # 应用入口、AppDelegate、状态栏、本地化入口
    Bridge/                   # 与系统/辅助功能桥接
    Engine/                   # 剪贴板、热键、OCR、规则、更新器等核心逻辑
    Models/                   # ClipItem、SmartGroup 等模型
    Views/                    # SwiftUI：Main / QuickPanel / Settings / Relay / Automation / Components
    Relay/                    # 跨设备中继
    Localization/             # 本地化资源
    MCPProxy/                 # 独立可执行目标 pastememo-mcp
    Resources/                # Info.plist、图标等资源
Tests/                        # PasteMemoTests，按功能拆文件
scripts/                      # 构建、检查、打包、更新 appcast
Makefile                      # dev / build / test / check / package
```

## 新代码放哪

- 窗口和面板 UI 放 `Sources/Views/` 已有子目录
- 剪贴板读写、热键、OCR、更新逻辑放 `Sources/Engine/`
- 数据模型放 `Sources/Models/`
- 应用生命周期和状态栏放 `Sources/App/`
- 测试与被测类型同名或按功能命名，放 `Tests/`

## 不要做

- 不要在仓库根再铺一套 `src/` 或 Xcode 工程目录；本仓用 SPM
- 不要把 MCP 代码混进主 target；`Package.swift` 已把 `Sources/MCPProxy` 排除出 `PasteMemo`
