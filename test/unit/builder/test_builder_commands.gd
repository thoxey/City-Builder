extends GutTest

const BuilderCls := preload("res://scripts/builder.gd")

var builder: Node
var catalog: StubCatalog
var economy: StubEconomy
var demand: StubDemand
var land: StubLand
var uniques: StubUniques
var saved_map: DataMap
var saved_structures: Array[Structure]
var saved_cells: Dictionary
var saved_registry: Dictionary
var saved_next_id: int

func before_each() -> void:
	saved_map = GameState.map
	saved_structures = GameState.structures
	saved_cells = GameState.cell_to_building.duplicate(true)
	saved_registry = GameState.building_registry.duplicate(true)
	saved_next_id = GameState._next_building_id
	GameState.map = DataMap.new()
	GameState.cell_to_building = {}
	GameState.building_registry = {}
	GameState._next_building_id = 0

	catalog = StubCatalog.new()
	catalog.add_structure("house", _structure("residential", 5))
	catalog.add_structure("factory", _structure("industrial", 20, [Vector2i(0, 0), Vector2i(1, 0)]))
	catalog.add_structure("park", Structure.new())
	catalog.add_structure("house_a", _structure("residential", 5), "houses")
	catalog.add_structure("house_b", _structure("residential", 5), "houses")
	# Compatibility catalogue record intentionally collides with its Palette pool.
	catalog.add_structure("grass", Structure.new(), "grass", true)
	catalog.add_structure("grass_trees", Structure.new(), "grass")
	catalog.add_structure("grass_flowers", Structure.new(), "grass")
	catalog.add_structure("road", _road_structure())
	GameState.structures = catalog.items

	economy = StubEconomy.new()
	demand = StubDemand.new()
	land = StubLand.new()
	uniques = StubUniques.new()
	builder = BuilderCls.new()
	builder.structures = catalog.items
	builder._catalog = catalog
	builder._economy = economy
	builder._demand = demand
	builder._land = land
	builder._uniques = uniques
	builder._road_straight_idx = catalog.get_item_index("road")
	builder.gridmap = GridMap.new()
	builder.ground_gridmap = GridMap.new()

func after_each() -> void:
	builder.free()
	catalog.free()
	economy.free()
	demand.free()
	land.free()
	uniques.free()
	GameState.map = saved_map
	GameState.structures = saved_structures
	GameState.cell_to_building = saved_cells
	GameState.building_registry = saved_registry
	GameState._next_building_id = saved_next_id

func test_success_and_exactly_one_placed_event() -> void:
	watch_signals(GameEvents)
	var outcome: Dictionary = builder.try_place_building("house", Vector2i.ZERO)
	assert_eq(outcome["status"], "applied")
	assert_eq(GameState.building_registry.size(), 1)
	assert_signal_emit_count(GameEvents, "structure_placed", 1)

func test_outside_land_rejects() -> void:
	land.blocked[Vector2i(2, 3)] = true
	assert_eq(builder.try_place_building("house", Vector2i(2, 3))["reason"], "outside_buildable_area")

func test_occupied_and_replacement_required_are_distinct() -> void:
	assert_eq(builder.try_place_building("park", Vector2i.ZERO)["status"], "applied")
	assert_eq(builder.try_place_building("park", Vector2i.ZERO)["reason"], "occupied_footprint")
	assert_eq(builder.try_place_building("park", Vector2i(1, 0))["status"], "applied")
	assert_eq(builder.try_place_building("house", Vector2i(1, 0))["reason"], "occupied_footprint")
	assert_eq(builder.try_place_building("house", Vector2i(2, 0))["status"], "applied")
	assert_eq(builder.try_place_building("park", Vector2i(2, 0))["reason"], "replacement_required")

func test_replace_applies_after_full_validation() -> void:
	builder.try_place_building("house", Vector2i.ZERO)
	var outcome: Dictionary = builder.try_place_building("park", Vector2i.ZERO, 0, true)
	assert_eq(outcome["status"], "applied")
	assert_eq(GameState.building_registry.size(), 1)

func test_road_cannot_offer_or_apply_replacement_over_an_existing_road() -> void:
	assert_eq(builder.try_place_building("road", Vector2i.ZERO).status, "applied")
	var road_bid := int(GameState.cell_to_building[Vector2i.ZERO])
	var occupied: Array[int] = [road_bid]
	assert_false(builder._can_offer_replacement(catalog.get_item_index("road"), occupied))
	var outcome: Dictionary = builder.try_place_building("road", Vector2i.ZERO, 0, true)
	assert_eq(outcome.reason, PlaytestActionResult.OCCUPIED_FOOTPRINT)
	assert_eq(GameState.building_registry.size(), 1)

