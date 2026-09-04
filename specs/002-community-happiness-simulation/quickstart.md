# Community Simulation Quickstart

## Run the game

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

The Dashboard now shows persistent population/capacity, Opportunity,
Liveability, Beauty, and Belonging, followed by the strongest current positive
and negative community effects. Identity, Freedom, and Care remain resident
interpretation weights and are not rendered as happiness bars.

## Author an effect

Add a `CommunityEffectProfile` inside a building JSON `profiles` array:

```json
{
  "type": "CommunityEffectProfile",
  "effects": [
    {
      "effect_id": "late_music_noise",
      "quality": "liveability",
      "manifestation": "neutral",
      "amount": -12.0,
      "scope": "local",
      "radius": 2,
      "schedule": {"start": 21, "end": 4},
      "sensitivity": "noise",
      "stacking_group": "night_noise",
      "reason": "Late music disturbed sleep"
    }
  ]
}
```

Valid qualities are `opportunity`, `liveability`, `beauty`, and `belonging`.
Valid manifestations are `identity`, `freedom`, `care`, and `neutral`. Valid
scopes are `local`, `participant`, `resident`, and `city`.

## Run verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path . \
  --log-file /tmp/city-builder-gut.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit \
  -ginclude_subdirs \
  -gexit
```

From `server/`:

```bash
npm run build
npm test -- --run
```

## Playtest snapshots

Start any authored scenario with the existing `playtest_start` tool, then use
`playtest_get_state`. Full snapshots include `community.residents`; compact
snapshots omit that array while retaining population, capacity, average
qualities, composition, migration counters, and effect summaries. No additional
MCP tools are introduced.

Deterministic scenario definitions live in `test/scenarios/community_*.json`.
Use identical scenario IDs, seeds, building actions, programme selections, and
hour counts when comparing balance changes.
