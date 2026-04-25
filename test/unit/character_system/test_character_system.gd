extends GutTest

## Unit tests for the CharacterSystem plugin.
##
## Stubs Demand (returns injected bucket values) and UniqueRegistry (no-op).
## Plugin is constructed, seeded with three in-memory character defs, and
## driven through GameEvents signals to exercise each transition.

const CharSysCls := preload("res://plugins/character_system/character_system_plugin.gd")

var _plugin: Node
var _stub_demand: Object
var _stub_uniques: Object
var _saved_map: DataMap

func before_each() -> void:
	_saved_map = GameState.map
	GameState.map = DataMap.new()

	_stub_demand  = _StubDemand.new()
	_stub_uniques = _StubUniques.new()

	_plugin = CharSysCls.new()
	_plugin._demand  = _stub_demand
	_plugin._uniques = _stub_uniques
	add_child(_plugin)

	# Seed defs directly — skip JSON walk.
	_plugin._defs = {
		"aristocrat_commercial": {
			"character_id": "aristocrat_commercial",
			"associated_bucket": "commercial",
			"arrival_threshold": 10,
			"want_building_id": "building_members_club",
		},
		"aristocrat_industrial": {
			"character_id": "aristocrat_industrial",
			"associated_bucket": "industrial",
			"arrival_threshold": 10,
			"want_building_id": "building_crazy_golf",
		},
		"farmer_residential": {
			"character_id": "farmer_residential",
			"associated_bucket": "residential",
			"arrival_threshold": 10,
			"want_building_id": "building_workshop_shed_house",
		},
	}
	_plugin._seed_initial_states()

func after_each() -> void:
	if _plugin and is_instance_valid(_plugin):
		for sname in ["demand_unserved_changed", "unique_placed", "map_loaded"]:
			var cb: Callable
			match sname:
				"demand_unserved_changed": cb = _plugin._on_demand_changed
				"unique_placed":  cb = _plugin._on_unique_placed
				"map_loaded":     cb = _plugin._on_map_loaded
			if GameEvents[sname].is_connected(cb):
				GameEvents[sname].disconnect(cb)
		_plugin.queue_free()
	_plugin = null
	GameState.map = _saved_map

# ── Arrival ───────────────────────────────────────────────────────────────────

func test_arrival_on_threshold_cross() -> void:
	# AUTO_REVEAL_WANT is false from M4 onward: crossing threshold stops at
	# ARRIVED. The modal close path is what advances to WANT_REVEALED.
	watch_signals(GameEvents)
	_plugin._on_demand_changed("commercial_demand", 12.0)

	assert_signal_emitted_with_parameters(GameEvents, "character_arrived", ["aristocrat_commercial"])
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.ARRIVED,
		"arrival no longer auto-advances past ARRIVED")

func test_arrival_ignored_below_threshold() -> void:
	watch_signals(GameEvents)
	_plugin._on_demand_changed("commercial_demand", 5.0)

	assert_signal_not_emitted(GameEvents, "character_arrived")
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.NOT_ARRIVED)

func test_arrival_wrong_bucket_ignored() -> void:
	_plugin._on_demand_changed("housing_demand", 50.0)

	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.NOT_ARRIVED,
		"commercial character ignores housing bucket")
	assert_eq(_plugin.get_state("farmer_residential"), CharSysCls.CharState.ARRIVED,
		"residential character triggers on housing_demand")

func test_simultaneous_arrivals() -> void:
	watch_signals(GameEvents)
	_plugin._on_demand_changed("commercial_demand", 20.0)
	_plugin._on_demand_changed("industrial_demand", 20.0)
	_plugin._on_demand_changed("housing_demand", 20.0)

	assert_signal_emit_count(GameEvents, "character_arrived", 3)
	for cid in ["aristocrat_commercial", "aristocrat_industrial", "farmer_residential"]:
		assert_eq(_plugin.get_state(cid), CharSysCls.CharState.ARRIVED)

