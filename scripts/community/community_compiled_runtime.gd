extends RefCounted
class_name CommunityCompiledRuntime

const Evaluator := preload("res://scripts/community/community_effect_evaluator.gd")

const SCOPE_CITY := 0
const SCOPE_LOCAL := 1
const SCOPE_RESIDENT := 2
const SCOPE_PARTICIPANT := 3
const SCOPE_IDS := {"city":SCOPE_CITY,"local":SCOPE_LOCAL,"resident":SCOPE_RESIDENT,"participant":SCOPE_PARTICIPANT}

var runtime_revision := 0
var source_ids := PackedInt32Array()
var source_internal_ids := PackedInt32Array()
var effect_ids := PackedInt32Array()
var effect_source_ids := PackedInt32Array()
var quality_ids := PackedInt32Array()
var manifestation_ids := PackedInt32Array()
var scopes := PackedInt32Array()
var amounts := PackedFloat64Array()
var radii := PackedInt32Array()
var schedule_masks := PackedInt32Array()
var sensitivity_ids := PackedInt32Array()
var stacking_keys := PackedInt64Array()
var source_anchor_x := PackedInt32Array()
var source_anchor_y := PackedInt32Array()
var source_active := PackedByteArray()
var source_schedule_masks := PackedInt32Array()
var requires_active_building := PackedByteArray()
var global_spans := PackedInt32Array()
var spatial_spans := PackedInt32Array()
var resident_links := PackedInt32Array()
var participant_links := PackedInt32Array()
var quality_names: Array[String] = []
var manifestation_names: Array[String] = []
var sensitivity_names: Array[String] = []
var _source_names: Array[String] = []
var _effect_names: Array[String] = []
var _participants: Dictionary = {}
var _participant_effects: Dictionary = {}
var _spatial_by_cell: Dictionary = {}
var _resident_by_cell: Dictionary = {}
var _dependency_revisions: Dictionary = {}
var _explanation_sources: Array = []

static func build(sources: Array, revisions: Dictionary) -> Variant:
	var runtime = (load("res://scripts/community/community_compiled_runtime.gd") as GDScript).new()
	runtime.replace_sources(sources, revisions)
	return runtime

