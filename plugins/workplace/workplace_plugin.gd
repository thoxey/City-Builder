extends PluginBase

## Workplace building plugin — incremental registration.
##
## Per building, registers with CityStats:
##   • _WorkerSink    ("population", priority 10)  — workers during open hours
##   • _OutputSource  ("industrial_output")        — raw production signal
##   • _BudgetSource  ("budget")                   — income from employed workers
##
## Industrial output is the raw "what factories produced" number that the
## Demand plugin's commercial bucket tracks, and the Phase 1b tax system will
## multiply by a tax rate to yield cash income.

const OUTPUT_PER_WORKER := 1  # output units produced per filled worker slot per hour
const BUDGET_PER_WORKER := 2  # budget units earned per filled worker slot per hour

func get_plugin_name() -> String: return "Workplace"
func get_dependencies() -> Array[String]: return ["CityStats"]

var _city_stats: PluginBase

func inject(deps: Dictionary) -> void:
	_city_stats = deps.get("CityStats")

# ── State — keyed by anchor Vector2i ─────────────────────────────────────────

var _worker_sinks:   Dictionary = {}
var _output_sources: Dictionary = {}
var _budget_sources: Dictionary = {}

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	GameEvents.structure_placed.connect(_on_placed)
	GameEvents.structure_demolished.connect(_on_demolished)
	GameEvents.map_loaded.connect(_on_map_loaded)
	_on_map_loaded(null)

# ── Incremental handlers ──────────────────────────────────────────────────────

func _on_placed(pos: Vector3i, idx: int, _orient: int) -> void:
	var profile := GameState.structures[idx].find_metadata(BuildingProfile) as BuildingProfile
	if not profile or profile.category != "workplace": return
	_register(Vector2i(pos.x, pos.z), profile.capacity, profile.active_start, profile.active_end)

func _on_demolished(pos: Vector3i) -> void:
	_unregister(Vector2i(pos.x, pos.z))

func _on_map_loaded(_map) -> void:
	for a in _worker_sinks:   _city_stats.unregister_sink(_worker_sinks[a])
	for a in _output_sources: _city_stats.unregister_source(_output_sources[a])
	for a in _budget_sources: _city_stats.unregister_source(_budget_sources[a])
	_worker_sinks.clear()
	_output_sources.clear()
	_budget_sources.clear()

	for bid in GameState.building_registry:
		var entry: Dictionary = GameState.building_registry[bid]
		var sid: int = entry.get("structure", -1)
		if sid < 0 or sid >= GameState.structures.size(): continue
		var profile := GameState.structures[sid].find_metadata(BuildingProfile) as BuildingProfile
		if not profile or profile.category != "workplace": continue
		_register(entry["anchor"], profile.capacity, profile.active_start, profile.active_end)

func _register(anchor: Vector2i, capacity: int, start: float, end: float) -> void:
	var sink     := _WorkerSink.new(capacity, start, end)
	var output   := _OutputSource.new(sink, OUTPUT_PER_WORKER)
	var budget   := _BudgetSource.new(sink, BUDGET_PER_WORKER)
	_worker_sinks[anchor]   = sink
	_output_sources[anchor] = output
	_budget_sources[anchor] = budget
	_city_stats.register_sink(sink)
	_city_stats.register_source(output)
	_city_stats.register_source(budget)

func _unregister(anchor: Vector2i) -> void:
	if _worker_sinks.has(anchor):
		_city_stats.unregister_sink(_worker_sinks[anchor])
		_worker_sinks.erase(anchor)
	if _output_sources.has(anchor):
		_city_stats.unregister_source(_output_sources[anchor])
		_output_sources.erase(anchor)
	if _budget_sources.has(anchor):
		_city_stats.unregister_source(_budget_sources[anchor])
		_budget_sources.erase(anchor)

## Sum of industrial output across every registered workplace this tick.
## Equal to last_fulfilled × OUTPUT_PER_WORKER per building. Reads last tick's
## fulfilment, so callers running in the same hour_changed pass see a one-tick
## lag behind placement (intentional — matches the budget flow).
func get_total_output() -> int:
	var total := 0
	for sink in _worker_sinks.values():
		total += (sink as _WorkerSink).last_fulfilled * OUTPUT_PER_WORKER
	return total

# ── Inner classes ─────────────────────────────────────────────────────────────

## Worker demand — draws from population pool during open hours.
## Priority 10 ensures workers are served before commercial visitors (priority 100).
class _WorkerSink extends CityStatSink:
	var capacity:       int
	var active_start:   float
	var active_end:     float
	var last_fulfilled: int = 0

	func _init(cap: int, start: float, end: float) -> void:
		capacity     = cap
		active_start = start
		active_end   = end
		priority = 10

	func get_type_id() -> String: return "population"

	func tick(hour: float) -> int:
		return capacity if _in_window(hour, active_start, active_end) else 0

	func on_fulfilled(fulfilled: int, _requested: int) -> void:
		last_fulfilled = fulfilled

## Industrial output — raw production signal from filled worker slots.
## Drives commercial demand and (via a later tax rate) tax income.
class _OutputSource extends CityStatSource:
	var _sink: _WorkerSink
	var _rate: int

	func _init(sink: _WorkerSink, rate: int) -> void:
		_sink = sink
		_rate = rate

	func get_type_id() -> String: return "industrial_output"

	func tick(_hour: float) -> int:
		return _sink.last_fulfilled * _rate

## Budget source — income generated by filled worker slots (one-tick lag from on_fulfilled).
class _BudgetSource extends CityStatSource:
	var _sink: _WorkerSink
	var _rate: int

	func _init(sink: _WorkerSink, rate: int) -> void:
		_sink = sink
		_rate = rate

	func get_type_id() -> String: return "budget"

	func tick(_hour: float) -> int:
		return _sink.last_fulfilled * _rate
