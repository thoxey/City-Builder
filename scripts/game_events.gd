extends Node

## Pure signal bus. No state, no logic.
## Builder emits here; plugins receive from here.
## Builder never knows plugins exist.

signal structure_placed(position: Vector3i, structure_index: int, orientation: int)
signal structure_demolished(position: Vector3i)
signal map_loaded(map: DataMap)
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