func replace_sources(sources: Array, revisions: Dictionary) -> void:
	_clear()
	_dependency_revisions = revisions.duplicate(true)
	runtime_revision = _revision_fingerprint(_dependency_revisions)
	# Source records are freshly built value dictionaries. Retain their nested
	# authored records read-only; deep-copying route evidence here made the hot
	# hourly path scale with the whole road graph.
	_explanation_sources = sources.duplicate()
	var prepared := Evaluator.prepare_effects(sources)
	quality_names.assign(CommunityConstants.QUALITIES)
	manifestation_names = ["identity", "freedom", "care", "neutral"]
	sensitivity_names = [""]
	var source_name_set := {}
	var effect_name_set := {}
	var stacking_name_set := {}
	for item in prepared:
		var source: Dictionary = item["source"]
		var effect: Dictionary = item["effect"]
		source_name_set[str(source.get("building_id", "")) + "|" + CommunityConstants.coordinate_key(source.get("anchor"))] = true
		effect_name_set[str(effect.get("effect_id", ""))] = true
		stacking_name_set[str(effect.get("stacking_group", ""))] = true
		var sensitivity := str(effect.get("sensitivity", ""))
		if not sensitivity.is_empty() and sensitivity not in sensitivity_names: sensitivity_names.append(sensitivity)
	_source_names.clear()
	for source_name_value in source_name_set.keys():
		_source_names.append(str(source_name_value))
	_source_names.sort()
	_effect_names.clear()
	for effect_name_value in effect_name_set.keys():
		_effect_names.append(str(effect_name_value))
	_effect_names.sort()
	var stacking_names: Array = stacking_name_set.keys()
	stacking_names.sort()
	sensitivity_names.sort()
	for index in _source_names.size():
		source_ids.append(index)
		source_internal_ids.append(-1)
		source_anchor_x.append(0)
		source_anchor_y.append(0)
		source_active.append(1)
		source_schedule_masks.append((1 << 24) - 1)
	for item in prepared:
		var source: Dictionary = item["source"]
		var effect: Dictionary = item["effect"]
		var source_key := str(source.get("building_id", "")) + "|" + CommunityConstants.coordinate_key(source.get("anchor"))
		var source_id := _source_names.find(source_key)
		var anchor: Variant = CommunityConstants.coordinate(source.get("anchor"))
		anchor = anchor if anchor != null else Vector2i.ZERO
		source_anchor_x[source_id] = anchor.x
		source_anchor_y[source_id] = anchor.y
		source_internal_ids[source_id] = int(source.get("internal_id", -1))
		# A source's authored operating window is compiled once.  `active` is only
		# a static enable flag when no window exists; it must not freeze the hour
		# used to construct the canonical source record.
		var building_schedule: Variant = source.get("building_schedule")
		source_schedule_masks[source_id] = _schedule_mask(building_schedule)
		source_active[source_id] = 1 if building_schedule is Dictionary or bool(source.get("active", true)) else 0
		var effect_index := effect_ids.size()
		effect_ids.append(_effect_names.find(str(effect.get("effect_id", ""))))
		effect_source_ids.append(source_id)
		var quality_id := quality_names.find(str(effect.get("quality", "")))
		var manifestation_id := manifestation_names.find(str(effect.get("manifestation", "neutral")))
		var scope_id := int(SCOPE_IDS.get(str(effect.get("scope", "")), -1))
		quality_ids.append(quality_id)
		manifestation_ids.append(manifestation_id)
		scopes.append(scope_id)
		amounts.append(float(effect.get("amount", 0.0)))
		radii.append(int(effect.get("radius", -1)) if effect.get("radius") != null else -1)
		schedule_masks.append(_schedule_mask(effect.get("schedule")))
		requires_active_building.append(1 if bool(effect.get("requires_active_building", true)) else 0)
		sensitivity_ids.append(sensitivity_names.find(str(effect.get("sensitivity", ""))))
		var stacking_id := stacking_names.find(str(effect.get("stacking_group", "")))
		var sign_id := 0 if float(effect.get("amount", 0.0)) >= 0.0 else 1
		stacking_keys.append((quality_id << 33) | (stacking_id << 1) | sign_id)
		if scope_id == SCOPE_CITY: global_spans.append(effect_index)
		if scope_id == SCOPE_LOCAL:
			spatial_spans.append(effect_index)
			var local_radius := int(radii[effect_index])
			for dx in range(-local_radius, local_radius + 1):
				for dy in range(-local_radius, local_radius + 1):
					if absi(dx) + absi(dy) <= local_radius:
						_append_index(_spatial_by_cell, "%d,%d" % [anchor.x + dx, anchor.y + dy], effect_index)
		if scope_id == SCOPE_RESIDENT:
			resident_links.append(effect_index)
			_append_index(_resident_by_cell, CommunityConstants.coordinate_key(anchor), effect_index)
		if scope_id == SCOPE_PARTICIPANT:
			participant_links.append(effect_index)
			for resident_id in source.get("participants", []):
				var linked: Dictionary = _participants.get(int(resident_id), {})
				linked[effect_index] = true
				_participants[int(resident_id)] = linked
				_append_index(_participant_effects, int(resident_id), effect_index)

func matches_revisions(revisions: Dictionary) -> bool:
	return _dependency_revisions == revisions

func matches_static_revisions(revisions: Dictionary) -> bool:
	for key in revisions:
		if String(key) in ["occupancy", "assignments", "time"]: continue
		if _dependency_revisions.get(key) != revisions[key]: return false
	for key in _dependency_revisions:
		if String(key) in ["occupancy", "assignments", "time"]: continue
		if not revisions.has(key): return false
	return true

## Assignment/occupancy facts change much more often than authored effects.
## Refresh their direct links without recompiling numeric effect metadata.
func update_dynamic_sources(sources: Array, revisions: Dictionary) -> void:
	_dependency_revisions = revisions.duplicate(true)
	runtime_revision = _revision_fingerprint(_dependency_revisions)
	_explanation_sources = sources.duplicate()
	_participants.clear()
	_participant_effects.clear()
	var participant_effects_by_source := {}
	for effect_index in participant_links:
		var source_id := int(effect_source_ids[effect_index])
		if not participant_effects_by_source.has(source_id): participant_effects_by_source[source_id] = []
		participant_effects_by_source[source_id].append(int(effect_index))
	for source_raw in sources:
		var source: Dictionary = source_raw
		var key := str(source.get("building_id", "")) + "|" + CommunityConstants.coordinate_key(source.get("anchor"))
		var source_id := _source_names.find(key)
		if source_id < 0: continue
		for resident_id in source.get("participants", []):
			var linked: Dictionary = _participants.get(int(resident_id), {})
			for effect_index in participant_effects_by_source.get(source_id, []): linked[effect_index] = true
			_participants[int(resident_id)] = linked
			for effect_index in participant_effects_by_source.get(source_id, []):
				_append_index(_participant_effects, int(resident_id), effect_index)

func get_dependency_revisions() -> Dictionary:
	return _dependency_revisions.duplicate(true)

func participates(resident_id: int, effect_index: int) -> bool:
	return bool(_participants.get(resident_id, {}).get(effect_index, false))

