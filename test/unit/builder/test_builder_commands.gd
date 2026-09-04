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

func _structure(category: String, capacity: int, footprint: Array[Vector2i] = [Vector2i.ZERO]) -> Structure:
	var structure := Structure.new()
	structure.footprint = footprint
	var profile := BuildingProfile.new()
	profile.category = category
	profile.capacity = capacity
	structure.metadata = [profile]
	return structure

class StubCatalog extends PluginBase:
	var items: Array[Structure] = []
	var ids: Array[String] = []
	func get_plugin_name() -> String: return "StubCatalog"
	func add_structure(id: String, structure: Structure, pool: String = "") -> void:
		structure.pool_id = pool
		ids.append(id)
		items.append(structure)
	func get_item_index(id: String) -> int: return ids.find(id)
	func get_id_by_index(index: int) -> String: return ids[index] if index >= 0 and index < ids.size() else ""
	func get_pool_indices(pool: String) -> Array[int]:
		var result: Array[int] = []
		for i in items.size():
			if items[i].pool_id == pool: result.append(i)
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
	func get_plugin_name() -> String: return "StubUniques"
	func is_unique(id: String) -> bool: return unique_ids.has(id)
	func is_placed(id: String) -> bool: return placed.has(id)
	func is_unlocked(_id: String) -> bool: return unlocked
	func get_profile(_id: String) -> UniqueProfile: return profile
