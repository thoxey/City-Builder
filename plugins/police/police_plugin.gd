extends PluginBase

## Police plugin.
## Each hour, spawns a looping patrol car per police station.
## Also registers with CityStats:
##   • _SafetySource ("safety")  — coverage provided by this station
##   • _BudgetSink   ("budget")  — running cost per station per hour

const PATROL_STOPS       := 4
const SAFETY_PER_STATION := 100  # safety units provided per station
const BUDGET_COST        := 30   # budget units consumed per station per hour

func get_plugin_name() -> String: return "Police"
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

var _station_tiles:      Array[Vector3i] = []
var _patrol_journey_ids: Array[int]      = []
var _safety_sources:     Dictionary      = {}  # Vector3i → _SafetySource
var _budget_sinks:       Dictionary      = {}  # Vector3i → _BudgetSink

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	GameEvents.structure_placed.connect(func(_a, _b, _c): _rebuild())
	GameEvents.structure_demolished.connect(func(_a): _rebuild())
	GameEvents.map_loaded.connect(func(_a): _rebuild())
	_day_night.hour_changed.connect(_on_hour)
	_rebuild()

# ── Rebuild — traffic routes require a full rescan; CityStats is rebuilt alongside ──

func _rebuild() -> void:
	# Unregister old CityStats entries
	for src in _safety_sources.values(): _city_stats.unregister_source(src)
	for snk in _budget_sinks.values():   _city_stats.unregister_sink(snk)
	_safety_sources.clear()
	_budget_sinks.clear()

	# Cancel existing patrols
	for jid: int in _patrol_journey_ids:
		_car_manager.cancel_journey(jid)
	_patrol_journey_ids.clear()
	_station_tiles.clear()

	for cell: Vector3i in GameState.gridmap.get_used_cells():
		var sid: int = GameState.gridmap.get_cell_item(cell)
		if sid < 0 or sid >= GameState.structures.size(): continue
		if GameState.structures[sid].find_metadata(PoliceMetadata) == null: continue

		_station_tiles.append(cell)

		var src := _SafetySource.new(SAFETY_PER_STATION)
		var snk := _BudgetSink.new(BUDGET_COST)
		_safety_sources[cell] = src
		_budget_sinks[cell]   = snk
		_city_stats.register_source(src)
		_city_stats.register_sink(snk)

	print("[Police] %d station(s)" % _station_tiles.size())

	for station: Vector3i in _station_tiles:
		_spawn_patrol(station)

# ── Hour tick ─────────────────────────────────────────────────────────────────

func _on_hour(_hour: float) -> void:
	for station: Vector3i in _station_tiles:
		_spawn_patrol(station)

# ── Patrol ────────────────────────────────────────────────────────────────────

func _spawn_patrol(station_tile: Vector3i) -> void:
	var building_tiles: Array[Vector3i] = _road_network.get_building_tiles()

	var candidates: Array[Vector3i] = []
	for t: Vector3i in building_tiles:
		if t != station_tile and not _road_network.get_stops_for_building(t).is_empty():
			candidates.append(t)

	if candidates.is_empty():
		push_warning("[Police] station %s: no reachable destinations" % str(station_tile))
		return

	candidates.shuffle()
	var route: Array[Vector3i] = []
	for t: Vector3i in candidates.slice(0, mini(PATROL_STOPS, candidates.size())):
		route.append(t)
	route.append(station_tile)

	var jid: int = _car_manager.request_journey(
			station_tile, route, CarSlot.CarType.POLICE, true)
	if jid >= 0:
		_patrol_journey_ids.append(jid)
	else:
		push_warning("[Police] station %s: failed to spawn patrol" % str(station_tile))

# ── Inner classes ─────────────────────────────────────────────────────────────

class _SafetySource extends CityStatSource:
	var capacity: int
	func _init(cap: int) -> void: capacity = cap
	func get_type_id() -> String: return "safety"
	func tick(_hour: float) -> int: return capacity

class _BudgetSink extends CityStatSink:
	var cost: int
	func _init(c: int) -> void: cost = c
	func get_type_id() -> String: return "budget"
	func tick(_hour: float) -> int: return cost
