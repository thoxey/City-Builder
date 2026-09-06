extends RefCounted
class_name CommunityCompiledEvaluator

const RuntimeType := preload("res://scripts/community/community_compiled_runtime.gd")
const ResultType := preload("res://scripts/community/community_evaluation_result.gd")
const CanonicalEvaluator := preload("res://scripts/community/community_effect_evaluator.gd")

static func evaluate(resident: CommunityResident, runtime: Variant,
		context: Dictionary = {}) -> Variant:
	var result = ResultType.new()
	return evaluate_into(resident, runtime, context, result, true)

static func evaluate_into(resident: CommunityResident, runtime: Variant,
		context: Dictionary, result: Variant, include_provenance: bool = false) -> Variant:
	var hour := int(context.get("hour", 0)) % 24
	var participant_overrides: Array = context.get("participant_effects", [])
	var participant_override_lookup: Dictionary = context.get("participant_override_lookup", {})
	if participant_override_lookup.is_empty():
		for effect_index in participant_overrides: participant_override_lookup[int(effect_index)] = true
	var candidate_effects: Array
	if context.has("candidate_effects"):
		candidate_effects = context["candidate_effects"]
	else:
		candidate_effects = runtime.candidate_effects(resident, participant_overrides)
	return evaluate_indexed_into(resident, runtime, hour, candidate_effects,
		participant_override_lookup, result, include_provenance)

static func evaluate_indexed_into(resident: CommunityResident, runtime: Variant,
		hour: int, candidate_effects: Array, participant_override_lookup: Dictionary,
		result: Variant, include_provenance: bool = false) -> Variant:
	result.reset(runtime.runtime_revision, include_provenance)
	var totals: PackedFloat64Array = result._scratch_totals
	var group_counts: Dictionary = result._stack_counts
	for effect_index in candidate_effects:
		if not _applies(resident, runtime, effect_index, hour, participant_override_lookup): continue
		var group_key := int(runtime.stacking_keys[effect_index])
		var ordinal := int(group_counts.get(group_key, 0))
		group_counts[group_key] = ordinal + 1
		var stacking := 1.0 if ordinal == 0 else (0.5 if ordinal == 1 else (0.25 if ordinal == 2 else 0.0))
		var quality_id := int(runtime.quality_ids[effect_index])
		var manifestation_id := int(runtime.manifestation_ids[effect_index])
		var preference := 1.0
		if runtime.manifestation_names[manifestation_id] != "neutral":
			preference = 0.5 + 1.5 * float(resident.manifestation_weights.get(runtime.quality_names[quality_id], {}).get(runtime.manifestation_names[manifestation_id], 0.0))
		var sensitivity := 1.0
		var sensitivity_id := int(runtime.sensitivity_ids[effect_index])
		if sensitivity_id >= 0 and not runtime.sensitivity_names[sensitivity_id].is_empty():
			sensitivity = float(resident.sensitivities.get(runtime.sensitivity_names[sensitivity_id], 1.0))
		totals[quality_id] += CommunityConstants.rounded(float(runtime.amounts[effect_index]) * preference * sensitivity * stacking)
		if include_provenance: result.provenance_handles.append(effect_index)
	for index in 4:
		result.quality_totals[index] = CommunityConstants.rounded(float(totals[index]))
	return result

static func compile_indexed_rows(runtime: Variant, hour: int,
		candidate_effects: Array, participant_override_lookup: Dictionary) -> Dictionary:
	var effect_indices := PackedInt32Array()
	var stacking_factors := PackedFloat64Array()
	var group_counts := {}
	for effect_index_value in candidate_effects:
		var effect_index := int(effect_index_value)
		if (int(runtime.schedule_masks[effect_index]) & (1 << hour)) == 0: continue
		var source_id := int(runtime.effect_source_ids[effect_index])
		if runtime.source_active[source_id] == 0: continue
		if runtime.requires_active_building[effect_index] != 0 and \
				(int(runtime.source_schedule_masks[source_id]) & (1 << hour)) == 0:
			continue
		if int(runtime.scopes[effect_index]) == RuntimeType.SCOPE_PARTICIPANT and not participant_override_lookup.has(effect_index):
			continue
		var group_key := int(runtime.stacking_keys[effect_index])
		var ordinal := int(group_counts.get(group_key, 0))
		group_counts[group_key] = ordinal + 1
		effect_indices.append(effect_index)
		stacking_factors.append(1.0 if ordinal == 0 else (0.5 if ordinal == 1 else (0.25 if ordinal == 2 else 0.0)))
	return {"effect_indices":effect_indices, "stacking_factors":stacking_factors}

