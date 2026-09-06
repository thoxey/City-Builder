extends GutTest

const Policy := preload("res://scripts/reactions/world_reaction_policy.gd")


func _candidate(target: String, priority: int, position: Vector3,
		cause: String = "condition") -> Dictionary:
	return {
		"target_key": target,
		"target_kind": target.get_slice(":", 0),
		"target_id": target.get_slice(":", 1),
		"expression": "pleased",
		"cause": cause,
		"priority": priority,
		"world_position": position,
	}


func test_selects_highest_priority_with_a_hard_visible_cap() -> void:
	var chosen := Policy.choose([
		_candidate("person:1", 10, Vector3(0, 0, 0), "ambient"),
		_candidate("building:2", 80, Vector3(4, 0, 0)),
		_candidate("car:3", 100, Vector3(8, 0, 0)),
	], {}, {}, 0.0, 2, 0.0)
	assert_eq(chosen.map(func(row): return row.target_key), ["car:3", "building:2"])


func test_allows_only_one_reaction_per_target() -> void:
	var chosen := Policy.choose([
		_candidate("person:1", 80, Vector3.ZERO),
		_candidate("person:1", 70, Vector3.ZERO),
	], {}, {}, 0.0, 5, 0.0)
	assert_eq(chosen.size(), 1)
	assert_eq(chosen[0].priority, 80)


func test_respects_active_and_cooldown_targets() -> void:
	var chosen := Policy.choose([
		_candidate("person:1", 80, Vector3.ZERO),
		_candidate("person:2", 80, Vector3(3, 0, 0)),
		_candidate("person:3", 80, Vector3(6, 0, 0)),
	], {"person:1": true}, {"person:2": 12.0}, 10.0, 5, 0.0)
	assert_eq(chosen.map(func(row): return row.target_key), ["person:3"])


func test_suppresses_nearby_ambient_clutter_but_keeps_critical_events() -> void:
	var chosen := Policy.choose([
		_candidate("person:1", 80, Vector3(3, 0, 0)),
		_candidate("person:2", 10, Vector3(0.5, 0, 0), "ambient"),
		_candidate("person:3", 100, Vector3(0.75, 0, 0), "state_change"),
	], {}, {}, 0.0, 5, 1.35)
	assert_eq(chosen.map(func(row): return row.target_key), ["person:3", "person:1"])


func test_ambient_choice_is_repeatable_without_global_rng() -> void:
	var first := Policy.ambient_candidate(42, "building", "17", 8,
		"busy", Vector3(2, 3, 4), 1000)
	var second := Policy.ambient_candidate(42, "building", "17", 8,
		"busy", Vector3(2, 3, 4), 1000)
	assert_eq(first, second)
	assert_eq(first.time_bucket, 8)
	assert_true(Policy.ambient_candidate(42, "building", "17", 8,
		"busy", Vector3.ZERO, 0).is_empty())
