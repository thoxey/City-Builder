extends GutTest

## Unit tests for the CharacterSystem plugin.
##
## Stubs Demand (returns injected bucket values) and UniqueRegistry (no-op).
## Plugin is constructed, seeded with three in-memory character defs, and
## driven through GameEvents signals to exercise each transition.

const CharSysCls := preload("res://plugins/character_system/character_system_plugin.gd")

var _plugin: Node
var _stub_demand: Object
var _stub_catalog: Object
var _saved_map: DataMap
var _saved_registry: Dictionary

func before_each() -> void:
	_saved_map = GameState.map
	_saved_registry = GameState.building_registry.duplicate(true)
	GameState.map = DataMap.new()
	GameState.building_registry = {}

	_stub_demand  = _StubDemand.new()
	_stub_catalog = _StubCatalog.new()

	_plugin = CharSysCls.new()
	_plugin._demand  = _stub_demand
	_plugin._catalog = _stub_catalog
	add_child(_plugin)

	# Seed defs directly — skip JSON walk.
	_plugin._defs = {
		"aristocrat_commercial": {
			"character_id": "aristocrat_commercial",
			"associated_bucket": "commercial",
			"arrival_threshold": 10,
			"arrival_requires_tier": 1,
			"want_building_id": "building_members_club",
		},
		"aristocrat_industrial": {
			"character_id": "aristocrat_industrial",
			"associated_bucket": "industrial",
			"arrival_threshold": 10,
			"arrival_requires_tier": 1,
			"want_building_id": "building_crazy_golf",
		},
		"farmer_residential": {
			"character_id": "farmer_residential",
			"associated_bucket": "residential",
			"arrival_threshold": 10,
			"arrival_requires_tier": 1,
			"want_building_id": "building_workshop_shed_house",
		},
	}
	_plugin._seed_initial_states()

func after_each() -> void:
	if _plugin and is_instance_valid(_plugin):
		for sname in ["demand_fulfilled_changed", "unique_placed", "structure_placed", "structure_demolished", "map_loaded"]:
			var cb: Callable
			match sname:
				"demand_fulfilled_changed": cb = _plugin._on_demand_changed
				"unique_placed":  cb = _plugin._on_unique_placed
				"structure_placed": cb = _plugin._on_structure_changed
				"structure_demolished": cb = _plugin._on_structure_demolished
				"map_loaded":     cb = _plugin._on_map_loaded
			if GameEvents[sname].is_connected(cb):
				GameEvents[sname].disconnect(cb)
		_plugin.queue_free()
	_plugin = null
	GameState.map = _saved_map
	GameState.building_registry = _saved_registry

# ── Arrival ───────────────────────────────────────────────────────────────────

func test_arrival_on_threshold_cross() -> void:
	# AUTO_REVEAL_WANT is false from M4 onward: crossing threshold stops at
	# ARRIVED. The modal close path is what advances to WANT_REVEALED.
	watch_signals(GameEvents)
	_emit_demand("commercial", 12.0)

	assert_signal_emitted_with_parameters(GameEvents, "character_arrived", ["aristocrat_commercial"])
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.ARRIVED,
		"arrival no longer auto-advances past ARRIVED")

func test_arrival_ignored_below_threshold() -> void:
	watch_signals(GameEvents)
	_emit_demand("commercial", 5.0)

	assert_signal_not_emitted(GameEvents, "character_arrived")
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.NOT_ARRIVED)

func test_arrival_wrong_bucket_ignored() -> void:
	_emit_demand("residential", 50.0)

	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.NOT_ARRIVED,
		"commercial character ignores housing bucket")
	assert_eq(_plugin.get_state("farmer_residential"), CharSysCls.CharState.ARRIVED,
		"residential character triggers on residential bucket")

func test_simultaneous_arrivals() -> void:
	var order := _ArrivalSink.new()
	GameEvents.character_arrived.connect(order.on_arrived)
	watch_signals(GameEvents)
	_emit_demand("commercial", 20.0)
	_emit_demand("industrial", 20.0)
	_emit_demand("residential", 20.0)
	GameEvents.character_arrived.disconnect(order.on_arrived)

	assert_signal_emit_count(GameEvents, "character_arrived", 3)
	assert_eq(order.ids, ["aristocrat_commercial", "aristocrat_industrial", "farmer_residential"])
	for cid in ["aristocrat_commercial", "aristocrat_industrial", "farmer_residential"]:
		assert_eq(_plugin.get_state(cid), CharSysCls.CharState.ARRIVED)

func test_arrival_fires_once() -> void:
	_emit_demand("commercial", 20.0)

	watch_signals(GameEvents)
	# Subsequent demand ticks above threshold must not re-fire arrival.
	_emit_demand("commercial", 50.0)
	_emit_demand("commercial", 100.0)

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
	_emit_demand("commercial", 20.0)
	_plugin.mark_want_revealed("aristocrat_commercial")

	watch_signals(GameEvents)
	_plugin._on_unique_placed("building_members_club")

	assert_signal_emitted_with_parameters(GameEvents, "character_satisfied", ["aristocrat_commercial"])
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.SATISFIED)

