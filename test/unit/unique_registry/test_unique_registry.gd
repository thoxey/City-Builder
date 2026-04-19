extends GutTest

## Unit tests for the UniqueRegistry plugin.
##
## Stubs BuildingCatalog + Demand to avoid walking disk JSONs during tests.
## Exercises: indexing, placement tracking, threshold gating, prereq chain,
## one-of-a-kind guard, demolition reopens the slot, landmark multi-prereqs.

const UniqueRegistryCls := preload("res://plugins/unique_registry/unique_registry_plugin.gd")

var _reg: Node
var _stub_catalog: Object
var _stub_demand: Object
var _saved_registry: Dictionary

func before_each() -> void:
	_saved_registry = GameState.building_registry.duplicate(true)
	GameState.building_registry = {}

	_stub_catalog = _StubCatalog.new()
	_stub_demand = _StubDemand.new()
	_reg = UniqueRegistryCls.new()
	_reg._catalog = _stub_catalog
	_reg._demand = _stub_demand
	add_child(_reg)
	# _plugin_ready wires the signal handlers + runs _index_uniques etc.
	_reg._plugin_ready()

func after_each() -> void:
	if _reg and is_instance_valid(_reg):
		for signal_name in ["structure_placed", "structure_demolished", "demand_changed", "map_loaded"]:
			var callable: Callable
			match signal_name:
				"structure_placed":     callable = _reg._on_structure_placed
				"structure_demolished": callable = _reg._on_structure_demolished
				"demand_changed":       callable = _reg._on_demand_changed
				"map_loaded":           callable = _reg._on_map_loaded
			if GameEvents[signal_name].is_connected(callable):
				GameEvents[signal_name].disconnect(callable)
		_reg.queue_free()
	_reg = null
	GameState.building_registry = _saved_registry

# ── Indexing ──────────────────────────────────────────────────────────────────

func test_indexing_counts_chains_wants_landmarks() -> void:
	_stub_catalog.register_unique(0, "building_pub", "commercial", 1, "aristocrat", "aristocrat_commercial", "chain", 10, [])
	_stub_catalog.register_unique(1, "building_nightclub", "commercial", 3, "aristocrat", "aristocrat_commercial", "chain", 60, ["building_pub"])
	_stub_catalog.register_unique(2, "building_members_club", "commercial", 0, "aristocrat", "aristocrat_commercial", "want", 60, ["building_nightclub"])
	_stub_catalog.register_unique(3, "building_theatre", "residential", 0, "aristocrat", "", "landmark", 0, ["building_members_club"])

	_reg._index_uniques()

	assert_eq(_reg.get_all_profiles().size(), 4)
	assert_true(_reg.is_unique("building_pub"))
	assert_true(_reg.is_unique("building_theatre"))
	assert_false(_reg.is_unique("building_small_a"))

# ── Threshold gating ──────────────────────────────────────────────────────────

func test_threshold_blocks_when_demand_below() -> void:
	_stub_catalog.register_unique(0, "building_pub", "commercial", 1, "aristocrat", "aristocrat_commercial", "chain", 10, [])
	_reg._index_uniques()
	_stub_demand.set_value("commercial_demand", 5.0)
	_reg._refresh_unlocks()

	assert_false(_reg.is_unlocked("building_pub"))

func test_threshold_passes_when_demand_at_or_above() -> void:
	_stub_catalog.register_unique(0, "building_pub", "commercial", 1, "aristocrat", "aristocrat_commercial", "chain", 10, [])
	_reg._index_uniques()
	_stub_demand.set_value("commercial_demand", 12.0)
	_reg._refresh_unlocks()

	assert_true(_reg.is_unlocked("building_pub"))

# ── Prerequisite chain ────────────────────────────────────────────────────────

func test_tier2_locked_until_tier1_placed() -> void:
	_stub_catalog.register_unique(0, "building_pub", "commercial", 1, "aristocrat", "aristocrat_commercial", "chain", 10, [])
	_stub_catalog.register_unique(1, "building_restaurant", "commercial", 2, "aristocrat", "aristocrat_commercial", "chain", 30, ["building_pub"])
	_reg._index_uniques()
	_stub_demand.set_value("commercial_demand", 50.0)
	_reg._refresh_unlocks()

	assert_true(_reg.is_unlocked("building_pub"), "T1 has no prereqs")
	assert_false(_reg.is_unlocked("building_restaurant"), "T2 locked while T1 unplaced")

	# Place the T1
	GameEvents.structure_placed.emit(Vector3i(0, 0, 0), 0, 0)

	assert_true(_reg.is_placed("building_pub"))
	assert_false(_reg.is_unlocked("building_pub"), "placed uniques are not unlockable again")
	assert_true(_reg.is_unlocked("building_restaurant"), "T2 now unlocked")

# ── One-of-a-kind guard ───────────────────────────────────────────────────────

func test_place_marks_unique_placed_exactly_once() -> void:
	_stub_catalog.register_unique(0, "building_pub", "commercial", 1, "aristocrat", "aristocrat_commercial", "chain", 10, [])
	_reg._index_uniques()

	watch_signals(GameEvents)
	GameEvents.structure_placed.emit(Vector3i(1, 0, 2), 0, 0)

	assert_eq(_reg.placed_count(), 1)
	assert_signal_emit_count(GameEvents, "unique_placed", 1)

# ── Demolish reopens the slot ─────────────────────────────────────────────────

