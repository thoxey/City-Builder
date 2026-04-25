extends GutTest

## Unit tests for the Economy plugin (Phase 1b).
##
## The plugin uses GameState.map.cash as the canonical balance and reads
## BuildingCatalog summaries for cash_cost lookups. Tests stub both surfaces
## directly — no DayNight, no real catalog walk — and exercise the public
## entry points (_on_hour, try_spend_cash, _on_stats_ticked).

const EconomyPluginCls := preload("res://plugins/economy/economy_plugin.gd")

var _economy: Node
var _saved_map: DataMap
var _saved_structures: Array[Structure]
var _saved_registry: Dictionary
var _stub_catalog: Object
var _structures_buf: Array[Structure] = []

func before_each() -> void:
	# Snapshot real GameState so tests can mutate it freely.
	_saved_map = GameState.map
	_saved_structures = GameState.structures
	_saved_registry = GameState.building_registry.duplicate(true)

	GameState.map = DataMap.new()
	_structures_buf = []
	GameState.structures = _structures_buf
	GameState.building_registry = {}

	_stub_catalog = _StubCatalog.new()
	_economy = EconomyPluginCls.new()
	# Skip the full _plugin_ready (which connects to DayNight + map_loaded);
	# inject the catalog stub straight into the field.
	_economy._catalog = _stub_catalog
	add_child(_economy)

func after_each() -> void:
	if _economy and is_instance_valid(_economy):
		_economy.queue_free()
	_economy = null
	GameState.map = _saved_map
	GameState.structures = _saved_structures
	GameState.building_registry = _saved_registry

# ── try_spend_cash ────────────────────────────────────────────────────────────

func test_try_spend_debits_cash_and_emits() -> void:
	GameState.map.cash = 100
	var s := _make_structure_with_cost("park", 30)

	watch_signals(GameEvents)
	var info: Dictionary = _economy.try_spend_cash(s)

	assert_true(info["ok"], "try_spend_cash should succeed when cash >= cost")
	assert_eq(info["cost"], 30)
	assert_eq(info["have"], 100, "have reports pre-spend balance")
	assert_eq(GameState.map.cash, 70, "cash debited by cost")
	assert_signal_emitted(GameEvents, "cash_changed", "spend must publish cash_changed")
	var params: Array = get_signal_parameters(GameEvents, "cash_changed", 0)
	assert_eq(params[0], 70, "emitted amount = post-spend total")
	assert_eq(params[1], -30, "emitted delta = signed change")

func test_try_spend_blocks_when_insufficient() -> void:
	GameState.map.cash = 20
	var s := _make_structure_with_cost("park", 30)

	watch_signals(GameEvents)
	var info: Dictionary = _economy.try_spend_cash(s)

	assert_false(info["ok"], "should block when cash < cost")
	assert_eq(info["cost"], 30)
	assert_eq(info["have"], 20, "have reports current balance for the toast")
	assert_eq(GameState.map.cash, 20, "cash untouched on block")
	assert_signal_not_emitted(GameEvents, "cash_changed", "no emit when blocked")

func test_try_spend_free_for_zero_cost() -> void:
	GameState.map.cash = 50
	var road := _make_structure_with_cost("road", 0)

	watch_signals(GameEvents)
	var info: Dictionary = _economy.try_spend_cash(road)

	assert_true(info["ok"], "zero-cost structures pass through")
	assert_eq(info["cost"], 0)
	assert_eq(GameState.map.cash, 50, "balance untouched")
	assert_signal_not_emitted(GameEvents, "cash_changed")

# ── Tick income / overhead ────────────────────────────────────────────────────

func test_tick_credits_tax_income_from_industrial_output() -> void:
	GameState.map.cash = 0
	_economy.tax_rate = 5

	# Simulate CityStats publishing a fresh supply snapshot for this hour.
	_economy._on_stats_ticked({"industrial_output": 12}, {}, {})

	watch_signals(GameEvents)
	_economy._on_hour(0.0)

	assert_eq(GameState.map.cash, 60, "12 output × 5 tax_rate = 60")
	assert_signal_emitted(GameEvents, "cash_changed")

func test_cash_clamped_at_zero() -> void:
	# Negative cash is impossible via tax income alone, so emulate a debit by
	# stuffing a negative-income hour through the public surface.
	GameState.map.cash = 10
	_economy._apply_delta(-100)

	assert_eq(GameState.map.cash, 0, "negative deltas can't push cash below zero")

func test_tick_emits_signal_with_delta() -> void:
	GameState.map.cash = 50
	_economy.tax_rate = 5
	_economy._on_stats_ticked({"industrial_output": 4}, {}, {})

	watch_signals(GameEvents)
	_economy._on_hour(0.0)

	# income=20, no overhead → +20 → 70
	var params: Array = get_signal_parameters(GameEvents, "cash_changed", 0)
	assert_eq(params[0], 70, "amount = new cash total")
	assert_eq(params[1], 20, "delta = signed change for the hour")

# ── get_cash_cost catalog lookup ──────────────────────────────────────────────

func test_get_cash_cost_reads_catalog_summary() -> void:
	var park := _make_structure_with_cost("park", 25)
	assert_eq(_economy.get_cash_cost(park), 25, "lookup via summary index")

	var unknown := Structure.new()  # not in GameState.structures → not in catalog
	assert_eq(_economy.get_cash_cost(unknown), 0, "unknown structure → 0 (free)")

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_structure_with_cost(bid: String, cost: int) -> Structure:
	# Stage the structure in GameState.structures so its index lookup works,
	# then mirror it into the stub catalog summary so cost resolves.
	var s := Structure.new()
	_structures_buf.append(s)
	GameState.structures = _structures_buf
	_stub_catalog.summaries.append({"building_id": bid, "cash_cost": cost})
	return s

## Stand-in for the BuildingCatalog plugin — only get_summary() is exercised.
## Extends PluginBase because the Economy plugin's `_catalog` field is typed
## to PluginBase and Godot enforces that on assignment.
class _StubCatalog extends PluginBase:
	var summaries: Array = []
	func get_plugin_name() -> String: return "_StubCatalog"
	func get_summary() -> Array:
		return summaries