static func evaluate_rows_into(resident: CommunityResident, runtime: Variant,
		rows: Dictionary, result: Variant) -> Variant:
	result.reset(runtime.runtime_revision, false)
	var totals: PackedFloat64Array = result._scratch_totals
	var effect_indices: PackedInt32Array = rows.effect_indices
	var stacking_factors: PackedFloat64Array = rows.stacking_factors
	for row_index in effect_indices.size():
		var effect_index := int(effect_indices[row_index])
		var quality_id := int(runtime.quality_ids[effect_index])
		var manifestation_id := int(runtime.manifestation_ids[effect_index])
		var preference := 1.0
		if runtime.manifestation_names[manifestation_id] != "neutral":
			preference = 0.5 + 1.5 * float(resident.manifestation_weights.get(runtime.quality_names[quality_id], {}).get(runtime.manifestation_names[manifestation_id], 0.0))
		var sensitivity := 1.0
		var sensitivity_id := int(runtime.sensitivity_ids[effect_index])
		if sensitivity_id >= 0 and not runtime.sensitivity_names[sensitivity_id].is_empty():
			sensitivity = float(resident.sensitivities.get(runtime.sensitivity_names[sensitivity_id], 1.0))
		totals[quality_id] += CommunityConstants.rounded(float(runtime.amounts[effect_index]) * preference * sensitivity * float(stacking_factors[row_index]))
	for index in 4:
		result.quality_totals[index] = CommunityConstants.rounded(float(totals[index]))
	return result

## Candidate quotes evaluate the same resident against many home/hour row sets.
## Compile resident-only preference and sensitivity lookups once per candidate.
static func compile_resident_multipliers(resident: CommunityResident, runtime: Variant) -> PackedFloat64Array:
	var multipliers := PackedFloat64Array()
	multipliers.resize(runtime.effect_ids.size())
	for effect_index in runtime.effect_ids.size():
		var quality_id := int(runtime.quality_ids[effect_index])
		var manifestation_id := int(runtime.manifestation_ids[effect_index])
		var preference := 1.0
		if runtime.manifestation_names[manifestation_id] != "neutral":
			preference = 0.5 + 1.5 * float(resident.manifestation_weights.get(runtime.quality_names[quality_id], {}).get(runtime.manifestation_names[manifestation_id], 0.0))
		var sensitivity := 1.0
		var sensitivity_id := int(runtime.sensitivity_ids[effect_index])
		if sensitivity_id >= 0 and not runtime.sensitivity_names[sensitivity_id].is_empty():
			sensitivity = float(resident.sensitivities.get(runtime.sensitivity_names[sensitivity_id], 1.0))
		multipliers[effect_index] = preference * sensitivity
	return multipliers

static func evaluate_rows_with_multipliers_into(runtime: Variant, rows: Dictionary,
		multipliers: PackedFloat64Array, result: Variant) -> Variant:
	result.reset(runtime.runtime_revision, false)
	var totals: PackedFloat64Array = result._scratch_totals
	var effect_indices: PackedInt32Array = rows.effect_indices
	var stacking_factors: PackedFloat64Array = rows.stacking_factors
	for row_index in effect_indices.size():
		var effect_index := int(effect_indices[row_index])
		var quality_id := int(runtime.quality_ids[effect_index])
		totals[quality_id] += CommunityConstants.rounded(float(runtime.amounts[effect_index]) * multipliers[effect_index] * float(stacking_factors[row_index]))
	for index in 4:
		result.quality_totals[index] = CommunityConstants.rounded(float(totals[index]))
	return result

static func evaluate_handles_into(resident: CommunityResident, runtime: Variant,
		context: Dictionary, base_effects: Array, participant_effects: Array,
		result: Variant) -> Variant:
	var override_lookup := {}
	for effect_index in participant_effects: override_lookup[int(effect_index)] = true
	var indexed_context := context.duplicate()
	indexed_context["participant_effects"] = participant_effects
	indexed_context["participant_override_lookup"] = override_lookup
	indexed_context["candidate_effects"] = runtime.merge_effect_handles(base_effects, participant_effects)
	return evaluate_into(resident, runtime, indexed_context, result, false)

static func project_explanation(resident: CommunityResident, runtime: Variant,
		context: Dictionary = {}, limit: int = 12) -> Array:
	var evaluation := CanonicalEvaluator.evaluate(resident, runtime.explanation_sources(), context)
	var effects: Array = evaluation.get("effects", []).duplicate(true)
	effects.resize(mini(effects.size(), maxi(limit, 0)))
	return effects

static func _applies(resident: CommunityResident, runtime: Variant,
		effect_index: int, hour: int, participant_overrides: Dictionary = {}) -> bool:
	if (int(runtime.schedule_masks[effect_index]) & (1 << hour)) == 0: return false
	var source_id := int(runtime.effect_source_ids[effect_index])
	if runtime.source_active[source_id] == 0: return false
	if runtime.requires_active_building[effect_index] != 0 and \
			(int(runtime.source_schedule_masks[source_id]) & (1 << hour)) == 0:
		return false
	match int(runtime.scopes[effect_index]):
		RuntimeType.SCOPE_CITY: return true
		RuntimeType.SCOPE_LOCAL:
			if resident.home_anchor == null: return false
			return abs(resident.home_anchor.x - runtime.source_anchor_x[source_id]) + abs(resident.home_anchor.y - runtime.source_anchor_y[source_id]) <= runtime.radii[effect_index]
		RuntimeType.SCOPE_RESIDENT:
			return resident.home_anchor != null and resident.home_anchor == Vector2i(runtime.source_anchor_x[source_id], runtime.source_anchor_y[source_id])
		RuntimeType.SCOPE_PARTICIPANT:
			return participant_overrides.has(effect_index) or runtime.participates(resident.resident_id, effect_index)
	return false
