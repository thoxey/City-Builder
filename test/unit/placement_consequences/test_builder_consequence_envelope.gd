extends GutTest

const BuilderCls := preload("res://scripts/builder.gd")

var builder: Node
var catalog: StubCatalog
var land: StubLand
var economy: StubEconomy
var demand: StubDemand
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
	GameState._next_building_id = 1
	catalog = StubCatalog.new()
	catalog.add_structure("home", _structure("residential"))
	catalog.add_structure("factory", _structure("industrial", [Vector2i.ZERO, Vector2i(1, 0)]))
	GameState.structures = catalog.items
	land = StubLand.new()
	economy = StubEconomy.new()
	demand = StubDemand.new()
	builder = BuilderCls.new()
	builder.structures = catalog.items
	builder._catalog = catalog
	builder._land = land
	builder._economy = economy
	builder._demand = demand
	builder._community = StubCommunity.new()
	builder._attractiveness = StubAttractiveness.new()

func after_each() -> void:
	builder.free(); catalog.free(); land.free(); economy.free(); demand.free()
	GameState.map = saved_map
	GameState.structures = saved_structures
	GameState.cell_to_building = saved_cells
	GameState.building_registry = saved_registry
	GameState._next_building_id = saved_next_id

func test_invalid_uses_canonical_reason_and_does_not_run_domain_quotes() -> void:
	land.blocked[Vector2i(4, 3)] = true
	var before := GameState.building_registry.duplicate(true)
	var quote: Dictionary = builder.evaluate_placement_consequences(0, Vector2i(4, 3))
	assert_eq(quote.status, "invalid")
	assert_eq(quote.reason, PlaytestActionResult.OUTSIDE_BUILDABLE_AREA)
	assert_eq(GameState.building_registry, before)
	assert_eq(economy.spend_calls, 0)
	assert_eq(demand.spend_calls, 0)

func test_rotated_multicell_quote_uses_canonical_footprint() -> void:
	var quote: Dictionary = builder.evaluate_placement_consequences(1, Vector2i(3, 3), 1)
	assert_eq(quote.status, "valid")
	assert_eq(quote.footprint, [{"x":3,"z":3}, {"x":3,"z":2}])
	assert_eq(quote.community.quality_deltas.beauty, 2.0)

func test_replaceable_overlap_is_valid_but_requires_confirmation() -> void:
	GameState.building_registry[7] = {"anchor":Vector2i.ZERO,"structure":0,"orientation":0,"cells":[Vector2i.ZERO]}
	GameState.cell_to_building[Vector2i.ZERO] = 7
	var quote: Dictionary = builder.evaluate_placement_consequences(1, Vector2i.ZERO)
	assert_eq(quote.status, "replacement")
	assert_true(quote.requires_confirmation)
	assert_eq(quote.replacement.removed_buildings[0].internal_id, 7)
	assert_eq(economy.spend_calls, 0)
	assert_eq(demand.spend_calls, 0)

func test_one_hundred_quotes_do_not_mutate_authority_or_emit_durable_events() -> void:
	watch_signals(GameEvents)
	GameState.map.cash = 321
	var registry_before: Dictionary = GameState.building_registry.duplicate(true)
	var cells_before: Dictionary = GameState.cell_to_building.duplicate(true)
	var next_id_before := GameState._next_building_id
	for i in 100:
		builder.evaluate_placement_consequences(0, Vector2i(i % 10, i / 10))
	assert_eq(GameState.map.cash, 321)
	assert_eq(GameState.building_registry, registry_before)
	assert_eq(GameState.cell_to_building, cells_before)
	assert_eq(GameState._next_building_id, next_id_before)
	assert_eq(economy.spend_calls, 0)
	assert_eq(demand.spend_calls, 0)
	assert_signal_not_emitted(GameEvents, "structure_placed")
	assert_signal_not_emitted(GameEvents, "structure_demolished")

func _structure(category: String, footprint: Array[Vector2i] = [Vector2i.ZERO]) -> Structure:
	var structure := Structure.new()
	structure.footprint = footprint
	var profile := BuildingProfile.new()
	profile.category = category
	structure.metadata = [profile]
	return structure

class StubCatalog extends PluginBase:
	var items: Array[Structure] = []
	var ids: Array[String] = []
	func get_plugin_name() -> String: return "StubCatalog"
	func add_structure(id: String, structure: Structure) -> void: ids.append(id); items.append(structure)
	func get_item_index(id: String) -> int: return ids.find(id)
	func get_id_by_index(index: int) -> String: return ids[index] if index >= 0 and index < ids.size() else ""
	func get_pool_indices(_pool: String) -> Array[int]: return []

class StubLand extends PluginBase:
	var blocked := {}
	func get_plugin_name() -> String: return "StubLand"
	func is_allowed(cell: Vector2i) -> bool: return not blocked.has(cell)

class StubEconomy extends PluginBase:
	var spend_calls := 0
	func get_plugin_name() -> String: return "StubEconomy"
	func quote_cash(_structure: Structure) -> Dictionary: return {"ok":true,"cost":5,"have":100,"reason":""}
	func try_spend_cash(_structure: Structure) -> Dictionary: spend_calls += 1; return {"ok":true}

class StubDemand extends PluginBase:
	var spend_calls := 0
	func get_plugin_name() -> String: return "StubDemand"
	func quote_placement(_structure: Structure) -> Dictionary: return {"ok":true,"bucket_id":"residential","cost":3.0,"have":100.0,"threshold":0.0,"reason":""}
	func try_spend(_structure: Structure) -> Dictionary: spend_calls += 1; return {"ok":true}

class StubCommunity extends PluginBase:
	func get_plugin_name() -> String: return "StubCommunity"
	func quote_placement_consequences(_index: int, _anchor: Vector2i, _removed: Array = [], _rotation: int = 0) -> Dictionary:
		return {"quality_deltas":{"opportunity":0.0,"liveability":0.0,"beauty":2.0,"belonging":0.0},"affected_resident_count":1,"affected_home_count":1,"uncertainties":[]}

class StubAttractiveness extends PluginBase:
	func get_plugin_name() -> String: return "StubAttractiveness"
	func quote_placement_consequences(_index: int, _anchor: Vector2i, _footprint: Array, _removed: Array = []) -> Dictionary:
		return {"city_delta":4,"affected_tile_count":2,"changed_tiles":[],"uncertainties":[]}