func test_satisfaction_ignores_wrong_building() -> void:
	_emit_demand("commercial", 20.0)

	watch_signals(GameEvents)
	_plugin._on_unique_placed("building_pub")  # not the want

	assert_signal_not_emitted(GameEvents, "character_satisfied")
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.ARRIVED)

func test_satisfaction_requires_arrival_first() -> void:
	# Character hasn't arrived — placing their want shouldn't satisfy them.
	_plugin._on_unique_placed("building_members_club")
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.NOT_ARRIVED)

func test_reveal_reconciles_an_existing_legacy_request_exactly_once() -> void:
	_emit_demand("commercial", 20.0)
	GameState.building_registry = {1:{"structure":0, "anchor":Vector2i.ZERO, "cells":[Vector2i.ZERO]}}
	watch_signals(GameEvents)
	_plugin.mark_want_revealed("aristocrat_commercial")
	_plugin.mark_want_revealed("aristocrat_commercial")
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.SATISFIED)
	assert_signal_emit_count(GameEvents, "character_want_revealed", 1)
	assert_signal_emit_count(GameEvents, "character_satisfied", 1)

func test_load_does_not_satisfy_revealed_character_when_request_is_absent() -> void:
	_plugin._set_state("aristocrat_commercial", CharSysCls.CharState.WANT_REVEALED)
	GameState.building_registry = {}
	_plugin._on_map_loaded(GameState.map)
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.WANT_REVEALED)

# ── Contribute promotion ──────────────────────────────────────────────────────

func test_promote_to_contributes_from_satisfied() -> void:
	_emit_demand("commercial", 20.0)
	_plugin.mark_want_revealed("aristocrat_commercial")
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
	_stub_demand.set_value("commercial", 50.0)

	watch_signals(GameEvents)
	_plugin._recheck_all_arrivals()

	assert_signal_emitted_with_parameters(GameEvents, "character_arrived", ["aristocrat_commercial"])

# ── Persistence ───────────────────────────────────────────────────────────────

func test_state_survives_map_swap() -> void:
	_emit_demand("commercial", 20.0)
	# Swap the map in, like after a load — character state dict lives on DataMap.
	var new_map := DataMap.new()
	new_map.character_states = GameState.map.character_states.duplicate()
	GameState.map = new_map

	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.ARRIVED,
		"state reads from current GameState.map — survives reassign")

func test_arrival_requires_demand_and_placed_tier() -> void:
	_stub_catalog.tiers["commercial"] = 0
	_emit_demand("commercial", 20.0)
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.NOT_ARRIVED)
	assert_eq(_plugin.evaluate_character_gate("aristocrat_commercial")["reasons"], [PlaytestActionResult.REQUIRED_TIER_NOT_REACHED])
	_stub_catalog.tiers["commercial"] = 1
	_plugin._recheck_all_arrivals()
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.ARRIVED)

func test_request_placement_does_not_satisfy_before_reveal() -> void:
	_emit_demand("commercial", 20.0)
	_plugin._on_unique_placed("building_members_club")
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.ARRIVED)

func test_forward_only_state_rejects_regression() -> void:
	_plugin._set_state("aristocrat_commercial", CharSysCls.CharState.SATISFIED)
	_plugin._set_state("aristocrat_commercial", CharSysCls.CharState.ARRIVED)
	assert_eq(_plugin.get_state("aristocrat_commercial"), CharSysCls.CharState.SATISFIED)

func _emit_demand(bucket_id: String, value: float) -> void:
	_stub_demand.set_value(bucket_id, value)
	_plugin._on_demand_changed(bucket_id, value)

# ── Stubs ─────────────────────────────────────────────────────────────────────

class _StubDemand extends PluginBase:
	var _values: Dictionary = {}
	func get_plugin_name() -> String: return "_StubDemand"
	func set_value(type_id: String, v: float) -> void: _values[type_id] = v
	# Recheck path now reads fulfilled demand. Stub returns the same value
	# for both getters since tests pin a single number per bucket.
	func get_value(type_id: String) -> float: return _values.get(type_id, 0.0)
	func get_fulfilled(type_id: String) -> float: return _values.get(type_id, 0.0)

class _StubCatalog extends PluginBase:
	var tiers := {"residential": 1, "industrial": 1, "commercial": 1}
	func get_plugin_name() -> String: return "_StubCatalog"
	func get_bucket_tier_snapshot(bucket_id: String) -> Dictionary:
		return {"attained_tier": tiers.get(bucket_id, 0), "tier_evidence": []}
	func get_item_index(building_id: String) -> int:
		return 0 if building_id == "building_members_club" else -1
	func get_summary_by_id(building_id: String) -> Dictionary:
		return {"display_name": building_id}

class _ArrivalSink extends RefCounted:
	var ids: Array[String] = []
	func on_arrived(character_id: String) -> void: ids.append(character_id)
