## Goal

FEATURE-727 followup: remove the rounded background and border behind bottom cards without changing scrolling or card geometry.

## Requirements

- Remove the card scroll region's rounded section fill and border in both themes.
- Keep the window shell, cards, spacing, scrolling, keyboard navigation and internal drop behavior.
- Keep section decoration on empty states and expanded preview.

## Acceptance Criteria

- Card rail shows the window shell directly between cards, without a separate rounded track.
- Existing affected tests and make check pass; rebuild/install the stable ARM app.
- Update existing fork PR #28 and reply to triggering comment 01a113f5-ef75-7850-bdd9-da1daff679a5.

## Notes

- User request authorizes implementation and delivery; no repeated planning/start approval is required.