func test_cash_demand_and_threshold_reasons() -> void:
	economy.quote = {"ok": false, "cost": 30, "have": 20, "reason": "insufficient_cash"}
	assert_eq(builder.try_place_building("park", Vector2i.ZERO)["reason"], "insufficient_cash")
	economy.quote = {"ok": true, "cost": 0, "have": 20, "reason": ""}
	demand.quote = {"ok": false, "bucket_id": "residential", "cost": 5.0, "have": 2.0, "threshold": 0.0, "reason": "insufficient"}
	assert_eq(builder.try_place_building("house", Vector2i.ZERO)["reason"], "insufficient_demand")
	demand.quote["reason"] = "below_threshold"
	demand.quote["threshold"] = 30.0
	assert_eq(builder.try_place_building("house", Vector2i.ZERO)["reason"], "below_demand_threshold")

func test_unique_prerequisite_and_duplicate_reasons() -> void:
	uniques.unique_ids["house"] = true
	uniques.unlocked = false
	uniques.profile.prerequisite_ids = PackedStringArray(["factory"])
	assert_eq(builder.try_place_building("house", Vector2i.ZERO)["reason"], "unmet_prerequisite")
	uniques.placed["factory"] = true
	assert_eq(builder.try_place_building("house", Vector2i.ZERO)["reason"], "below_demand_threshold")
	uniques.placed["house"] = true
	assert_eq(builder.try_place_building("house", Vector2i.ZERO)["reason"], "unique_already_placed")

func test_unknown_building_and_invalid_rotation_reject() -> void:
	assert_eq(builder.try_place_building("missing", Vector2i.ZERO)["reason"], "unknown_building")
	assert_eq(builder.try_place_building("house", Vector2i.ZERO, 4)["reason"], "invalid_rotation")

func test_seeded_pool_and_multi_cell_rotation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var pool_eval: Dictionary = builder.evaluate_placement("houses", Vector2i.ZERO, 0, false, "", rng)
	assert_true(pool_eval["ok"])
	assert_true(pool_eval["details"]["building_id"] in ["house_a", "house_b"])
	var rotated: Dictionary = builder.evaluate_placement("factory", Vector2i(3, 3), 1)
	assert_eq(rotated["details"]["footprint"], [Vector2i(3, 3), Vector2i(3, 2)])

func test_seeded_player_choice_collision_never_commits_excluded_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 19019
	var observed: Dictionary = {}
	for index in 24:
		var outcome: Dictionary = builder.try_place_choice("grass", Vector2i(index, 4),
			0, false, "", rng)
		assert_eq(outcome.status, PlaytestActionResult.STATUS_APPLIED)
		assert_ne(outcome.details.building_id, "grass")
		observed[String(outcome.details.building_id)] = true
	assert_true(observed.has("grass_trees"), "seeded choice reaches the tree variant")
	assert_true(observed.has("grass_flowers"), "seeded choice reaches the flower variant")

func test_player_choice_honours_explicit_variant_but_exact_building_path_remains_available() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 19019
	var choice: Dictionary = builder.try_place_choice("grass", Vector2i(0, 5),
		0, false, "grass_flowers", rng)
	assert_eq(choice.status, PlaytestActionResult.STATUS_APPLIED)
	assert_eq(choice.details.building_id, "grass_flowers")

	var exact: Dictionary = builder.try_place_building("grass", Vector2i(1, 5))
	assert_eq(exact.status, PlaytestActionResult.STATUS_APPLIED)
	assert_eq(exact.details.building_id, "grass",
		"legacy catalogue identity remains addressable only as building_id")

func test_demolition_resolves_satellite_cell() -> void:
	builder.try_place_building("factory", Vector2i.ZERO)
	var outcome: Dictionary = builder.try_demolish_cell(Vector2i(1, 0))
	assert_eq(outcome["status"], "applied")
	assert_eq(GameState.building_registry.size(), 0)
	assert_eq(builder.try_demolish_cell(Vector2i(1, 0))["reason"], "nothing_to_demolish")

func test_rejection_never_partially_spends() -> void:
	GameState.map.cash = 100
	economy.quote = {"ok": true, "cost": 30, "have": 100, "reason": ""}
	demand.quote = {"ok": false, "bucket_id": "residential", "cost": 5.0, "have": 0.0, "threshold": 0.0, "reason": "insufficient"}
	builder.try_place_building("house", Vector2i.ZERO)
	assert_eq(economy.spend_calls, 0)
	assert_eq(demand.spend_calls, 0)
	assert_eq(GameState.map.cash, 100)

func test_story_lock_rejection_is_an_atomic_no_op() -> void:
	uniques.unique_ids["house"] = true
	uniques.forced_decision = {
		"selectable": false, "unlocked": false,
		"reasons": [PlaytestActionResult.WANT_NOT_REVEALED],
		"primary_reason": PlaytestActionResult.WANT_NOT_REVEALED,
	}
	var cells_before := GameState.cell_to_building.duplicate(true)
	var registry_before := GameState.building_registry.duplicate(true)
	var outcome: Dictionary = builder.try_place_building("house", Vector2i.ZERO)
	assert_eq(outcome.reason, PlaytestActionResult.WANT_NOT_REVEALED)
	assert_eq(GameState.cell_to_building, cells_before)
	assert_eq(GameState.building_registry, registry_before)
	assert_eq(economy.spend_calls, 0)
	assert_eq(demand.spend_calls, 0)

