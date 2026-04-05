extends PluginBase

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

func get_plugin_name() -> String: return "CityStats"
func get_dependencies() -> Array[String]: return ["DayNight"]

var _day_night: PluginBase

func inject(deps: Dictionary) -> void:
	_day_night = deps.get("DayNight")

# ── Registry ──────────────────────────────────────────────────────────────────

var _sources: Array = []  # CityStatSource
var _sinks:   Array = []  # CityStatSink
var _satisfaction: Dictionary = {}  # type_id -> float 0–1

func _plugin_ready() -> void:
	if _day_night:
		_day_night.hour_changed.connect(_on_hour)

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

# ── Tick ──────────────────────────────────────────────────────────────────────

func _on_hour(hour: float) -> void:
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
	emit_signal("stats_ticked", supply, demand, snap)

	if OS.is_debug_build():
		print("[CityStats] h=%.0f  supply=%s  demand=%s  sat=%s" % [hour, supply, demand, snap])