func test_demolish_clears_placement_and_re_unlocks() -> void:
	_stub_catalog.register_unique(0, "building_pub", "commercial", 1, "aristocrat", "aristocrat_commercial", "chain", 10, [])
	_reg._index_uniques()
	_stub_demand.set_value("commercial_demand", 50.0)
	_reg._refresh_unlocks()

	GameEvents.structure_placed.emit(Vector3i(1, 0, 2), 0, 0)
	assert_false(_reg.is_unlocked("building_pub"))

	watch_signals(GameEvents)
	GameEvents.structure_demolished.emit(Vector3i(1, 0, 2))

	assert_false(_reg.is_placed("building_pub"))
	assert_true(_reg.is_unlocked("building_pub"), "demand still high → re-unlocked")
	assert_signal_emitted(GameEvents, "unique_removed")

# ── Landmark requires all three wants ─────────────────────────────────────────

func test_landmark_needs_all_prereqs() -> void:
	_stub_catalog.register_unique(0, "building_members_club",  "commercial", 0, "aristocrat", "aristocrat_commercial",  "want", 0, [])
	_stub_catalog.register_unique(1, "building_crazy_golf",    "industrial", 0, "aristocrat", "aristocrat_industrial",  "want", 0, [])
	_stub_catalog.register_unique(2, "building_pirate_radio",  "residential", 0, "aristocrat", "aristocrat_residential", "want", 0, [])
	_stub_catalog.register_unique(3, "building_theatre",       "residential", 0, "aristocrat", "",                       "landmark", 0,
		["building_members_club", "building_crazy_golf", "building_pirate_radio"])
	_reg._index_uniques()
	_reg._refresh_unlocks()

	assert_false(_reg.is_unlocked("building_theatre"), "no wants placed → landmark locked")

	GameEvents.structure_placed.emit(Vector3i(0, 0, 0), 0, 0)  # members_club
	GameEvents.structure_placed.emit(Vector3i(1, 0, 0), 1, 0)  # crazy_golf
	assert_false(_reg.is_unlocked("building_theatre"), "2/3 wants still locks the landmark")

	GameEvents.structure_placed.emit(Vector3i(2, 0, 0), 2, 0)  # pirate_radio
	assert_true(_reg.is_unlocked("building_theatre"), "all 3 wants placed → landmark unlocks")

# ── unique_unlocked fires once per transition ─────────────────────────────────

func test_unique_unlocked_fires_once_per_flip() -> void:
	_stub_catalog.register_unique(0, "building_pub", "commercial", 1, "aristocrat", "aristocrat_commercial", "chain", 10, [])
	_reg._index_uniques()

	# Start below threshold.
	_stub_demand.set_value("commercial_demand", 5.0)
	_reg._refresh_unlocks()
	assert_false(_reg.is_unlocked("building_pub"))

	watch_signals(GameEvents)
	# Cross threshold — expect one emit.
	_stub_demand.set_value("commercial_demand", 12.0)
	_reg._refresh_unlocks()
	_reg._refresh_unlocks()  # Idempotent — second refresh must NOT re-emit.

	assert_signal_emit_count(GameEvents, "unique_unlocked", 1)

# ── Non-unique placements are ignored ─────────────────────────────────────────

func test_non_unique_placement_ignored() -> void:
	_stub_catalog.register_unique(0, "building_pub", "commercial", 1, "aristocrat", "aristocrat_commercial", "chain", 10, [])
	_stub_catalog.register_non_unique(1, "building_small_a")
	_reg._index_uniques()

	GameEvents.structure_placed.emit(Vector3i(4, 0, 5), 1, 0)  # generic small_a

	assert_eq(_reg.placed_count(), 0, "non-uniques don't count toward placed")

# ── Stubs ─────────────────────────────────────────────────────────────────────

class _StubCatalog extends PluginBase:
	var structures: Array = []           # parallel to summaries; each wraps a Structure
	var summaries: Array = []
	var _id_by_idx: Dictionary = {}      # int -> building_id

	func get_plugin_name() -> String: return "_StubCatalog"

	func register_unique(idx: int, bid: String, bucket: String, tier: int,
			patron: String, character: String, role: String,
			threshold: int, prereqs: Array) -> void:
		var u := UniqueProfile.new()
		u.bucket = bucket
		u.tier = tier
		u.patron_id = patron
		u.character_id = character
		u.chain_role = role
		u.prerequisite_threshold = threshold
		var arr := PackedStringArray()
		for p in prereqs:
			arr.append(String(p))
		u.prerequisite_ids = arr

		var s := Structure.new()
		var meta: Array[StructureMetadata] = [u]
		s.metadata = meta
		_ensure_slot(idx)
		structures[idx] = s
		summaries[idx] = {"building_id": bid}
		_id_by_idx[idx] = bid

	func register_non_unique(idx: int, bid: String) -> void:
		var s := Structure.new()
		_ensure_slot(idx)
		structures[idx] = s
		summaries[idx] = {"building_id": bid}
		_id_by_idx[idx] = bid

	func _ensure_slot(idx: int) -> void:
		while structures.size() <= idx:
			structures.append(null)
			summaries.append({})

	func get_all() -> Array[Structure]:
		var out: Array[Structure] = []
		for s in structures:
			out.append(s)
		return out

	func get_summary() -> Array:
		return summaries

	func get_id_by_index(idx: int) -> String:
		return _id_by_idx.get(idx, "")


class _StubDemand extends PluginBase:
	var _values: Dictionary = {}  # type_id -> float
	func get_plugin_name() -> String: return "_StubDemand"
	func set_value(type_id: String, v: float) -> void: _values[type_id] = v
	func get_value(type_id: String) -> float:
		return _values.get(type_id, 0.0)
	# Mirror the real static mapping.
	func bucket_for_category(category: String) -> String:
		match category:
			"residential": return "housing_demand"
			"workplace":   return "industrial_demand"
			"industrial":  return "industrial_demand"
			"commercial":  return "commercial_demand"
			_:             return ""
