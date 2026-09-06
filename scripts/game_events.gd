extends Node

## Pure signal bus. No state, no logic.
## Builder emits here; plugins receive from here.
## Builder never knows plugins exist.

signal structure_placed(position: Vector3i, structure_index: int, orientation: int)
signal structure_demolished(position: Vector3i)
signal map_loaded(map: DataMap)
## Canonical post-commit invalidation boundary for hourly, building and map mutations.
signal authoritative_change_committed(change_set: Variant)
signal satisfaction_changed(score: float)
## Bucket signals — alphabetised so file-walk order matches editor display.
## fulfilled = current placed capacity; total = ever-asked-for; unserved = total - fulfilled.
signal demand_fulfilled_changed(bucket_type_id: String, value: float)
signal demand_total_changed(bucket_type_id: String, value: float)
signal demand_unserved_changed(bucket_type_id: String, value: float)
## Cash surplus changed — `amount` is the new total, `delta` is the signed change.
signal cash_changed(amount: int, delta: int)
## Palette's affordable-entry set or selection has changed.
## `entry_ids` is the ordered list of currently affordable entry ids;
## `selected_id` is the currently active entry (or "" if none affordable).
signal palette_changed(entry_ids: Array, selected_id: String)
## Palette's detached presentation projection changed. Consumers fetch it by
## calling get_build_menu_model(); only the monotonically increasing revision
## crosses the event bus.
signal build_menu_model_changed(revision: int)
## Presentation-only mode change used by PlayerUI/Builder coordination.
signal player_input_mode_changed(mode: String)
signal placement_context_changed(context: Dictionary)

## One-shot gameplay handoff emitted after the opening tutorial's durable
## completion receipt has been written.  Narrative acknowledgement is separate.
signal tutorial_opening_completed(payload: Dictionary)

## A unique building has just been placed on the map.
signal unique_placed(building_id: String)
## A unique building has just been demolished; its slot is open again.
signal unique_removed(building_id: String)
## A unique crossed the threshold+prereq checks and is now available to build.
signal unique_unlocked(building_id: String)

## Character questline signals. The event system (Phase 8) listens to these
## and decides whether each emits a dialogue modal, a newspaper item, a toast,
## or nothing. The UI layer never listens to these directly.
signal character_arrived(character_id: String)
signal character_want_revealed(character_id: String)
signal character_satisfied(character_id: String)
signal character_state_changed(character_id: String, new_state: int)

## Patron questline signals — emitted by PatronSystem.
signal patron_landmark_ready(patron_id: String)
signal patron_landmark_completed(patron_id: String)
signal patron_state_changed(patron_id: String, new_state: int)

## BuildableArea expansion — carries the newly added cells so the UI / overlay
## can tween them into the allowed set without diffing.
signal buildable_area_expanded(new_cells: Array)

## Per-tile attractiveness changed (placement / demolition / area expansion).
signal tile_attractiveness_changed(pos: Vector2i, score: int)
## City-wide attractiveness sum changed. Trigger source for quest events that
## want to fire when total city attractiveness crosses a threshold.
signal city_attractiveness_changed(value: int)

## Persistent community simulation signals.
signal community_population_changed(population: int, capacity: int)
signal community_qualities_changed(averages: Dictionary)
signal community_resident_arrived(resident_id: int, home_anchor: Vector2i)
signal community_resident_departed(resident_id: int, reason: String)
signal community_resident_rehomed(resident_id: int, home_anchor: Vector2i)
signal community_programme_changed(anchor: Vector2i, programme_id: String)

## Presentation events. They carry intent/selection only; Community remains the
## sole authority for simulation and programme state.
signal community_ui_requested
signal community_ui_refresh_requested(reason: String)
signal community_inspect_mode_changed(active: bool)
signal community_place_selected(anchor: Vector2i)
signal community_notification(kind: String, resident_id: int, message: String)
