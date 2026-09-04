# Community Insight UI visual QA

Date: 2026-09-04  
Reference viewport: 1280×720  
Result: PASS

## Live checks

- Community HUD is visually distinct from legacy Satisfaction and shows supplied population and composite-happiness icons, `People N/capacity`, `Happiness`, a signed recent change, and a focusable Community entry button.
- The HUD sits below the developer strip without overlap. The 380 px right sidebar remains within the viewport and does not overlap the centered HUD.
- Community and Patrons share one tabbed, collapsible Town insights shell.
- Overview, resident detail, place detail, empty, full-capacity, and at-risk states were driven through the live Godot playtest bridge and inspected at native 1280×720 resolution.
- Resident and place content uses one vertical scroll region with focus-following enabled; labels wrap within the sidebar.
- Live keyboard-only navigation passed: focus started on Overview, Tab moved to Residents, and Enter opened the Residents section. Standard Godot focus styling was visible; controls also retain gamepad-compatible UI focus/accept behavior.
- The at-risk capture exposes `Relocation window: 23/24 hours` and `1 hour remaining` before the exact departure boundary.
- The place capture shows ACTIVE schedule state and a summed negative contribution (`−24.7`, two residents), while authored effects remain separate previews.
- All semantic rows retain a text sign, arrow, ACTIVE/INACTIVE state, or WARNING label and do not depend on colour alone.
- Runtime icon references resolve exclusively beneath `res://sprites/community_icons/game/`; source masters and `review/` proofs are not loaded.

## Reviewed screenshots

- `screenshots/overview.png` — overview, mixed drivers, compact HUD, shared shell.
- `screenshots/resident-detail.png` — current/target qualities, personality, sensitivities, and scrollable explanation.
- `screenshots/place-inspection.png` — actual participation/affected counts, schedule and signed contributions.
- `screenshots/empty-state.png` — constructive zero-population explanation.
- `screenshots/full-capacity.png` — 5/5 capacity and migration rejection warning.
- `screenshots/at-risk.png` — hour 23/24 relocation rationale and separate effect sections.

Each capture was asserted by the live test to be one full-resolution 1280×720 frame and was manually reviewed after the final HUD, aggregation, and scroll-position corrections.

## Limitations

- The starter kit's developer/build/time overlays remain visually dense by design; Community surfaces avoid them but do not redesign those unrelated controls.
- The existing project-wide GUT teardown warnings remain outside this feature's scope; exact counts are recorded in `test-results.md`.
