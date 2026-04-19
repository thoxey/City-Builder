extends GutTest

## Unit tests for the EventSystem plugin and its condition DSL.
##
## Events are injected via `set_events_for_test()` rather than read from disk
## so tests don't depend on the data/events/ tree. DSL tests hit the static
## EventCondition.evaluate() directly.

const EventSysCls := preload("res://plugins/event_system/event_system_plugin.gd")
const Condition   := preload("res://scripts/event_condition.gd")

var _plugin: Node
var _saved_map: DataMap

func before_each() -> void:
	_saved_map = GameState.map
	GameState.map = DataMap.new()

	_plugin = EventSysCls.new()
	add_child(_plugin)
	# Don't call _plugin_ready — that walks disk + connects signals. Tests wire
	# up signals manually so they can fire exactly the triggers they need.

func after_each() -> void:
	if _plugin and is_instance_valid(_plugin):
		_plugin.queue_free()
	_plugin = null
	GameState.map = _saved_map

# ── Loading / indexing ────────────────────────────────────────────────────────

func test_load_and_index() -> void:
	var events := {
		"evt_a": {
			"event_id": "evt_a",
			"event_type": "dialogue",
			"trigger": {"event": "character_arrived", "character_id": "cid_a"},
			"payload": {}
		},
		"evt_b": {
			"event_id": "evt_b",
			"event_type": "newspaper",
			"trigger": {"event": "patron_landmark_completed", "patron_id": "pid_x"},
			"payload": {}
		},
		"evt_c": {
			"event_id": "evt_c",
			"event_type": "dialogue",
			"trigger": {"event": "character_arrived", "character_id": "cid_b"},
			"payload": {}
		},
	}
	_plugin.set_events_for_test(events)
	assert_eq(_plugin.all_event_ids().size(), 3)
	var arrivals: Array = _plugin.events_for_trigger("character_arrived")
	assert_eq(arrivals.size(), 2, "two arrival events indexed")
	assert_true(arrivals.has("evt_a"))
	assert_true(arrivals.has("evt_c"))

# ── Dispatch ──────────────────────────────────────────────────────────────────

func test_dispatch_on_trigger_fires_resolved_signal() -> void:
	var events := {
		"arr_a": {
			"event_id": "arr_a",
			"event_type": "dialogue",
			"trigger": {"event": "character_arrived", "character_id": "cid_a"},
			"payload": {"tree_id": "t1"}
		}
	}
	_plugin.set_events_for_test(events)

	var sink := _Sink.new()
	_plugin.event_resolved.connect(sink.on_resolved)

	# Drive the dispatch directly (bypasses GameEvents wiring).
	_plugin._dispatch("character_arrived", {"character_id": "cid_a"})

	assert_eq(sink.records.size(), 1, "event_resolved fired once")
	assert_eq(sink.records[0].get("event_id", ""), "arr_a")

func test_dispatch_filter_matches_character_id() -> void:
	var events := {
		"arr_a": {
			"event_id": "arr_a",
			"event_type": "dialogue",
			"trigger": {"event": "character_arrived", "character_id": "cid_a"},
			"payload": {}
		},
		"arr_b": {
			"event_id": "arr_b",
			"event_type": "dialogue",
			"trigger": {"event": "character_arrived", "character_id": "cid_b"},
			"payload": {}
		}
	}
	_plugin.set_events_for_test(events)
	var sink := _Sink.new()
	_plugin.event_resolved.connect(sink.on_resolved)

	_plugin._dispatch("character_arrived", {"character_id": "cid_b"})

	assert_eq(sink.records.size(), 1)
	assert_eq(sink.records[0].get("event_id", ""), "arr_b", "only the matching character's event fires")

# ── enabled_if ────────────────────────────────────────────────────────────────

func test_enabled_if_false_suppresses() -> void:
	GameState.map.cash = 100
	var events := {
		"gated": {
			"event_id": "gated",
			"event_type": "dialogue",
			"trigger": {"event": "character_arrived"},
			"enabled_if": "cash >= 500",
			"payload": {}
		}
	}
	_plugin.set_events_for_test(events)

	var sink := _Sink.new()
	_plugin.event_resolved.connect(sink.on_resolved)

	_plugin._dispatch("character_arrived", {})
	assert_eq(sink.records.size(), 0, "enabled_if=false suppresses dispatch")

func test_enabled_if_true_dispatches() -> void:
	GameState.map.cash = 900
	var events := {
		"gated": {
			"event_id": "gated",
			"event_type": "dialogue",
			"trigger": {"event": "character_arrived"},
			"enabled_if": "cash >= 500",
			"payload": {}
		}
	}
	_plugin.set_events_for_test(events)
	var sink := _Sink.new()
	_plugin.event_resolved.connect(sink.on_resolved)

	_plugin._dispatch("character_arrived", {})
	assert_eq(sink.records.size(), 1)

