# Data Model: Radial Build UI and Player HUD

All structures are read-only presentation projections unless marked transient.

## BuildMenuModel

| Field | Type | Meaning |
|---|---|---|
| revision | int/String | Changes when entry/availability/current selection changes |
| groups | Array[BuildMenuGroup] | Stable, non-empty authored groups |
| entries_by_id | Dictionary | Stable ID to BuildMenuEntry |
| selected_entry_id | String | Current Palette selection or empty |
| empty_state | String? | Player-facing reason when no choices exist |

## BuildMenuGroup

- `id`: stable enum-like key
- `label`: localizable player-facing label
- `icon_key`: category icon
- `order`: deterministic integer
- `entry_ids`: ordered IDs including available and unavailable entries
- `available_count`, `total_count`: display-only summaries

Valid v1 IDs are `roads`, `homes`, `commerce`, `industry`, `nature`, `civic`,
and `landmarks`.

## BuildMenuEntry

- `id`: pool ID or building ID; stable selection key
- `display_name`, `short_label`
- `group_id`, `ui_order`, `icon_key`
- `is_pool`, `member_building_ids`
- `representative_structure_index`: preview only
- `cash_cost`: integer or unavailable
- `demand_cost`: bucket ID/value or unavailable
- `availability`: `available`, `insufficient_cash`, `insufficient_demand`,
  `locked_prerequisite`, `already_built`, `missing_content`, or `no_members`
- `availability_label`: canonical player-facing reason
- `can_select`: true only for `available`

The projection may aggregate pool costs only when all selectable members share
the displayed cost. Otherwise it shows a range or "varies" and member selection
remains authoritative at placement.

## RadialPage (derived)

- `level`: `categories` or `items`
- `group_id`: empty at category level
- `page_index`, `page_count`
- `wedges`: ordered Array[RadialWedge], maximum length eight
- `centre_action`: `close` or `back`
- `origin`, `inner_radius`, `outer_radius`, `safe_rect`

Pagination reserves navigation wedges before allocating item wedges. Every page
is derived deterministically from `entry_ids`; it is never persisted.

## RadialWedge

- `kind`: `group`, `entry`, `next_page`, or `previous_page`
- `target_id`, `label`, `icon_key`
- `start_angle`, `end_angle`
- `enabled`, `state_pattern`, `accessible_description`

## RadialFocusState (transient)

- `is_open`, `input_mode`
- `level`, `group_id`, `page_index`
- `focused_wedge_index`, `last_entry_id_by_group`
- `origin`

State resets on map/session restart and never enters `DataMap` or deterministic
snapshots.

## Catalog UI metadata (authored)

Standalone building:

```json
{"ui_group":"nature","ui_order":20,"ui_icon":"build-duck-pond"}
```

Pool sidecar:

```json
{
  "pool_id":"residential_t1",
  "ui_group":"homes",
  "ui_order":10,
  "ui_icon":"build-house"
}
```

Pool UI metadata is authoritative for its single menu entry. Member metadata is
used only if the member becomes standalone later. Missing/invalid values use a
logged deterministic fallback; duplicate order values tie-break by stable ID.

## UIAssetRecord

- `id`, `label`, `family`, `role`, `motif`
- `source_path`, `source_dimensions`
- runtime path/dimensions and intended display range
- color mode/space, alpha policy, background rule
- palette roles and accessibility label
- approval state

## PlayerHUDState

- top bar: cash, budget delta, attractiveness, output, three demand summaries,
  population/capacity, satisfaction, Community happiness, Inbox badge
- tool dock: `idle|placing|blocked|demolishing`, entry ID/icon/name, cost summary,
  block reason, contextual actions
- safe-area occupancy for top bar, dock, time controls, right drawer, and modal

## State transitions

```text
closed -> categories -> items -> placement
                    \-> items(next/previous page)
items -> categories -> closed
placement -> closed (cancel) | placement (successful repeat)
any radial level -> closed when higher-priority dialogue/confirmation opens
```

Confirmation revalidates `can_select` through Palette before entering placement.