func candidate_effects(resident: CommunityResident, participant_overrides: Array = []) -> Array:
	var result := candidate_effects_for_home(resident.home_anchor)
	result.append_array(_participant_effects.get(resident.resident_id, []))
	result.append_array(participant_overrides)
	return _sorted_unique(result)

func candidate_effects_for_home(home_anchor: Variant) -> Array:
	var result: Array = Array(global_spans)
	if home_anchor != null:
		var key := CommunityConstants.coordinate_key(home_anchor)
		result.append_array(_spatial_by_cell.get(key, []))
		result.append_array(_resident_by_cell.get(key, []))
	return _sorted_unique(result)

func merge_effect_handles(base_effects: Array, additional_effects: Array) -> Array:
	var result := base_effects.duplicate()
	result.append_array(additional_effects)
	return _sorted_unique(result)

func _sorted_unique(result: Array) -> Array:
	result.sort()
	var unique: Array = []
	var previous := -1
	for effect_index in result:
		if int(effect_index) != previous: unique.append(int(effect_index))
		previous = int(effect_index)
	return unique

func participant_effects_for_source(source: Dictionary) -> Array:
	var key := str(source.get("building_id", "")) + "|" + CommunityConstants.coordinate_key(source.get("anchor"))
	var source_id := _source_names.find(key)
	if source_id < 0: return []
	var result: Array = []
	for effect_index in participant_links:
		if int(effect_source_ids[effect_index]) == source_id: result.append(int(effect_index))
	return result

## Candidate-specific but allocation-bounded participant preference table. This
## replaces 24 full authored-source scans during each migration quote.
func participant_benefits_by_hour(resident: CommunityResident) -> Array:
	var result: Array = []
	for hour in 24: result.append({})
	for effect_index in participant_links:
		var source_id := int(effect_source_ids[effect_index])
		var internal_id := int(source_internal_ids[source_id])
		var quality_id := int(quality_ids[effect_index])
		var manifestation_id := int(manifestation_ids[effect_index])
		var quality := quality_names[quality_id]
		var manifestation := manifestation_names[manifestation_id]
		var preference := 1.0 if manifestation == "neutral" else 0.5 + 1.5 * float(resident.manifestation_weights.get(quality, {}).get(manifestation, 0.0))
		var value := float(amounts[effect_index]) * preference * float(resident.quality_importance.get(quality, 0.0))
		var schedule_mask := int(schedule_masks[effect_index])
		for hour in 24:
			if (schedule_mask & (1 << hour)) == 0: continue
			var hourly: Dictionary = result[hour]
			hourly[internal_id] = float(hourly.get(internal_id, 0.0)) + value
	return result

func explanation_sources() -> Array:
	return _explanation_sources.duplicate(true)

func canonical_fingerprint() -> String:
	var parts := [str(runtime_revision), str(source_ids), str(source_internal_ids), str(effect_ids), str(effect_source_ids),
		str(quality_ids), str(manifestation_ids), str(scopes), str(amounts), str(radii),
		str(schedule_masks), str(sensitivity_ids), str(stacking_keys), str(source_anchor_x),
		str(source_anchor_y), str(source_active), str(source_schedule_masks),
		str(requires_active_building), str(_participants)]
	return "|".join(parts).sha256_text()

static func _schedule_mask(schedule: Variant) -> int:
	var mask := 0
	for hour in 24:
		if Evaluator.schedule_active(schedule, hour): mask |= 1 << hour
	return mask

static func _revision_fingerprint(revisions: Dictionary) -> int:
	var keys: Array = revisions.keys()
	keys.sort()
	var text := ""
	for key in keys: text += "%s=%s;" % [key, revisions[key]]
	return int(text.hash()) & 0x7fffffff

func _clear() -> void:
	source_ids.clear(); source_internal_ids.clear(); effect_ids.clear(); effect_source_ids.clear(); quality_ids.clear()
	manifestation_ids.clear(); scopes.clear(); amounts.clear(); radii.clear(); schedule_masks.clear()
	sensitivity_ids.clear(); stacking_keys.clear(); source_anchor_x.clear(); source_anchor_y.clear()
	source_active.clear(); source_schedule_masks.clear(); requires_active_building.clear()
	global_spans.clear(); spatial_spans.clear(); resident_links.clear()
	participant_links.clear(); _participants.clear(); _participant_effects.clear()
	_spatial_by_cell.clear(); _resident_by_cell.clear(); _source_names.clear(); _effect_names.clear()
	quality_names.clear(); manifestation_names.clear(); sensitivity_names.clear(); _explanation_sources.clear()

static func _append_index(index: Dictionary, key: Variant, effect_index: int) -> void:
	var values: Array = index.get(key, [])
	values.append(effect_index)
	index[key] = values
