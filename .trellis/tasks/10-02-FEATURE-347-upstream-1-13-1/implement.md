# 执行计划

1. 读取项目规范与两侧改动，记录基线；准备独立 checkout。
2. 合并上游稳定 main，逐段处理源码及 CI 发布脚本冲突。
3. 复核悬浮框尺寸、卡片缩放、搜索、Quick Look 按键与焦点；保留 fork 更新渠道与发版守卫。
4. 运行 make test 和 make check，保存本次日志并修复与合并相关的失败。
5. 更新需要沉淀的 fork 合并规范，提交、同步目标分支、推送 fork 并创建 main PR。
6. 按既有合并授权合入 fork main；运行稳定 ARM release 安装脚本，关闭旧版/测试版并验证签名、版本、进程存活。
7. 交付链接与结果，完成 Trellis 记录与 Multica 结果评论。
