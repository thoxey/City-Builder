extends GutTest

const RuntimeType := preload("res://scripts/community/community_compiled_runtime.gd")
const CompiledEvaluator := preload("res://scripts/community/community_compiled_evaluator.gd")
const ResultType := preload("res://scripts/community/community_evaluation_result.gd")

func _resident() -> CommunityResident:
	var resident := CommunityResident.new()
	resident.resident_id = 7
	resident.home_anchor = Vector2i(1, 0)
	resident.manifestation_weights = {
		"opportunity": {"identity": 0.2, "freedom": 0.6, "care": 0.2},
		"liveability": {"identity": 0.2, "freedom": 0.2, "care": 0.6},
		"beauty": {"identity": 0.6, "freedom": 0.2, "care": 0.2},
		"belonging": {"identity": 0.2, "freedom": 0.6, "care": 0.2},
	}
	resident.sensitivities = {"noise": 1.25, "pollution": 0.8}
	resident.activity_assignment = {"anchor": {"x": 2, "z": 0}}
	return resident

func _sources() -> Array:
	return [
		{"internal_id":1, "building_id":"park", "anchor":Vector2i(0, 0), "active":true, "participants":[], "effects":[
			{"effect_id":"green", "quality":"beauty", "manifestation":"care", "amount":6.0, "scope":"local", "radius":2, "stacking_group":"green"},
			{"effect_id":"calm", "quality":"liveability", "manifestation":"neutral", "amount":3.0, "scope":"city", "stacking_group":"calm"},
		]},
		{"internal_id":2, "building_id":"club", "anchor":Vector2i(2, 0), "active":true, "participants":[7], "effects":[
			{"effect_id":"crowd", "quality":"belonging", "manifestation":"freedom", "amount":8.0, "scope":"participant", "stacking_group":"crowd", "schedule":{"start":21,"end":4}},
			{"effect_id":"noise", "quality":"liveability", "manifestation":"neutral", "amount":-4.0, "scope":"local", "radius":2, "sensitivity":"noise", "stacking_group":"noise", "schedule":{"start":21,"end":4}},
		]},
	]

func _revisions(structures: int = 1) -> Dictionary:
	return {"topology":1,"structures":structures,"programmes":1,"occupancy":1,"schedules":1,"balance":1,"time":21}

func test_canonical_and_compiled_evaluators_are_exactly_equivalent() -> void:
	var resident := _resident()
	var sources := _sources()
	var canonical := CommunityEffectEvaluator.evaluate_totals(resident, sources, {"hour":21})
	var runtime = RuntimeType.build(sources, _revisions())
	var compiled = CompiledEvaluator.evaluate(resident, runtime, {"hour":21})
	assert_eq(compiled.to_totals_dictionary(), canonical)
	assert_eq(compiled.quality_totals.size(), 4)
	assert_true(compiled.to_operational_dict().get("effects", []).is_empty())

func test_preindexed_home_and_participant_handles_preserve_exact_stacking_order() -> void:
	var resident := _resident()
	var sources := _sources()
	var runtime = RuntimeType.build(sources, _revisions())
	var expected = CompiledEvaluator.evaluate(resident, runtime, {"hour":21})
	var actual = ResultType.new()
	CompiledEvaluator.evaluate_handles_into(resident, runtime, {"hour":21},
		runtime.candidate_effects_for_home(resident.home_anchor),
		runtime.participant_effects_for_source(sources[1]), actual)
	assert_eq(actual.to_totals_dictionary(), expected.to_totals_dictionary())

func test_compiled_participant_benefit_table_preserves_authored_schedule_and_formula() -> void:
	var resident := _resident()
	var runtime = RuntimeType.build(_sources(), _revisions())
	var benefits: Array = runtime.participant_benefits_by_hour(resident)
	assert_eq(benefits.size(), 24)
	assert_eq(benefits[12].get(2, 0.0), 0.0)
	assert_almost_eq(float(benefits[21].get(2, 0.0)),
		8.0 * (0.5 + 1.5 * 0.6) * float(resident.quality_importance.belonging), 0.00001)

