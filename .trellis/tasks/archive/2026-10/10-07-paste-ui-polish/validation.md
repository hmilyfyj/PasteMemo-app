# Validation

Baseline: origin/main fefc4c767a8c3f6644a6a660cdb0df28ca39b22a. Final fetch confirmed origin/main is an ancestor of HEAD.

- Targeted group/motion/temporary visual fixture: 16 tests passed, exit 0.
- `make test`: 463 tests in 42 suites passed, exit 0.
- `make check`: shell syntax, all localization files and Swift build passed, exit 0.
- `git diff --check`: passed.
- Temporary visual capture rendered actual card/palette components with synthetic text, link, document and image content in light and dark modes. Both images reviewed; readable headers and image footers, source colors retained. Fixture removed before commit.
- `./scripts/rebuild_and_open_stable.sh`: passed; ARM64 application installed and signed at the stable app location. Existing SwiftData store migrated from no ZGROUPSORTORDER column to the new optional column, retaining all 38,403 records. Only schema/count metadata inspected.
- Independent validation bundle seeded with three synthetic clips and two colored groups, clipboard monitoring disabled. Startup stopped in the existing accessibility permission NSAlert; AX tools exposed no usable window. Pointer dragging, interactive color save/reload, live preference switching, keyboard navigation/preview/paste and focus restoration could not be completed in this session. No successful native interaction is claimed. Temporary fixture and validation process removed; stable installation retained.

Behavior tests cover membership/counts/retention, stable selection moves, configured on-disk SQL store, ordering before >50-item pagination, reopen and timestamp independence, newest-history probe, unranked fallback, group deletion, automation moves, duplicate capture, undo rank, export/streaming backup and legacy payload compatibility, private drag payloads, motion preferences, actual window animation cancellation and header contrast.

Final read-only review confirmed earlier undo/newest-history findings fixed and found no remaining concrete data-loss/count/drag-code blocker. Automation's per-item unranked fallback is retained explicitly; stable multi-item append order applies to manual UI assignment/reorder.

Logs and safe theme PNGs are retained in the Multica task workdir; only theme PNGs are attached to the issue result. User clipboard contents and signing keys are excluded.
