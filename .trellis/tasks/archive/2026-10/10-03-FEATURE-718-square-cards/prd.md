悬浮卡片改为正方形，紧凑和展开模式均保持宽高相等，跟随现有卡片高度变化。保留原有卡片内容、预览和经典面板布局。

修改范围：QuickPanelBottomContentGeometry 的宽度派生规则；几何测试覆盖两种模式和不同高度；同步悬浮布局规范。通过 make test、make check，签名安装本机 ARM 版并验证正方形卡片，然后更新并合并 fork 的 PR #26 到 main。
