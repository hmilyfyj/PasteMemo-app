<!-- PROJECT:START -->

# 项目规则

- 这是上游 `lifedever/PasteMemo-app` 的 fork。本地改动推到 `origin`（`hmilyfyj/PasteMemo-app`），不要推给 upstream。
- 定期把上游合并进本地；MR 目标分支是 `main`。
- 业务代码改完后用 `./scripts/rebuild_and_open_stable.sh` 构建并启动本机 ARM 应用。
- 验证入口：`make test`、`make check`。Swift 源码在 `Sources/`，测试在 `Tests/`。
- `sparkle_private_key.pem` 只留在本机，不要提交。

<!-- PROJECT:END -->

<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are for AI assistants working in this project.

This project is managed by Trellis. The working knowledge you need lives under `.trellis/`:

- `.trellis/workflow.md` — development phases, when to create tasks, skill routing
- `.trellis/spec/` — package- and layer-scoped coding guidelines (read before writing code in a given layer)
- `.trellis/workspace/` — per-developer journals and session traces
- `.trellis/tasks/` — active and archived tasks (PRDs, research, jsonl context)

If a Trellis command is available on your platform (e.g. `/trellis:finish-work`, `/trellis:continue`), prefer it over manual steps. Not every platform exposes every command.

If you're using Codex or another agent-capable tool, additional project-scoped helpers may live in:
- `.agents/skills/` — reusable Trellis skills
- `.codex/agents/` — optional custom subagents

Managed by Trellis. Edits outside this block are preserved; edits inside may be overwritten by a future `trellis update`.

<!-- TRELLIS:END -->
