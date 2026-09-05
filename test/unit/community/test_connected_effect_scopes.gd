extends GutTest

const CommunityPlugin := preload("res://plugins/community/community_plugin.gd")

func _resident(home: Vector2i) -> CommunityResident:
	var resident := CommunityResident.new()
	resident.resident_id = 1
	resident.home_anchor = home
	return resident

func _effect(id: String, scope: String, radius: Variant = null) -> Dictionary:
	return CommunityEffectProfile.normalize_effect({
		"effect_id": id, "quality": "liveability", "manifestation": "neutral",
		"amount": 5, "scope": scope, "radius": radius,
		"stacking_group": id, "reason": id,
	})

func test_isolated_participant_effect_does_not_apply_but_local_effect_does() -> void:
	var resident := _resident(Vector2i.ZERO)
	var source := {"building_id": "place", "anchor": Vector2i(1, 0), "active": true, "participants": [], "effects": [_effect("visit", "participant"), _effect("nearby", "local", 1)]}
	var evaluated := CommunityEffectEvaluator.evaluate(resident, [source], {"hour": 12})
	assert_eq(evaluated["effects"].map(func(row): return row["effect_id"]), ["nearby"])

func test_assigned_participant_receives_effect_with_assignment_provenance() -> void:
	var resident := _resident(Vector2i.ZERO)
	var source := {"building_id": "place", "anchor": Vector2i(3, 0), "active": true, "participants": [1], "effects": [_effect("visit", "participant")]}
	var evaluated := CommunityEffectEvaluator.evaluate(resident, [source], {"hour": 12})
	assert_eq(evaluated["effects"].size(), 1)
	assert_true(evaluated["effects"][0]["participant"])
	assert_eq(evaluated["effects"][0]["source_building_id"], "place")

func test_resident_scope_stays_at_the_occupied_source_anchor() -> void:
	var resident := _resident(Vector2i.ZERO)
	var effect := _effect("secure_home", "resident")
	assert_true(CommunityEffectEvaluator.applies(effect, resident, {"anchor": Vector2i.ZERO, "active": true}, {"hour": 0}))
	assert_false(CommunityEffectEvaluator.applies(effect, resident, {"anchor": Vector2i(1, 0), "active": true}, {"hour": 0}))

func test_placement_preview_reports_new_and_overlapping_home_coverage() -> void:
	var saved_structures := GameState.structures
	var structure := Structure.new()
	structure.metadata = [CommunityEffectProfile.from_dict({"effects": [{
		"effect_id": "green", "quality": "beauty", "manifestation": "neutral", "amount": 5,
		"scope": "local", "radius": 2, "stacking_group": "green", "reason": "green",
	}]})]
	GameState.structures = [structure]
	var plugin := CommunityPlugin.new()
	var first := _resident(Vector2i(1, 0)); first.resident_id = 1
	var second := _resident(Vector2i(2, 0)); second.resident_id = 2
	second.applied_effects = [{"stacking_group": "green", "applied_amount": 5.0}]
	plugin._residents = {1: first, 2: second}
	var preview: Dictionary = plugin.get_placement_preview(0, Vector2i.ZERO)
	assert_eq(preview["max_radius"], 2)
	assert_eq(preview["homes_in_range"], [1, 2])
	assert_eq(preview["newly_served_homes"], [1])
	assert_eq(preview["overlapping_coverage_homes"], [2])
	plugin.free()
	GameState.structures = saved_structures
