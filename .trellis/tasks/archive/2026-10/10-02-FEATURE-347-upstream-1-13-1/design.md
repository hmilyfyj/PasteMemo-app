# 合并设计

从 fork 最新 origin/main 的独立任务 checkout 做保留历史的 merge，来源固定为上游稳定 697236d。不重新铺上游基线，以免再次丢失本地悬浮框优化。

冲突逐段对照共同基线和两侧差异，保留 fork 的底部面板路径与 Sparkle 初始化，同时纳入上游经典面板、预览、设置、AI 和验证码等新增行为。重点复核无文本冲突但共同修改的 Quick Look 和窗口控制逻辑。

宿主旧仓不切分支、不 stash、不修改。上游 remote 禁用推送。PR 指向 fork main，按既有授权合并，再构建安装签名 ARM release。回滚由 fork merge revert 和重装旧版实现，不重写共享历史。
