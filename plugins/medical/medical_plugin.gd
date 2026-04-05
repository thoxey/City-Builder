extends PluginBase

## Medical plugin.
## Each hour, dispatches one ambulance per facility.
## Route: facility → random incident location → facility (single trip, not looping).

func get_plugin_name() -> String: return "Medical"
func get_dependencies() -> Array[String]: return ["RoadNetwork", "CarManager", "DayNight"]

var _road_network: PluginBase
var _car_manager:  PluginBase
var _day_night:    PluginBase

func inject(deps: Dictionary) -> void:
	_road_network = deps.get("RoadNetwork")
	_car_manager  = deps.get("CarManager")
	_day_night    = deps.get("DayNight")

# ── State ─────────────────────────────────────────────────────────────────────

var _facility_tiles: Array[Vector3i] = []

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	GameEvents.structure_placed.connect(func(_a, _b, _c): _rebuild())
	GameEvents.structure_demolished.connect(func(_a): _rebuild())
	GameEvents.map_loaded.connect(func(_a): _rebuild())
	_day_night.hour_changed.connect(_on_hour)
	_rebuild()

# ── Build ─────────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	_facility_tiles.clear()
	for cell: Vector3i in GameState.gridmap.get_used_cells():
		var sid: int = GameState.gridmap.get_cell_item(cell)
		if sid < 0 or sid >= GameState.structures.size():
			continue
		if GameState.structures[sid].find_metadata(MedicalMetadata) != null:
			_facility_tiles.append(cell)
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

	# Route: facility → incident → facility (not looping — ambulance returns and parks)
	var route: Array[Vector3i] = [incident_tile, facility_tile]
	var jid: int = _car_manager.request_journey(
			facility_tile, route, CarSlot.CarType.AMBULANCE, false)
	if jid < 0:
		push_warning("[Medical] facility %s: failed to dispatch (pool full or no road)" % str(facility_tile))