func test_replacement_cannot_remove_the_requested_unique_prerequisite() -> void:
	assert_eq(builder.try_place_building("factory", Vector2i.ZERO).status, "applied")
	uniques.unique_ids["house"] = true
	uniques.placed["factory"] = true
	uniques.profile.prerequisite_ids = PackedStringArray(["factory"])
	var before := GameState.building_registry.duplicate(true)
	var outcome: Dictionary = builder.try_place_building("house", Vector2i.ZERO, 0, true)
	assert_eq(outcome.reason, PlaytestActionResult.UNMET_PREREQUISITE)
	assert_has(outcome.details.planned_removal_building_ids, "factory")
	assert_eq(GameState.building_registry, before, "rejected replacement preserves its prerequisite")

func _structure(category: String, capacity: int, footprint: Array[Vector2i] = [Vector2i.ZERO]) -> Structure:
	var structure := Structure.new()
	structure.footprint = footprint
	var profile := BuildingProfile.new()
	profile.category = category
	profile.capacity = capacity
	structure.metadata = [profile]
	return structure

func _road_structure() -> Structure:
	var structure := Structure.new()
	structure.footprint = [Vector2i.ZERO]
	structure.metadata = [RoadMetadata.new()]
	return structure

class StubCatalog extends PluginBase:
	var items: Array[Structure] = []
	var ids: Array[String] = []
	var summaries: Array[Dictionary] = []
	func get_plugin_name() -> String: return "StubCatalog"
	func add_structure(id: String, structure: Structure, pool: String = "",
			palette_excluded: bool = false) -> void:
		structure.pool_id = pool
		ids.append(id)
		items.append(structure)
		summaries.append({"building_id":id, "pool_id":pool,
			"palette_excluded":palette_excluded})
	func get_item_index(id: String) -> int: return ids.find(id)
	func get_id_by_index(index: int) -> String: return ids[index] if index >= 0 and index < ids.size() else ""
	func get_summary_by_index(index: int) -> Dictionary:
		return summaries[index] if index >= 0 and index < summaries.size() else {}
	func get_pool_indices(pool: String) -> Array[int]:
		var result: Array[int] = []
		for i in items.size():
			if items[i].pool_id == pool: result.append(i)
		return result
	func get_player_pool_indices(pool: String) -> Array[int]:
		var result: Array[int] = []
		for i in items.size():
			if items[i].pool_id == pool and not bool(summaries[i].palette_excluded):
				result.append(i)
		return result

class StubEconomy extends PluginBase:
	var quote := {"ok": true, "cost": 0, "have": 1000, "reason": ""}
	var spend_calls := 0
	func get_plugin_name() -> String: return "StubEconomy"
	func quote_cash(_structure: Structure) -> Dictionary: return quote.duplicate(true)
	func try_spend_cash(_structure: Structure) -> Dictionary:
		spend_calls += 1
		GameState.map.cash -= int(quote["cost"])
		return quote.duplicate(true)

class StubDemand extends PluginBase:
	var quote := {"ok": true, "bucket_id": "", "cost": 0.0, "have": 100.0, "threshold": 0.0, "reason": ""}
	var spend_calls := 0
	func get_plugin_name() -> String: return "StubDemand"
	func quote_placement(_structure: Structure) -> Dictionary: return quote.duplicate(true)
	func try_spend(_structure: Structure) -> Dictionary:
		spend_calls += 1
		return quote.duplicate(true)
	func bucket_display_name(id: String) -> String: return id

class StubLand extends PluginBase:
	var blocked: Dictionary = {}
	func get_plugin_name() -> String: return "StubLand"
	func is_allowed(cell: Vector2i) -> bool: return not blocked.has(cell)

class StubUniques extends PluginBase:
	var unique_ids: Dictionary = {}
	var placed: Dictionary = {}
	var unlocked := true
	var profile := UniqueProfile.new()
	var forced_decision: Dictionary = {}
	func get_plugin_name() -> String: return "StubUniques"
	func is_unique(id: String) -> bool: return unique_ids.has(id)
	func is_placed(id: String) -> bool: return placed.has(id)
	func is_unlocked(_id: String) -> bool: return unlocked
	func get_profile(_id: String) -> UniqueProfile: return profile
	func evaluate_unlock(id: String, excluded: Array = []) -> Dictionary:
		if not forced_decision.is_empty():
			return forced_decision.duplicate(true)
		var reasons: Array[String] = []
		if placed.has(id) and id not in excluded:
			reasons.append(PlaytestActionResult.UNIQUE_ALREADY_PLACED)
		var missing: Array[String] = []
		for prerequisite in profile.prerequisite_ids:
			if not placed.has(prerequisite) or prerequisite in excluded:
				missing.append(prerequisite)
		if not missing.is_empty():
			reasons.append(PlaytestActionResult.UNMET_PREREQUISITE)
		elif not unlocked:
			reasons.append(PlaytestActionResult.BELOW_DEMAND_THRESHOLD)
		return {"selectable":reasons.is_empty(), "unlocked":reasons.is_empty(),
			"reasons":reasons, "primary_reason":reasons[0] if not reasons.is_empty() else null,
			"missing_prerequisites":missing}
