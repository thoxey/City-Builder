extends PluginBase

## Medical plugin.
## Each hour, dispatches one ambulance per facility.
## Also registers with CityStats:
##   • _HealthSource ("health")  — coverage provided by this facility
##   • _BudgetSink   ("budget")  — running cost per facility per hour

const HEALTH_PER_FACILITY := 100  # health units provided per facility
const BUDGET_COST         := 40   # budget units consumed per facility per hour

func get_plugin_name() -> String: return "Medical"
func get_dependencies() -> Array[String]: return ["RoadNetwork", "CarManager", "DayNight", "CityStats"]

var _road_network: PluginBase
var _car_manager:  PluginBase
var _day_night:    PluginBase
var _city_stats:   PluginBase

func inject(deps: Dictionary) -> void:
	_road_network = deps.get("RoadNetwork")
	_car_manager  = deps.get("CarManager")
	_day_night    = deps.get("DayNight")
	_city_stats   = deps.get("CityStats")

# ── State ─────────────────────────────────────────────────────────────────────

var _facility_tiles:  Array[Vector3i] = []
var _health_sources:  Dictionary      = {}  # Vector3i → _HealthSource
var _budget_sinks:    Dictionary      = {}  # Vector3i → _BudgetSink

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	GameEvents.structure_placed.connect(func(_a, _b, _c): _rebuild())
	GameEvents.structure_demolished.connect(func(_a): _rebuild())
	GameEvents.map_loaded.connect(func(_a): _rebuild())
	_day_night.hour_changed.connect(_on_hour)
	_rebuild()

# ── Rebuild ───────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	# Unregister old CityStats entries
	for src in _health_sources.values(): _city_stats.unregister_source(src)
	for snk in _budget_sinks.values():   _city_stats.unregister_sink(snk)
	_health_sources.clear()
	_budget_sinks.clear()

	_facility_tiles.clear()

	for cell: Vector3i in GameState.gridmap.get_used_cells():
		var sid: int = GameState.gridmap.get_cell_item(cell)
		if sid < 0 or sid >= GameState.structures.size(): continue
		if GameState.structures[sid].find_metadata(MedicalMetadata) == null: continue

		_facility_tiles.append(cell)

		var src := _HealthSource.new(HEALTH_PER_FACILITY)
		var snk := _BudgetSink.new(BUDGET_COST)
		_health_sources[cell] = src
		_budget_sinks[cell]   = snk
		_city_stats.register_source(src)
		_city_stats.register_sink(snk)

	print("[Medical] %d facility(ies)" % _facility_tiles.size())

# ── Hour tick ─────────────────────────────────────────────────────────────────

func _on_hour(_hour: float) -> void:
	for facility: Vector3i in _facility_tiles:
		_dispatch_ambulance(facility)

# ── Dispatch ──────────────────────────────────────────────────────────────────

func _dispatch_ambulance(facility_tile: Vector3i) -> void:
	var building_tiles: Array[Vector3i] = _road_network.get_building_tiles()

	var candidates: Array[Vector3i] = []
	for t: Vector3i in building_tiles:
		if t != facility_tile and not _road_network.get_stops_for_building(t).is_empty():
			candidates.append(t)

	if candidates.is_empty():
		push_warning("[Medical] facility %s: no reachable incident locations" % str(facility_tile))
		return

	var incident_tile: Vector3i = candidates[randi() % candidates.size()]
	var route: Array[Vector3i] = [incident_tile, facility_tile]
	var jid: int = _car_manager.request_journey(
			facility_tile, route, CarSlot.CarType.AMBULANCE, false)
	if jid < 0:
		push_warning("[Medical] facility %s: failed to dispatch" % str(facility_tile))

# ── Inner classes ─────────────────────────────────────────────────────────────

class _HealthSource extends CityStatSource:
	var capacity: int
	func _init(cap: int) -> void: capacity = cap
	func get_type_id() -> String: return "health"
	func tick(_hour: float) -> int: return capacity

class _BudgetSink extends CityStatSink:
	var cost: int
	func _init(c: int) -> void: cost = c
	func get_type_id() -> String: return "budget"
	func tick(_hour: float) -> int: return cost
