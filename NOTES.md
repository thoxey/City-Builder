# Random Ideas

A scratchpad for game ideas, visual references, and things to explore later.

## Ideas

- Use large capital letters as world-space icons for character quests, similar to the mission markers in *Grand Theft Auto*. Each letter could represent the character who starts the quest.

## Playtest notes — 2026-09-05

- Fresh play should start on an empty plot and immediately put the free Town
  Hall on the cursor; do not silently load the old four-building Slot 1 town.
- `B` and right-click should be the same contextual back action: placement →
  previous item radial, item radial → categories, categories → close.
- Right-click can no longer rotate while it is the build/back action. Use `Z`
  for building rotation; retain middle-drag for camera rotation.
- Keep building nameplates off by default.
- Make the 1080p window predictable on a 4K/Retina display and increase HUD,
  radial, and dock text/icon sizes.
- Keep the radial centre control visible on hover.
- Show buildable-land boundaries and effect radii while previewing placement.
- After placement, float each affected quality icon with an up/down direction
  icon so the consequence is immediately legible.
- Nearby buildings of the same commercial type should be a strong
  attractiveness penalty, shown during placement.
- Rebalance toward many more homes per workplace/shop. One ordinary shop should
  serve the opening cluster rather than starting with credit for five shops.
- Housing construction and migration must agree: at high occupancy, the player
  should always earn enough Homes demand for the next ordinary house.
- Replace the ambiguous “Strongest drivers” presentation with explicit current
  happiness effects and distinguish historical migration events from current
  housing availability.
- Make the buildable area visibly distinct from unavailable land.

### Generic TODO — road tool

- The road tool is mechanically functional but not enjoyable to use. Treat road
  drawing feel as a separate interaction-design pass: continuous strokes,
  corner correction, previews, undo/error recovery, and clearer connection
  feedback. Do not fold that work into the current town-loop balance pass.

## Playtest notes — 2026-09-06

### First tutorial flow

1. Make “Place the Town Hall” the first guidance message.
2. After the Town Hall is placed, tell the player to place a road.
3. Once the player has placed some road, ask them to place a couple of different
   nature items to restore town Beauty to a positive value.
4. This should generate some Homes demand. Prompt the player to place early
   housing, such as houses or a tower block.
5. Explain that homes should not be placed directly beside one another if the
   player wants the best quality, and encourage adding decoration.
6. Introduce industry as somewhere for residents to work. Explain that it should
   be kept away from homes.
7. Explain that residents now work and earn money, then introduce a shop. Its
   location should demonstrate a trade-off: close to homes is convenient, while
   distance can protect residential quality.
8. After the first shop is placed, introduce the first full-dialogue quest.

Keep this opening tutorial focused and polished before expanding the later
tutorial.

### First quest and townspeople

- The first quest begins after the first shop is placed. Mr Ambrose explains
  that the town needs more land and thinks the player may be able to persuade
  Sir William to give up some of his.
- Consider staging this as a scene at Sir William's house, with the relevant
  characters already present and acquainted. Sir William needs one or more
  associated buildings or a clear residence for the scene.
- Use minor townspeople to make planning trade-offs personal. For example, a
  resident might complain that a shop is too far away to walk to, while another
  might object to its effects when it is nearby.
- Explore four recurring personality/archetype viewpoints, each primarily
  representing one community value: Opportunity, Livability, Beauty, or
  Belonging. Different personalities should prefer different planning choices.

### Opening pacing and demand balance

- The early game has too much idle waiting while demand accumulates, especially
  on the path to unlocking the post-war mid-block at 75 lifetime Homes demand.
- Try an explicit introductory boost during roughly the first five minutes so
  Homes, Work, and Shops demand build more quickly. Reassess after playtesting
  whether the boost should affect all demand equally.
- The aim is to get the player through the sparse opening more quickly; normal
  pacing may become appropriate once the town is larger and there are more
  simultaneous activities.

### UI and feedback

- When Ambrose mentions Opportunity, Livability, Beauty, or Belonging in
  dialogue, show the corresponding icon beside the keyword.
- Demand hover details should include the lifetime total as well as the current
  amount. Apply this consistently to Homes, Work, and Shops demand so unlock
  requirements such as “75 total Homes demand ever” can be understood and
  tracked.
- Make the quality icons that rise from affected buildings after placement more
  readable. Fade the first portion relatively quickly, then ease into a much
  slower taper so the icons linger before disappearing.
- Show a building's known effects while it is held for placement. For example,
  a house preview should communicate its Homes-demand cost and its Beauty,
  Livability, Opportunity, and Belonging effects using icons and signed values.

### Larger feature — live placement consequences

- As the player moves a held building around the map, calculate and preview the
  consequences as though it were placed on the current tile. Live-update the
  demand costs, community-value changes, affected buildings, bonuses, and
  penalties so the player can compare locations before committing.
- This is a substantial feature and should be scoped separately from the
  smaller tutorial and feedback improvements above.