func test_precompiled_migration_rows_match_indexed_evaluation_exactly() -> void:
	var resident := _resident()
	var sources := _sources()
	var runtime = RuntimeType.build(sources, _revisions())
	var participant: Array = runtime.participant_effects_for_source(sources[1])
	var handles: Array = runtime.merge_effect_handles(runtime.candidate_effects_for_home(resident.home_anchor), participant)
	var lookup := {}
	for effect_index in participant: lookup[int(effect_index)] = true
	var rows: Dictionary = CompiledEvaluator.compile_indexed_rows(runtime, 21, handles, lookup)
	var expected = ResultType.new()
	CompiledEvaluator.evaluate_indexed_into(resident, runtime, 21, handles, lookup, expected)
	var actual = ResultType.new()
	CompiledEvaluator.evaluate_rows_into(resident, runtime, rows, actual)
	assert_eq(actual.to_totals_dictionary(), expected.to_totals_dictionary())

func test_candidate_multiplier_table_matches_precompiled_rows_exactly() -> void:
	var resident := _resident()
	var sources := _sources()
	var runtime = RuntimeType.build(sources, _revisions())
	var participant: Array = runtime.participant_effects_for_source(sources[1])
	var handles: Array = runtime.merge_effect_handles(runtime.candidate_effects_for_home(resident.home_anchor), participant)
	var lookup := {}
	for effect_index in participant: lookup[int(effect_index)] = true
	var rows: Dictionary = CompiledEvaluator.compile_indexed_rows(runtime, 21, handles, lookup)
	var expected = ResultType.new()
	CompiledEvaluator.evaluate_rows_into(resident, runtime, rows, expected)
	var actual = ResultType.new()
	var multipliers: PackedFloat64Array = CompiledEvaluator.compile_resident_multipliers(resident, runtime)
	CompiledEvaluator.evaluate_rows_with_multipliers_into(runtime, rows, multipliers, actual)
	assert_eq(actual.to_totals_dictionary(), expected.to_totals_dictionary())

func test_revision_mismatch_invalidates_without_wall_clock_fallback() -> void:
	var runtime = RuntimeType.build(_sources(), _revisions())
	assert_true(runtime.matches_revisions(_revisions()))
	assert_false(runtime.matches_revisions(_revisions(2)))

func test_deterministic_rebuild_matches_incremental_replacement() -> void:
	var sources := _sources()
	var rebuilt = RuntimeType.build(sources, _revisions(2))
	var incremental = RuntimeType.build([], _revisions())
	incremental.replace_sources(sources, _revisions(2))
	assert_eq(incremental.canonical_fingerprint(), rebuilt.canonical_fingerprint())
	assert_eq(CompiledEvaluator.evaluate(_resident(), incremental, {"hour":21}).to_totals_dictionary(), CompiledEvaluator.evaluate(_resident(), rebuilt, {"hour":21}).to_totals_dictionary())

func test_explanation_projection_is_explicit_bounded_and_detached() -> void:
	var runtime = RuntimeType.build(_sources(), _revisions())
	var first: Array = CompiledEvaluator.project_explanation(_resident(), runtime, {"hour":21}, 2)
	assert_eq(first.size(), 2)
	first[0]["applied_amount"] = 999.0
	var second: Array = CompiledEvaluator.project_explanation(_resident(), runtime, {"hour":21}, 2)
	assert_ne(second[0]["applied_amount"], 999.0)

func test_runtime_cache_is_not_a_datamap_property_or_public_snapshot_value() -> void:
	var map := DataMap.new()
	var names: Array[String] = []
	for property in map.get_property_list():
		names.append(String(property["name"]))
	assert_false("community_compiled_runtime" in names)
	var runtime = RuntimeType.build(_sources(), _revisions())
	assert_false("runtime" in CompiledEvaluator.evaluate(_resident(), runtime, {"hour":21}).to_operational_dict())
