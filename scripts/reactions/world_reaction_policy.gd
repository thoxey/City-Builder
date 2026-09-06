class_name WorldReactionPolicy
extends RefCounted

## Pure, deterministic selection policy for short-lived world reactions.
##
## This deliberately owns no simulation state and creates no scene nodes. A future
## presenter can feed it semantic candidates derived from Community, People,
## CarManager, and building projections, then render only the selected records.

const DEFAULT_VISIBLE_CAP := 5
const DEFAULT_MIN_SPACING := 1.35
const CRITICAL_PRIORITY := 90


static func choose(candidates: Array, active_targets: Dictionary = {},
		cooldown_until: Dictionary = {}, now_seconds: float = 0.0,
		visible_cap: int = DEFAULT_VISIBLE_CAP,
		min_spacing: float = DEFAULT_MIN_SPACING) -> Array:
	var ordered: Array = []
	for raw in candidates:
		if raw is not Dictionary:
			continue
		var candidate: Dictionary = raw
		if not _is_valid(candidate):
			continue
		ordered.append(candidate.duplicate(true))
	ordered.sort_custom(_candidate_before)

	var selected: Array = []
	var claimed_targets := active_targets.duplicate()
	for candidate: Dictionary in ordered:
		if selected.size() >= maxi(0, visible_cap):
			break
		var target_key := String(candidate["target_key"])
		if bool(claimed_targets.get(target_key, false)):
			continue
		if float(cooldown_until.get(target_key, 0.0)) > now_seconds:
			continue
		if int(candidate["priority"]) < CRITICAL_PRIORITY \
				and _too_close(candidate, selected, min_spacing):
			continue
		selected.append(candidate)
		claimed_targets[target_key] = true
	return selected


static func ambient_candidate(world_seed: int, target_kind: String,
		target_id: String, time_bucket: int, expression: String,
		world_position: Vector3, chance_per_thousand: int = 20) -> Dictionary:
	var bounded_chance := clampi(chance_per_thousand, 0, 1000)
	var roll := _stable_roll(world_seed, target_kind, target_id, time_bucket)
	if roll >= bounded_chance:
		return {}
	return {
		"target_key": "%s:%s" % [target_kind, target_id],
		"target_kind": target_kind,
		"target_id": target_id,
		"expression": expression,
		"cause": "ambient",
		"priority": 10,
		"world_position": world_position,
		"time_bucket": time_bucket,
	}


static func _stable_roll(world_seed: int, target_kind: String,
		target_id: String, time_bucket: int) -> int:
	var material := "%d|%s|%s|%d" % [world_seed, target_kind, target_id, time_bucket]
	var prefix := material.sha256_text().substr(0, 7)
	return prefix.hex_to_int() % 1000


static func _is_valid(candidate: Dictionary) -> bool:
	return not String(candidate.get("target_key", "")).is_empty() \
		and not String(candidate.get("expression", "")).is_empty() \
		and candidate.get("world_position") is Vector3 \
		and int(candidate.get("priority", -1)) >= 0


static func _candidate_before(a: Dictionary, b: Dictionary) -> bool:
	var a_priority := int(a.get("priority", 0))
	var b_priority := int(b.get("priority", 0))
	if a_priority != b_priority:
		return a_priority > b_priority
	var a_cause := String(a.get("cause", ""))
	var b_cause := String(b.get("cause", ""))
	if a_cause != b_cause:
		return a_cause < b_cause
	return String(a.get("target_key", "")) < String(b.get("target_key", ""))


static func _too_close(candidate: Dictionary, selected: Array,
		min_spacing: float) -> bool:
	if min_spacing <= 0.0:
		return false
	var position: Vector3 = candidate["world_position"]
	for existing: Dictionary in selected:
		var other: Vector3 = existing["world_position"]
		var planar_distance := Vector2(position.x, position.z).distance_to(
			Vector2(other.x, other.z))
		if planar_distance < min_spacing:
			return true
	return false
