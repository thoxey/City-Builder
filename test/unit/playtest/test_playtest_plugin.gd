extends GutTest

const PlaytestCls := preload("res://plugins/playtest/playtest_plugin.gd")

var playtest: Node
var builder: StubBuilder
var clock: StubClock
var saved_map: DataMap
var saved_registry: Dictionary

func before_each() -> void:
	saved_map = GameState.map
	saved_registry = GameState.building_registry.duplicate(true)
	GameState.map = DataMap.new()
	GameState.building_registry = {}
	builder = StubBuilder.new()
	clock = StubClock.new()
	playtest = PlaytestCls.new()
	playtest._clock = clock
	playtest._community = StubCommunity.new()
	playtest._dialogue = StubDialogue.new()
	playtest.set_builder_for_tests(builder)
	add_child(playtest)

func after_each() -> void:
	playtest.queue_free()
	builder.free()
	clock.free()
	playtest._community.free()
	playtest._dialogue.free()
	GameState.map = saved_map
	GameState.building_registry = saved_registry

func test_start_requires_builder_readiness() -> void:
	playtest.set_builder_for_tests(null)
	var result: Dictionary = playtest.start_session({"scenario_id": "fresh_city", "seed": 1})
	assert_eq(result["error"]["reason"], "game_not_ready")

func test_scenario_path_allows_first_town_namespace_without_traversal() -> void:
	assert_eq(PlaytestCls._scenario_path("fresh_city"), "res://test/scenarios/fresh_city.json")
	assert_eq(PlaytestCls._scenario_path("first_town/compact"), "res://test/scenarios/first_town/compact.json")
	assert_eq(PlaytestCls._scenario_path("first_town/../secret"), "")
	assert_eq(PlaytestCls._scenario_path("another/place"), "")

func test_readiness_recovers_builder_after_autoload_startup_order() -> void:
	var lazy := LazyPlaytest.new()
	lazy.discovered_builder = builder
	assert_true(lazy.is_ready_for_commands())
	assert_eq(lazy._builder, builder)
	lazy.free()

func test_start_creates_ready_fresh_session() -> void:
	var result: Dictionary = playtest.start_session({"scenario_id": "fresh_city", "seed": 12})
	assert_eq(result["session"]["status"], "ready")
	assert_eq(result["session"]["sequence"], 0)
	assert_eq(result["session"]["seed"], 12)
	assert_eq(builder.reset_calls, 1)

func test_snapshot_contains_balance_domains_and_stable_hash() -> void:
	var first: Dictionary = playtest.start_session({"scenario_id": "fresh_city", "seed": 1})["snapshot"]
	for key in ["simulation", "economy", "population", "community", "satisfaction", "attractiveness", "demand", "land", "buildings", "progression", "available_choice_count", "tier_two_available", "state_hash"]:
		assert_has(first, key)
	var second: Dictionary = playtest.get_snapshot()
	assert_eq(first["state_hash"], second["state_hash"])
	assert_eq(first["simulation"]["hour"], 6)
	assert_eq(first["economy"]["cash"], 1000)
	assert_has(first["land"], "occupied_count")
	assert_has(first["land"], "free_count")
	assert_eq(first["population"]["current"], 2)
	assert_eq(first["community"]["population"], 2)

func test_compact_state_omits_resident_array_but_keeps_aggregates() -> void:
	playtest.start_session({"scenario_id": "fresh_city", "seed": 1})
	var full: Dictionary = playtest.handle_command("get_state", {})["snapshot"]["community"]
	var compact: Dictionary = playtest.handle_command("get_state", {"compact": true})["snapshot"]["community"]
	assert_has(full, "residents")
	assert_does_not_have(compact, "residents")
	assert_eq(compact["population"], full["population"])
	assert_has(compact, "average_qualities")

func test_place_demolish_and_advance_delegate_to_gameplay_commands() -> void:
	playtest.start_session({"scenario_id": "fresh_city", "seed": 1})
	var placed: Dictionary = playtest.handle_command("place", {
		"request_id": "p1", "building_id": "house", "anchor": {"x": 2, "z": 3},
	})
	assert_eq(placed["status"], "applied")
	assert_eq(builder.last_place["anchor"], Vector2i(2, 3))
	var demolished: Dictionary = playtest.handle_command("demolish", {
		"request_id": "d1", "cell": {"x": 2, "z": 3},
	})
	assert_eq(demolished["status"], "applied")
	assert_eq(builder.last_demolish, Vector2i(2, 3))
	var advanced: Dictionary = playtest.handle_command("advance", {"request_id": "a1", "hours": 1})
	assert_eq(advanced["status"], "applied")
	assert_eq(clock.absolute_hour, 1)
	assert_eq(advanced["sequence"], 3)

func test_invalid_coordinates_are_normal_gameplay_rejections() -> void:
	playtest.start_session({"scenario_id": "fresh_city", "seed": 1})
	var outcome: Dictionary = playtest.handle_command("place", {"request_id": "bad", "building_id": "house", "anchor": {"x": "no", "z": 0}})
	assert_eq(outcome["status"], "rejected")
	assert_eq(outcome["reason"], "invalid_coordinate")
	assert_eq(builder.place_calls, 0)