# ── Effects ───────────────────────────────────────────────────────────────────

func test_effect_set_flag_writes_flags_dict() -> void:
	_plugin.apply_effect({"kind": "set_flag", "target": "met_alice"})
	assert_true(bool(GameState.map.flags.get("met_alice", false)))

func test_effect_fire_event_cascades() -> void:
	var events := {
		"src": {
			"event_id": "src",
			"event_type": "dialogue",
			"trigger": {"event": "manual"},
			"payload": {}
		},
		"news": {
			"event_id": "news",
			"event_type": "newspaper",
			"trigger": {"event": "manual"},
			"payload": {}
		}
	}
	_plugin.set_events_for_test(events)
	var sink := _Sink.new()
	_plugin.event_resolved.connect(sink.on_resolved)

	_plugin.apply_effect({"kind": "fire_event", "target": "news"})
	assert_eq(sink.records.size(), 1)
	assert_eq(sink.records[0].get("event_id", ""), "news")

func test_unknown_effect_returns_false() -> void:
	var ok: bool = _plugin.apply_effect({"kind": "not_a_real_kind"})
	assert_false(ok)

func test_event_count_bumps_on_dispatch() -> void:
	var events := {
		"once": {
			"event_id": "once",
			"event_type": "dialogue",
			"trigger": {"event": "character_arrived"},
			"payload": {}
		}
	}
	_plugin.set_events_for_test(events)
	_plugin._dispatch("character_arrived", {})
	_plugin._dispatch("character_arrived", {})
	assert_eq(int(GameState.map.event_counts.get("once", 0)), 2)

# ── DSL coverage ──────────────────────────────────────────────────────────────

func test_dsl_empty_expr_is_true() -> void:
	assert_true(Condition.evaluate("", {}))

func test_dsl_cash_cmp() -> void:
	var ctx := {"cash": 500}
	assert_true(Condition.evaluate("cash >= 500", ctx))
	assert_false(Condition.evaluate("cash > 500", ctx))
	assert_true(Condition.evaluate("cash == 500", ctx))
	assert_false(Condition.evaluate("cash < 500", ctx))

func test_dsl_flag_token() -> void:
	var ctx := {"flags": {"met_alice": true}}
	assert_true(Condition.evaluate("flag.met_alice", ctx))
	assert_false(Condition.evaluate("flag.unknown", ctx))

func test_dsl_has_placed_token() -> void:
	var ctx := {"placed_ids": {"building_pub": true}}
	assert_true(Condition.evaluate("has_placed:building_pub", ctx))
	assert_false(Condition.evaluate("has_placed:building_theatre", ctx))

func test_dsl_state_token() -> void:
	var ctx := {"character_states": {"cid_a": 1}}  # ARRIVED == 1
	assert_true(Condition.evaluate("state.cid_a == \"ARRIVED\"", ctx))
	assert_false(Condition.evaluate("state.cid_a == \"SATISFIED\"", ctx))

func test_dsl_demand_and_count() -> void:
	var ctx := {
		"demand": {"housing_demand": 42.5},
		"event_counts": {"evt_a": 3},
	}
	assert_true(Condition.evaluate("demand.housing_demand >= 30", ctx))
	assert_false(Condition.evaluate("demand.housing_demand > 100", ctx))
	assert_true(Condition.evaluate("count.evt_a >= 3", ctx))
	assert_false(Condition.evaluate("count.evt_a > 5", ctx))

func test_dsl_and_or_combination() -> void:
	var ctx := {"cash": 1000, "flags": {"met_alice": true}}
	assert_true(Condition.evaluate("cash >= 500 && flag.met_alice", ctx))
	assert_false(Condition.evaluate("cash >= 500 && flag.unknown", ctx))
	assert_true(Condition.evaluate("cash < 500 || flag.met_alice", ctx))
	assert_false(Condition.evaluate("cash < 500 || flag.unknown", ctx))

func test_dsl_parens() -> void:
	var ctx := {"cash": 100, "flags": {"a": true, "b": false}}
	assert_true(Condition.evaluate("(flag.a || flag.b) && cash >= 100", ctx))
	assert_false(Condition.evaluate("flag.a && (cash >= 200 || flag.b)", ctx))

func test_dsl_unknown_token_returns_false() -> void:
	assert_false(Condition.evaluate("wiggle.wobble >= 4", {}))

# ── Helpers ───────────────────────────────────────────────────────────────────

class _Sink:
	extends RefCounted
	var records: Array = []
	func on_resolved(rec: Dictionary) -> void:
		records.append(rec)
