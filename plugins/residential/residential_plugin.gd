extends PluginBase

## Residential building plugin — incremental registration.
##
## Per building, registers with CityStats:
##   • _PopSource   ("population") — supply scaled by overall satisfaction score
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
	_pop_sources.clear()

	for bid in GameState.building_registry:
		var entry: Dictionary = GameState.building_registry[bid]
		var sid: int = entry.get("structure", -1)
		if sid < 0 or sid >= GameState.structures.size(): continue
		var profile := GameState.structures[sid].find_metadata(BuildingProfile) as BuildingProfile
		if not profile or profile.category != "residential": continue
		_register(entry["anchor"], profile.capacity)

func _register(anchor: Vector2i, capacity: int) -> void:
	var pop_src  := _PopSource.new(capacity, _satisfaction)
	_pop_sources[anchor]  = pop_src
	_city_stats.register_source(pop_src)

## Total residential capacity summed across every placed residential building.
func get_total_capacity() -> int:
	var total := 0
	for src in _pop_sources.values():
		total += (src as _PopSource).capacity
	return total

## Current effective population: capacity scaled by last tick's satisfaction.
## Matches the supply figure _PopSource publishes to CityStats each tick.
func get_current_population() -> int:
	var score: float = _satisfaction.get_score() if _satisfaction else 1.0
	return int(get_total_capacity() * score)

func _unregister(anchor: Vector2i) -> void:
	if _pop_sources.has(anchor):
		_city_stats.unregister_source(_pop_sources[anchor])
		_pop_sources.erase(anchor)

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
