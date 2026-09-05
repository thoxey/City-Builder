# Visual QA: First-Patron Progression

**Date**: 2026-09-05  
**Viewport**: 1280 x 720  
**Renderer**: Godot Metal Forward+

## Reviewed frames

| Frame | Progression evidence | Result |
|---|---|---:|
| `first-arrival.png` | Baba Yaga has arrived; the Patron drawer shows current and required gates | Pass |
| `request-revealed.png` | Pirate Radio is the current authored request | Pass |
| `patron-ready.png` | All three contributors are satisfied and the Theatre is ready | Pass |
| `landmark-complete.png` | The Theatre is built and each contributor is shown as complete | Pass |
| `land-expanded.png` | The post-donation town view is reframed to include the expanded buildable area | Pass |

## Inspection notes

- The Patron drawer is visible and readable in every progression frame.
- The drawer, top HUD, time controls, and build dock do not overlap or clip at
  the target viewport.
- Authored names remain stable across the sequence. The next-step copy uses
  natural articles, including `Place The Theatre` and `Build Pirate Radio`.
- The completed frames replace the prior generic growth fallback with the
  canonical terminal message, `First patron complete`.
- Satisfied gates are visually distinguishable from current unmet requirements.
- Placeholder nameplates are suppressed in the capture harness so they do not
  obscure the progression evidence.
- The final screenshot is presentation evidence for the expanded town view; the
  canonical state trace is the authoritative proof that the donation increased
  buildable land from 64 to 256 cells.
- The compact canonical town is a progression stress fixture, not evidence of
  the intended spatial balance. Milestone 006 owns matched compact-versus-spread
  testing and must prove that connected separation can improve resident outcomes
  at a visible road or land-use cost.

All five frames passed visual inspection without blocking layout or copy defects.
