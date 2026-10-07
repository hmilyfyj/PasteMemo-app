1. Inspect existing theme plumbing, main/sidebar group reorder, clip drag/paste, group persistence and backup/export paths. Reuse existing helpers.
2. Implement scheme-aware bottom palette and selection; central motion policy with live reduced motion; group colors, internal drop assignment and persisted item reorder.
3. Add isolated behavior tests for order/count/persistence and motion decisions. Run affected tests first, then make test and make check. Fix regressions without touching unrelated behavior.
4. Review using project trellis-check agent, integrate safe fixes and rerun checks only for new changes. Update app specs for new contracts.
5. Run scripts/rebuild_and_open_stable.sh for ARM installation. Verify appearance/group UI and keyboard navigation/paste/preview using test data where feasible; do not expose user history in attachments.
6. Fetch origin/main before delivery, protect task work if updates exist, commit only task files, archive task and record session. Push to hmilyfyj fork and open PR against main. Deliver one issue reply to the triggering comment with PR, validation and any limitations; in_review after completion.
