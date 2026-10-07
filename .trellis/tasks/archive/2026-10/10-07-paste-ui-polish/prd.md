# Paste-inspired themes, motion and reusable groups

## Goal
Make PasteMemo's bottom panel clearer in either appearance and consistent to navigate; make reusable groups easy to recognize and maintain.

## Authorization and background
FEATURE-727 research proposed light/dark themes, consistent motion, and colored reusable groups with drop assignment and item ordering. The user approved these three items in comment 01a113d1-b620-76f0-8ec4-3bca5410c4c7: “先做：浅深色主题；统一动效；完善常用分组”. Runtime instructions authorize necessary planning, implementation, verification and delivery without repeated start/task approval. Baseline origin/main fefc4c7. Existing theme choice, permanent group retention, keyboard navigation and paste routes must keep working.

## Requirements
1. Bottom shell, sections, cards and controls respect the existing system/light/dark choice; text, selected and hover states remain readable. Preserve source colors on selection; avoid a parallel preference.
2. Centralize quick-panel and related command-palette motion. Keep high-frequency navigation immediate or subtle, preserve the existing launch animation toggle, and respect live system reduced-motion changes. Paste/focus restoration must remain immediate and reliable.
3. Add group color selection to create/edit flows and show colors in main sidebar and quick-panel tabs. Reuse existing name/icon/retention controls.
4. Support assigning internal clipboard items to groups through drag/drop and stable manual item ordering within groups. Persist order across app reopening and pasting. Group assignment, moves and removals preserve correct counts, retention semantics, and existing ungrouped-history ordering. Reuse existing group-list ordering where available. Automation retains its per-item metadata behavior: cross-group moves clear stale ranks and use history fallback until manual ordering, while existing ranked members keep their positions.
5. Preserve multi-select, double-click paste, context menu selection, space preview, classic layout and bottom geometry. New strings appear in every supported language.

## Acceptance criteria
- Light/dark/system switching updates bottom UI with readable previews, controls and unchanged source identity colors.
- Reduced motion avoids movement; launching and repeated keyboard navigation/paste do not leave stale frames or focus.
- A new or edited group saves its color and shows it in both windows after reload.
- Drop an item/selection into a group; move it between groups; remove it: membership and counts remain consistent without dropping content.
- Reorder group items, reopen and paste: manual order remains. History outside the group retains its existing chronology.
- Meaningful tests cover persistence/order/counts and applicable motion behavior; make test and make check pass. The ARM app is rebuilt and installed using the stable script, and UI checks are recorded.

## Out of scope
Cross-device sync, shared boards, intelligent recommendations, multi-filter search, independent item names, compact-card redesign and unrelated performance work.
