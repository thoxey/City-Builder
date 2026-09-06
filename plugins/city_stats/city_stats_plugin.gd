extends PluginBase

const SimulationIntentType := preload("res://scripts/simulation/simulation_intent.gd")

## Thin city statistics registry.
##
## Building-type plugins (Residential, Workplace, …) register CityStatSource /
## CityStatSink objects here.  Each in-game hour DayNight fires hour_changed,
## which triggers one simulation tick:
##   1. Poll every source  → sum supply per type_id
##   2. Poll every sink    → record demand per type_id
##   3. Distribute supply  → call on_fulfilled() on each sink (first-come)
##   4. Compute satisfaction (fulfilled / demanded) per type_id
##   5. Emit stats_ticked so any interested plugin can read the snapshot

signal stats_ticked(supply: Dictionary, demand: Dictionary, satisfaction: Dictionary)

var _performance_debug_logs := OS.get_environment("CITY_BUILDER_PERFORMANCE_DEBUG_LOGS") == "1"

func get_plugin_name() -> String: return "CityStats"
func get_dependencies() -> Array[String]: return ["DayNight", "SimulationTransaction"]

var _day_night: PluginBase
var _simulation_transaction: PluginBase
var _pending_publication: Dictionary = {}

func inject(deps: Dictionary) -> void:
	_day_night = deps.get("DayNight")
	_simulation_transaction = deps.get("SimulationTransaction")

# ── Registry ──────────────────────────────────────────────────────────────────

var _sources: Array = []  # CityStatSource
var _sinks:   Array = []  # CityStatSink
var _satisfaction: Dictionary = {}  # type_id -> float 0–1
var _last_supply_snapshot: Dictionary = {}

func _plugin_ready() -> void:
	if _simulation_transaction:
		_simulation_transaction.register_reducer(&"resources", [&"tick"], _reduce_hour, _commit_hour, 0)
		_simulation_transaction.register_contributor(&"city_stats", [&"resources"], _collect_hour)
		_simulation_transaction.transaction_committed.connect(_publish_committed_hour)
	elif _day_night:
		_day_night.hour_changed.connect(_on_hour)

func _collect_hour(context: Variant, sink: Variant) -> void:
	sink.submit(SimulationIntentType.create("city_stats:%d" % context.absolute_hour, &"city_stats",
		"city", &"resources", &"tick", {"hour":context.clock_hour}, 0, &"set", 0))

func _reduce_hour(intents: Array, _context: Variant) -> Dictionary:
	return {"ok":intents.size() == 1, "reason_code":"invalid_payload",
		"plan":{"hour":float(intents[0].get_payload().hour)} if intents.size() == 1 else {},
		"domains":[&"resources"]}

func _commit_hour(plan: Dictionary, _context: Variant) -> Dictionary:
	_on_hour(float(plan.hour), false)
	return {"ok":true}

func _publish_committed_hour(_change_set: Variant, _ledger: Dictionary) -> void:
	if _pending_publication.is_empty(): return
	stats_ticked.emit(_pending_publication.supply, _pending_publication.demand, _pending_publication.satisfaction)
	_pending_publication.clear()

func register_source(source: CityStatSource) -> void:
	_sources.append(source)

func register_sink(sink: CityStatSink) -> void:
	_sinks.append(sink)

func unregister_source(source: CityStatSource) -> void:
	_sources.erase(source)

func unregister_sink(sink: CityStatSink) -> void:
	_sinks.erase(sink)

## Returns the last satisfaction score (0–1) for a given type_id.
## 1.0 means supply fully met demand; 0.0 means nothing was fulfilled.
## Defaults to 1.0 when no data exists yet (no demand = no shortage).
func get_satisfaction(type_id: String) -> float:
	return _satisfaction.get(type_id, 1.0)

func get_satisfaction_snapshot() -> Dictionary:
	return _satisfaction.duplicate(true)

func get_supply_snapshot() -> Dictionary:
	return _last_supply_snapshot.duplicate(true)

func reset_runtime_state() -> void:
	_satisfaction.clear()

# ── Tick ──────────────────────────────────────────────────────────────────────

func _on_hour(hour: float, publish: bool = true) -> void:
	# --- Poll sources ---
	var supply: Dictionary = {}  # type_id -> int
	for source in _sources:
		var t: String = (source as CityStatSource).get_type_id()
		supply[t] = supply.get(t, 0) + (source as CityStatSource).tick(hour)

	# --- Poll sinks and cache results so we don't call tick() twice ---
	# Each entry: { sink: CityStatSink, type_id: String, requested: int }
	var sink_entries: Array = []
	var demand: Dictionary = {}  # type_id -> int
	for sink in _sinks:
		var t: String = (sink as CityStatSink).get_type_id()
		var requested: int = (sink as CityStatSink).tick(hour)
		sink_entries.append({
			"sink":     sink,
			"type_id":  t,
			"requested": requested,
			"priority": (sink as CityStatSink).priority,
		})
		demand[t] = demand.get(t, 0) + requested

	# --- Sort by priority so lower-priority-value sinks are served first ---
	sink_entries.sort_custom(func(a, b): return a["priority"] < b["priority"])

	# --- Distribute supply ---
	var remaining: Dictionary = {}  # type_id -> int remaining to give out
	for t in demand:
		remaining[t] = supply.get(t, 0)

	var fulfilled_total: Dictionary = {}  # type_id -> int actually given
	for entry in sink_entries:
		var t: String = entry["type_id"]
		var requested: int = entry["requested"]
		var share: int = mini(requested, remaining.get(t, 0))
		remaining[t] = remaining.get(t, 0) - share
		(entry["sink"] as CityStatSink).on_fulfilled(share, requested)
		fulfilled_total[t] = fulfilled_total.get(t, 0) + share

	# --- Satisfaction scores ---
	for t in demand:
		var d: int = demand[t]
		_satisfaction[t] = float(fulfilled_total.get(t, 0)) / float(d) if d > 0 else 1.0

	var snap := _satisfaction.duplicate()
	_last_supply_snapshot = supply.duplicate(true)
	if publish:
		emit_signal("stats_ticked", supply, demand, snap)
	else:
		_pending_publication = {"supply":supply.duplicate(true), "demand":demand.duplicate(true), "satisfaction":snap}

	if _performance_debug_logs:
		print("[CityStats] h=%.0f  supply=%s  demand=%s  sat=%s" % [hour, supply, demand, snap])
