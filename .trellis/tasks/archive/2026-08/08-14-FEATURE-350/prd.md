# FEATURE-350 接入 Trellis 并配置 Claude/Codex/Pi/Trae

## 目标

在 fork 仓 `hmilyfyj/PasteMemo-app` 初始化 Trellis 0.6.14，平台集合与镖局 `saas-backend-node` 一致：Claude Code、Codex、Pi Agent、Trae。后续开发可以按 `.trellis/workflow.md` 建 task、写规划产物、再改代码。

## 背景 / 已知事实

- 主仓 `/Users/fengit/workspace/tools/PasteMemo-app` 与 worktree `FEATURE-347` 原先都没有 `.trellis/`。
- 镖局 node 仓已跟踪的 Trellis 平台目录：`.claude/`、`.codex/`、`.pi/`、`.trae/`、`.agents/`、`AGENTS.md`。`trellis init` 对应开关是 `--claude --codex --pi --trae`。
- 本仓是 Swift 6 SPM 的 macOS 14+ 剪贴板应用，入口在 `Package.swift`；源码在 `Sources/{App,Bridge,Engine,Models,Views,Relay,Localization,MCPProxy,Resources}`，测试在 `Tests/`。
- 远端主干是 `origin/main`（当前 `ae25117`），没有 `origin/develop`。origin 是 fork `https://github.com/hmilyfyj/PasteMemo-app.git`。项目约定：定期合并上游，不向 upstream 推代码。
- 本机开发构建脚本是 `scripts/rebuild_and_open.sh` / `scripts/rebuild_and_open_stable.sh`；质量入口是 `make test` 与 `make check`。
- 默认 `trellis init` 会生成 frontend/backend 占位 spec。本仓没有 React/Node 分层，需要补一份基于现有目录的 `spec/app`，避免后续 agent 按 Web 模板写代码。

## 需求要点

1. 在 `origin/main` 新建 worktree，执行 `trellis init --claude --codex --pi --trae --no-monorepo -u fengit`。
2. `trellis platforms` 能列出 claude-code、codex、pi、trae。
3. `AGENTS.md` 保留 Trellis 管理块，并在 `PROJECT` 块写上本仓规则：构建脚本、fork 合并方向、本地 ARM 安装。
4. 根目录 `.gitignore` 忽略 `.claude/settings.local.json`（与镖局 node 一致）。
5. 新增 `.trellis/spec/app/`，记录已验证的目录、验证命令、fork 约定；frontend/backend 占位 index 指向 `spec/app`。
6. 提交到 `feature/FEATURE-350-trellis`，对 `origin/main` 开 PR。不推 upstream。

## 范围外

- 不改 Swift 业务代码，不跑应用重装。
- 不把镖局 node 的 frontend/GraphQL spec 复制过来。
- 不推送到 `lifedever/PasteMemo-app`。
- 不在本任务填完所有 frontend/backend 占位文件正文。

## 验收标准

- [x] worktree 根目录存在 `.trellis/`，版本文件为 `0.6.14`
- [x] `trellis platforms --json` 含 `claude-code`、`codex`、`pi`、`trae`
- [x] 存在 `.claude/`、`.codex/`、`.pi/`、`.trae/`、`.agents/skills/`
- [x] `AGENTS.md` 同时有 `PROJECT` 块和 `TRELLIS` 块
- [x] `.gitignore` 含 `.claude/settings.local.json`
- [x] `.trellis/spec/app/index.md` 存在，且能指出 `Sources/`、`Tests/`、`make test`、`make check`
- [x] `git diff --check` 通过
- [x] 已向 `hmilyfyj/PasteMemo-app` 的 `main` 开 PR
