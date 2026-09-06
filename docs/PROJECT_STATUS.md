# Project status

Status snapshot: 6 September 2026.

This page is the concise roadmap index for the current repository. Individual
`spec.md` headlines preserve the state in which some workstreams were
written and can lag behind their checked task lists and validation evidence.
“Complete” below means the workstream's tracked implementation and verification
tasks are checked; it does not mean the whole game is release-ready.

## Playable now

The current project opens into a fresh-town tutorial and supports the complete
core construction loop: Town Hall placement, rooted roads, buildable land,
homes, workplaces, shops, nature, economy/demand progression, residents,
traffic, character/patron progression, dialogue, and live placement feedback.

The test and playtest foundations cover deterministic simulation,
progression/save round trips, performance timing, dialogue, tutorial state, and
the player UI. Remaining work is concentrated in explicit human/renderer gates,
release-grade save UX, final narrative content, and planned world presentation.

## Workstream index

| Spec | State | Task evidence and remaining work |
| --- | --- | --- |
| [001 Gameplay Playtest MCP](../specs/001-gameplay-playtest-mcp/spec.md) | Partial | 72/75 tasks checked. Controlled balance comparison, milestone screenshots, and frozen baseline protocol remain. The MCP transport is optional local tooling. |
| [002 Community Happiness Simulation](../specs/002-community-happiness-simulation/spec.md) | Complete | 72/72 tasks checked. |
| [003 Community Insight UI](../specs/003-community-ui/spec.md) | Complete | 44/44 tasks checked. |
| [004 Radial Build UI and Player HUD](../specs/004-radial-build-ui/spec.md) | Complete | 54/54 tasks checked. |
| [005 Reachable First-Patron Progression](../specs/005-reachable-first-patron/spec.md) | Complete | 53/53 tasks checked, including deterministic and save/load boundary evidence. |
| [006 Connected First-Town Loop](../specs/006-connected-first-town-loop/spec.md) | Partial | 58/65 tasks checked. The baseline trace, external player cohorts, blind visual review, durability sessions, and final release decision remain. |
| [007 Save Continuity and Desktop Release](../specs/007-save-lifecycle-release/spec.md) | Planned | Draft specification only; no task plan or release implementation is claimed. |
| [008 Coherent Civilian Simulation](../specs/008-civilian-simulation-coherence/spec.md) | Partial | 69/70 tasks checked. One normal-renderer full-day observation remains. |
| [009 Performance and Regression Foundation](../specs/009-performance-foundation/spec.md) | Complete | 32/32 tasks checked. |
| [010 Traffic Flow Coherence](../specs/010-traffic-flow-coherence/spec.md) | Partial | 36/37 tasks checked. The 1920×1080 normal-renderer observation remains open. |
| [011 Quest Dialogue Foundation](../specs/011-quest-dialogue-foundation/spec.md) | Complete | 48/48 tasks checked. |
| [012 First Tutorial Mini-Quest](../specs/012-first-tutorial-mini-quest/spec.md) | Complete with placeholder copy | 37/37 tasks checked. Mechanics and automated verification are complete; visible `AMBROSE PLACEHOLDER` lines still await final prose and play-feel approval. |
| [013 Buildable Area and Community Quality Pass](../specs/013-buildable-community-pass/spec.md) | Complete | 19/19 tasks checked. |
| [014 Automated Opening Balance Playtest](../specs/014-opening-balance-playtest/spec.md) | Complete | 14/14 tasks checked. |
| [015 Transactional Performance Architecture](../specs/015-transactional-performance/spec.md) | Complete | 96/96 tasks checked. The spec headline is historical; implementation and verification tasks are complete. |
| [016 First Land Quest and Townspeople](../specs/016-first-land-quest-townspeople/spec.md) | Paused | 4/46 tasks checked. Planning and baseline work are done; implementation is deliberately blocked on the collaborative creative approvals in Phase 2. |
| [017 UI and Feedback Improvements](../specs/017-ui-feedback-improvements/spec.md) | Complete | 19/19 tasks checked. |
| [018 Live Placement Consequences](../specs/018-live-placement-consequences/spec.md) | Complete | 15/15 tasks checked. |
| [019 Opening Playtest Polish](../specs/019-opening-playtest-polish/spec.md) | Complete | 27/27 tasks checked. |
| [020 Building Ground Contact](../specs/020-building-ground-contact/spec.md) | Complete | 29/29 tasks checked. The spec headline is historical; implementation and release evidence are present. |
| [021 Emotive World Reactions](../specs/021-emotive-world-reactions/spec.md) | Planned | 0/53 tasks checked. The feature is fully specified but not implemented. |

## What “prototype” still means

- The opening sequence intentionally exposes labelled placeholder dialogue.
- Save/load internals and regression coverage exist, but the player-facing save
  lifecycle and desktop-release workstream is not complete.
- The first land quest, its final player/Ambrose identity policy, and the
  expanded townsperson cast await creative approval.
- Several normal-renderer and human-playtest acceptance gates remain open even
  where the corresponding automated suite is complete.
- Emotive world reactions are planned only; screenshots or concepts in that
  workstream are not evidence of runtime implementation.

Use [the development guide](DEVELOPMENT.md) for current verification commands.
For a workstream's normative requirements and detailed evidence, follow its
spec, task list, and `validation/` directory.