func test_arrival_fires_once() -> void:
	_plugin._on_demand_changed("commercial_demand", 20.0)

	watch_signals(GameEvents)
	# Subsequent demand ticks above threshold must not re-fire arrival.
	_plugin._on_demand_changed("commercial_demand", 50.0)
	_plugin._on_demand_changed("commercial_demand", 100.0)

	assert_signal_not_emitted(GameEvents, "character_arrived")

# ── Want reveal ───────────────────────────────────────────────────────────────

func test_auto_reveal_skipped_if_already_arrived_manually() -> void:
	# Simulate the Phase 5 flow: arrival without auto-reveal.
	_plugin._set_state("aristocrat_commercial", CharSysCls.CharState.ARRIVED)

	watch_signals(GameEvents)
	_plugin.mark_want_revealed("aristocrat_commercial")

	assert_signal_emitted_with_parameters(GameEvents, "character_want_revealed", ["aristocrat_commercial"])
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.WANT_REVEALED)

func test_mark_want_revealed_noop_if_not_arrived() -> void:
	_plugin.mark_want_revealed("aristocrat_commercial")
	# Still NOT_ARRIVED — can't reveal without first arriving.
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.NOT_ARRIVED)

# ── Satisfaction ──────────────────────────────────────────────────────────────

func test_satisfied_on_want_placement() -> void:
	_plugin._on_demand_changed("commercial_demand", 20.0)  # reaches WANT_REVEALED

	watch_signals(GameEvents)
	_plugin._on_unique_placed("building_members_club")

	assert_signal_emitted_with_parameters(GameEvents, "character_satisfied", ["aristocrat_commercial"])
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.SATISFIED)

func test_satisfaction_ignores_wrong_building() -> void:
	_plugin._on_demand_changed("commercial_demand", 20.0)

	watch_signals(GameEvents)
	_plugin._on_unique_placed("building_pub")  # not the want

	assert_signal_not_emitted(GameEvents, "character_satisfied")
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.ARRIVED)

func test_satisfaction_requires_arrival_first() -> void:
	# Character hasn't arrived — placing their want shouldn't satisfy them.
	_plugin._on_unique_placed("building_members_club")
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.NOT_ARRIVED)

# ── Contribute promotion ──────────────────────────────────────────────────────

func test_promote_to_contributes_from_satisfied() -> void:
	_plugin._on_demand_changed("commercial_demand", 20.0)
	_plugin._on_unique_placed("building_members_club")
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.SATISFIED)

	_plugin.promote_to_contributes("aristocrat_commercial")
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.CONTRIBUTES_TO_LANDMARK)

func test_promote_noop_from_wrong_state() -> void:
	# Not SATISFIED → promotion is a no-op
	_plugin.promote_to_contributes("aristocrat_commercial")
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.NOT_ARRIVED)

# ── Recheck arrivals at boot (seed-demand-100 case) ───────────────────────────

func test_recheck_fires_arrival_when_demand_above_at_boot() -> void:
	_stub_demand.set_value("commercial_demand", 50.0)

	watch_signals(GameEvents)
	_plugin._recheck_all_arrivals()

	assert_signal_emitted_with_parameters(GameEvents, "character_arrived", ["aristocrat_commercial"])

# ── Persistence ───────────────────────────────────────────────────────────────

func test_state_survives_map_swap() -> void:
	_plugin._on_demand_changed("commercial_demand", 20.0)
	# Swap the map in, like after a load — character state dict lives on DataMap.
	var new_map := DataMap.new()
	new_map.character_states = GameState.map.character_states.duplicate()
	GameState.map = new_map

	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.ARRIVED,
		"state reads from current GameState.map — survives reassign")

# ── Stubs ─────────────────────────────────────────────────────────────────────

class _StubDemand extends PluginBase:
	var _values: Dictionary = {}
	func get_plugin_name() -> String: return "_StubDemand"
	func set_value(type_id: String, v: float) -> void: _values[type_id] = v
	func get_value(type_id: String) -> float: return _values.get(type_id, 0.0)

class _StubUniques extends PluginBase:
	func get_plugin_name() -> String: return "_StubUniques"
