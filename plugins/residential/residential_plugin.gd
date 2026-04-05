extends PluginBase

## Residential building plugin — incremental registration.
##
## Per building, registers with CityStats:
##   • _PopSource   ("population") — supply scaled by overall satisfaction score
##   • _SafetySink  ("safety")     — demands safety coverage proportional to capacity
##   • _HealthSink  ("health")     — demands health coverage proportional to capacity
##
## The satisfaction feedback is one-tick delayed (reads last tick's score), which
## is intentional — it creates a stable feedback loop rather than oscillation.

func get_plugin_name() -> String: return "Residential"
func get_dependencies() -> Array[String]: return ["CityStats", "Satisfaction"]

var _city_stats:   PluginBase
var _satisfaction: PluginBase

func inject(deps: Dictionary) -> void:
	_city_stats   = deps.get("CityStats")
	_satisfaction = deps.get("Satisfaction")

# ── State — keyed by anchor Vector2i ─────────────────────────────────────────

var _pop_sources:  Dictionary = {}
var _safety_sinks: Dictionary = {}
var _health_sinks: Dictionary = {}

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	GameEvents.structure_placed.connect(_on_placed)
	GameEvents.structure_demolished.connect(_on_demolished)
	GameEvents.map_loaded.connect(_on_map_loaded)
	_on_map_loaded(null)

# ── Incremental handlers ──────────────────────────────────────────────────────

func _on_placed(pos: Vector3i, idx: int, _orient: int) -> void:
	var profile := GameState.structures[idx].find_metadata(BuildingProfile) as BuildingProfile
	if not profile or profile.category != "residential":
		return
	_register(Vector2i(pos.x, pos.z), profile.capacity)

func _on_demolished(pos: Vector3i) -> void:
	_unregister(Vector2i(pos.x, pos.z))

func _on_map_loaded(_map) -> void:
	for a in _pop_sources:  _city_stats.unregister_source(_pop_sources[a])
	for a in _safety_sinks: _city_stats.unregister_sink(_safety_sinks[a])
	for a in _health_sinks: _city_stats.unregister_sink(_health_sinks[a])
	_pop_sources.clear()
	_safety_sinks.clear()
	_health_sinks.clear()

	for bid in GameState.building_registry:
		var entry: Dictionary = GameState.building_registry[bid]
		var sid: int = entry.get("structure", -1)
		if sid < 0 or sid >= GameState.structures.size(): continue
		var profile := GameState.structures[sid].find_metadata(BuildingProfile) as BuildingProfile
		if not profile or profile.category != "residential": continue
		_register(entry["anchor"], profile.capacity)

func _register(anchor: Vector2i, capacity: int) -> void:
	var pop_src  := _PopSource.new(capacity, _satisfaction)
	var saf_sink := _SafetySink.new(capacity)
	var hlt_sink := _HealthSink.new(capacity)
	_pop_sources[anchor]  = pop_src
	_safety_sinks[anchor] = saf_sink
	_health_sinks[anchor] = hlt_sink
	_city_stats.register_source(pop_src)
	_city_stats.register_sink(saf_sink)
	_city_stats.register_sink(hlt_sink)

func _unregister(anchor: Vector2i) -> void:
	if _pop_sources.has(anchor):
		_city_stats.unregister_source(_pop_sources[anchor])
		_pop_sources.erase(anchor)
	if _safety_sinks.has(anchor):
		_city_stats.unregister_sink(_safety_sinks[anchor])
		_safety_sinks.erase(anchor)
	if _health_sinks.has(anchor):
		_city_stats.unregister_sink(_health_sinks[anchor])
		_health_sinks.erase(anchor)

# ── Inner classes ─────────────────────────────────────────────────────────────

## Population supply — available residents, scaled by last tick's satisfaction.
class _PopSource extends CityStatSource:
	var capacity:      int
	var _satisfaction  # Satisfaction plugin ref

	func _init(cap: int, sat) -> void:
		capacity     = cap
		_satisfaction = sat

	func get_type_id() -> String: return "population"

	func tick(_hour: float) -> int:
		var score: float = _satisfaction.get_score() if _satisfaction else 1.0
		return int(capacity * score)

## Safety demand — always active, proportional to residential headcount.
class _SafetySink extends CityStatSink:
	var capacity: int
	func _init(cap: int) -> void: capacity = cap
	func get_type_id() -> String: return "safety"
	func tick(_hour: float) -> int: return capacity

## Health demand — always active, proportional to residential headcount.
class _HealthSink extends CityStatSink:
	var capacity: int
	func _init(cap: int) -> void: capacity = cap
	func get_type_id() -> String: return "health"
	func tick(_hour: float) -> int: return capacity