func test_duplicate_request_is_not_applied_twice() -> void:
	playtest.start_session({"scenario_id": "fresh_city", "seed": 1})
	var request := {"request_id": "same", "building_id": "house", "anchor": {"x": 0, "z": 0}}
	var first: Dictionary = playtest.handle_command("place", request)
	var duplicate: Dictionary = playtest.handle_command("place", request)
	assert_eq(first["status"], "applied")
	assert_eq(duplicate["status"], "duplicate")
	assert_false(duplicate["changed"])
	assert_eq(builder.place_calls, 1)
	assert_eq(duplicate["sequence"], first["sequence"])

func test_expected_sequence_conflict_and_ordered_trace() -> void:
	playtest.start_session({"scenario_id": "fresh_city", "seed": 1})
	var conflict: Dictionary = playtest.handle_command("advance", {"request_id": "stale", "hours": 1, "expected_sequence": 4})
	assert_eq(conflict["reason"], "sequence_conflict")
	assert_eq(clock.absolute_hour, 0)
	var trace: Array = playtest.get_trace()
	assert_eq(trace[0]["kind"], "start")
	assert_eq(trace[1]["kind"], "advance")

func test_request_cache_is_bounded() -> void:
	playtest.start_session({"scenario_id": "fresh_city", "seed": 1})
	for i in 270:
		playtest.handle_command("advance", {"request_id": "r%d" % i, "hours": 0})
	assert_lte(playtest._request_cache.size(), playtest.REQUEST_CACHE_LIMIT)

func test_resolve_dialogue_is_idempotent_semantic_action() -> void:
	playtest.start_session({"scenario_id": "fresh_city", "seed": 1})
	var request := {"request_id":"resolve-1", "event_id":"arrival"}
	var first: Dictionary = playtest.handle_command("resolve_dialogue", request)
	var duplicate: Dictionary = playtest.handle_command("resolve_dialogue", request)
	assert_eq(first["status"], PlaytestActionResult.STATUS_APPLIED)
	assert_eq(duplicate["status"], PlaytestActionResult.STATUS_DUPLICATE)
	assert_eq(playtest._dialogue.resolved_ids, ["arrival"])

func test_progression_snapshot_has_complete_contract_shape() -> void:
	var progression: Dictionary = playtest.start_session({"scenario_id":"fresh_city", "seed":1})["snapshot"]["progression"]
	for key in ["buckets", "characters", "patrons", "story_buildings", "unlocked", "placed", "donations_applied", "flags", "event_counts", "pending_dialogue_event_ids", "milestones"]:
		assert_has(progression, key)

class StubBuilder extends Node:
	var reset_calls := 0
	var place_calls := 0
	var last_place: Dictionary = {}
	var last_demolish := Vector2i.ZERO
	func reset_to_fresh_map(map: DataMap) -> Dictionary:
		reset_calls += 1
		GameState.map = map
		return PlaytestActionResult.applied()
	func try_place_building(id: String, anchor: Vector2i, rotation: int, replace: bool, variant: String, _rng: RandomNumberGenerator) -> Dictionary:
		place_calls += 1
		last_place = {"id": id, "anchor": anchor, "rotation": rotation, "replace": replace, "variant": variant}
		return PlaytestActionResult.applied(last_place)
	func try_demolish_cell(cell: Vector2i) -> Dictionary:
		last_demolish = cell
		return PlaytestActionResult.applied({"cell": cell})
	static func _orientation_to_steps(_orientation: int) -> int: return 0

class LazyPlaytest extends "res://plugins/playtest/playtest_plugin.gd":
	var discovered_builder: Node
	func _find_builder() -> Node: return discovered_builder

class StubClock extends PluginBase:
	var absolute_hour := 0
	var hour := 6
	func get_plugin_name() -> String: return "StubClock"
	func reset_manual_clock(start_hour: int) -> void:
		absolute_hour = 0
		hour = start_hour
	func advance_hours(hours: int) -> Dictionary:
		if hours < 0 or hours > 1000: return PlaytestActionResult.rejected("invalid_hours")
		var old := absolute_hour
		absolute_hour += hours
		hour = (hour + hours) % 24
		var result := PlaytestActionResult.applied({"requested_hours": hours, "emitted_hours": hours, "from_absolute_hour": old, "to_absolute_hour": absolute_hour})
		result["changed"] = hours > 0
		return result
	func get_absolute_hour() -> int: return absolute_hour
	func current_hour() -> int: return hour
	func is_manual() -> bool: return true

class StubCommunity extends PluginBase:
	func get_population() -> int: return 2
	func get_snapshot(compact: bool = false) -> Dictionary:
		var result := {
			"population": 2, "capacity": 3,
			"average_qualities": {"opportunity": 50.0, "liveability": 50.0, "beauty": 50.0, "belonging": 50.0},
			"average_composite_happiness": 50.0,
			"personality_distribution": {"cohorts": {"general": 2}, "dominant_lenses": {"identity": 1, "freedom": 1, "care": 0}},
			"migration": {"arrivals": 2, "departures": 0, "rejections": 0, "last_day": 0},
			"effect_summary": [],
		}
		if not compact: result["residents"] = [{"resident_id": 1}, {"resident_id": 2}]
		return result

class StubDialogue extends PluginBase:
	var resolved_ids: Array[String] = []
	func set_presentation_enabled(_enabled: bool) -> void: pass
	func resolve_pending_event(event_id: String) -> Dictionary:
		resolved_ids.append(event_id)
		return PlaytestActionResult.applied({"event_id":event_id})
