## Theme
Extend QuickPanelBottomTheme into a scheme-aware palette, consumed by the existing shell/section modifiers and QuickClipCard. Use semantic foreground/background tokens rather than opaque fixed white/dark colors. Resolve the existing app appearance preference through the established AppKit/SwiftUI path; selected cards keep their source-derived header and use an outline. Preserve square card sizing and lazy rail.

## Motion
One QuickPanelMotion policy owns timings/curves and reduced-motion decisions for SwiftUI/AppKit. Keep launchAnimationEnabled behavior; query live accessibility state when opening and observe it where the persistent views need updates. Selection/navigation must be interruptible and must not animate content reordering. Do not delay dismissAndPaste or change its target/focus logic.

## Reusable groups
Expose SmartGroup.color in the existing editor and carry it through all create/update paths and sidebar/tab count metadata. Internal drags carry item identifiers with a dedicated UTType, distinct from group/type reordering and ordinary external text. Resolve only existing local items, batch update through a shared group service, and no-op same-group assignment. Keep existing drag-to-other-app behavior where present.

Manual ordering is group-scoped and persisted with backwards-compatible optional data; old items get deterministic fallback ordering. Integrate with ClipItemStore SQL pagination so ordering applies before slicing, not only to loaded items. Define stable relative ordering for multi-item moves and additions. Clearing membership clears stale ordering. Add accessible move actions if necessary alongside drag reorder.

## Compatibility and rollback
No history deletion or retention default changes. Reuse existing safe save/notify behavior. New optional model state must auto-migrate an existing local SwiftData store. Document persistence/data transfer contracts and verify round-trip behavior. Code rollback uses normal revert; no resetting user preferences or deleting databases.
