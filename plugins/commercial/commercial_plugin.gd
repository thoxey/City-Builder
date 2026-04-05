extends PluginBase

## Commercial building plugin — incremental registration.
##
## Per building, registers with CityStats:
##   • _VisitorSink ("population", priority 100) — customers during open hours
##
## Priority 100 means commercial is served after workplaces (priority 10),
## so residents fill jobs before filling leisure activities.

func get_plugin_name() -> String: return "Commercial"
func get_dependencies() -> Array[String]: return ["CityStats"]

var _city_stats: PluginBase

func inject(deps: Dictionary) -> void:
	_city_stats = deps.get("CityStats")

# ── State — keyed by anchor Vector2i ─────────────────────────────────────────

var _visitor_sinks: Dictionary = {}

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	GameEvents.structure_placed.connect(_on_placed)
	GameEvents.structure_demolished.connect(_on_demolished)
	GameEvents.map_loaded.connect(_on_map_loaded)
	_on_map_loaded(null)

# ── Incremental handlers ──────────────────────────────────────────────────────

func _on_placed(pos: Vector3i, idx: int, _orient: int) -> void:
	var profile := GameState.structures[idx].find_metadata(BuildingProfile) as BuildingProfile
	if not profile or profile.category != "commercial": return
	_register(Vector2i(pos.x, pos.z), profile.capacity, profile.active_start, profile.active_end)

func _on_demolished(pos: Vector3i) -> void:
	_unregister(Vector2i(pos.x, pos.z))

func _on_map_loaded(_map) -> void:
	for a in _visitor_sinks: _city_stats.unregister_sink(_visitor_sinks[a])
	_visitor_sinks.clear()

	for bid in GameState.building_registry:
		var entry: Dictionary = GameState.building_registry[bid]
		var sid: int = entry.get("structure", -1)
		if sid < 0 or sid >= GameState.structures.size(): continue
		var profile := GameState.structures[sid].find_metadata(BuildingProfile) as BuildingProfile
		if not profile or profile.category != "commercial": continue
		_register(entry["anchor"], profile.capacity, profile.active_start, profile.active_end)

func _register(anchor: Vector2i, capacity: int, start: float, end: float) -> void:
	var sink := _VisitorSink.new(capacity, start, end)
	_visitor_sinks[anchor] = sink
	_city_stats.register_sink(sink)

func _unregister(anchor: Vector2i) -> void:
	if _visitor_sinks.has(anchor):
		_city_stats.unregister_sink(_visitor_sinks[anchor])
		_visitor_sinks.erase(anchor)

# ── Inner class ───────────────────────────────────────────────────────────────

## Visitor demand — draws from population pool during commercial hours.
## Served after workers (priority 100 > 10).
class _VisitorSink extends CityStatSink:
	var capacity:     int
	var active_start: float
	var active_end:   float
	var last_fulfilled: int = 0

	func _init(cap: int, start: float, end: float) -> void:
		capacity     = cap
		active_start = start
		active_end   = end
		priority = 100

	func get_type_id() -> String: return "population"

	func tick(hour: float) -> int:
		return capacity if _in_window(hour, active_start, active_end) else 0

	func on_fulfilled(fulfilled: int, _requested: int) -> void:
		last_fulfilled = fulfilled
