# Visual QA

Normal-renderer proofs were captured on 2026-09-06 using Godot 4.6.2, Metal
Forward+, and the Apple M2 Max GPU. The capture script loaded the real main scene and
used authoritative runtime placement quotes, tutorial/Dashboard projections, and
committed Playtest choices. The manifest records 18 successful captures with no
failures: nine states at both 1280×720 and 1920×1080.

Review outcome:

- An unchanged valid quote hides the location panel and leaves no empty footprint.
- Changed quotes retain only their non-zero semantic change and non-empty supporting
  evidence. Invalid, replacement, and uncertain quotes retain only their actionable
  rows.
- At 1280×720 the compact panel remains readable above the existing dock and clear of
  both Ambrose's guidance and the expanded Dashboard. At 1920×1080 the standard-width
  panel remains clear of both side regions. No row or panel is clipped at either
  resolution. The capture driver records all three rectangles and fails if the panel
  intersects either region or leaves less than its 12-unit authored safe margin.
- The real rooted-town run visibly advances from nine roads to the nature lesson only
  after the tenth Town Hall-rooted road cell.
- The adjacency direction visibly says “another home” and never says “the first house.”
- After the first qualifying rooted shop, the primary direction visibly reads
  “Continue to your first land quest.” and contains no `0/100 fulfilled` line.
- Twelve committed Grass choices in the renderer run produced both planted variants
  and no plain grass. The 100-choice headless evidence independently records exact
  counts and the deterministic selection hash.

Representative proofs: [unchanged 1280×720](screenshots/1280x720-unchanged-hidden.png),
[changed 1280×720](screenshots/1280x720-changed.png),
[replacement 1920×1080](screenshots/1920x1080-replacement.png),
[ten roads 1280×720](screenshots/1280x720-ten-rooted-roads.png),
[adjacency 1920×1080](screenshots/1920x1080-adjacency-another-home.png),
[handoff 1280×720](screenshots/1280x720-first-quest-handoff.png), and
[Grass variants 1920×1080](screenshots/1920x1080-grass-pool-variants.png).
The complete machine-readable record is in
[the capture manifest](screenshots/manifest.json).

No visual blocker remains. The proof run did not add or exercise a feature-019
world-space placement-impact capsule; any other world feedback visible in the shared
dirty worktree belongs to separate existing work.
