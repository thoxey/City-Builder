extends PluginBase

## Police plugin.
## Each hour, spawns a looping patrol car per police station.
## Patrol route: PATROL_STOPS random reachable buildings → returns to station → loops.

const PATROL_STOPS := 4

func get_plugin_name() -> String: return "Police"
func get_dependencies() -> Array[String]: return ["RoadNetwork", "CarManager", "DayNight"]

var _road_network: PluginBase
var _car_manager:  PluginBase
var _day_night:    PluginBase

func inject(deps: Dictionary) -> void:
	_road_network = deps.get("RoadNetwork")
	_car_manager  = deps.get("CarManager")
	_day_night    = deps.get("DayNight")

# ── State ─────────────────────────────────────────────────────────────────────

var _station_tiles:    Array[Vector3i] = []
var _patrol_journey_ids: Array[int]    = []

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	GameEvents.structure_placed.connect(func(_a, _b, _c): _rebuild())
	GameEvents.structure_demolished.connect(func(_a): _rebuild())
	GameEvents.map_loaded.connect(func(_a): _rebuild())
	_day_night.hour_changed.connect(_on_hour)
	_rebuild()

# ── Build ─────────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	# Cancel existing patrols (CarManager already cancelled them on map change,
	# but cancel here too for any non-map-change rebuilds)
	for jid: int in _patrol_journey_ids:
		_car_manager.cancel_journey(jid)
	_patrol_journey_ids.clear()
	_station_tiles.clear()

	for cell: Vector3i in GameState.gridmap.get_used_cells():
		var sid: int = GameState.gridmap.get_cell_item(cell)
		if sid < 0 or sid >= GameState.structures.size():
			continue
		if GameState.structures[sid].find_metadata(PoliceMetadata) != null:
			_station_tiles.append(cell)

	print("[Police] %d station(s)" % _station_tiles.size())

	# Spawn a patrol immediately so cars are visible without waiting for an hour tick
	for station: Vector3i in _station_tiles:
		_spawn_patrol(station)

# ── Hour tick ─────────────────────────────────────────────────────────────────

func _on_hour(_hour: float) -> void:
	for station: Vector3i in _station_tiles:
		_spawn_patrol(station)

# ── Patrol ────────────────────────────────────────────────────────────────────

func _spawn_patrol(station_tile: Vector3i) -> void:
	var building_tiles: Array[Vector3i] = _road_network.get_building_tiles()

	# Pick PATROL_STOPS distinct reachable buildings (excluding the station)
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
	route.append(station_tile)   # return home at end of each loop iteration

	var jid: int = _car_manager.request_journey(
			station_tile, route, CarSlot.CarType.POLICE, true)
	if jid >= 0:
		_patrol_journey_ids.append(jid)
	else:
		push_warning("[Police] station %s: failed to spawn patrol (pool full or no road)" % str(station_tile))
