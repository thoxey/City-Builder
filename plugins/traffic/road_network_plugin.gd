extends PluginBase

## Road Network — builds and exposes the road graph, walk graph, and building stops.
## Pure infrastructure: no cars, no simulation. All vehicle plugins depend on this.

const LANE_OFFSET := 0.2
const BASE_SPEED  := 3.0   # tiles/sec at speed_limit 30

var _graph:      Dictionary = {}   # Vector3i → Array[Vector3i]  (road tiles only)
var _walk_graph: Dictionary = {}   # Vector3i → Array[Vector3i]  (all placed tiles)
var _building_tiles:      Array[Vector3i] = []
var _building_stops:      Array[Vector3i] = []   # flat: road tiles adjacent to any building
var _building_road_stops: Dictionary = {}         # building_tile → Array[Vector3i]

func get_plugin_name() -> String: return "RoadNetwork"
func get_dependencies() -> Array[String]: return []

# ── Public API ────────────────────────────────────────────────────────────────

func get_road_graph() -> Dictionary:
	return _graph

func get_walk_graph() -> Dictionary:
	return _walk_graph

func get_building_tiles() -> Array[Vector3i]:
	return _building_tiles

func get_stops_for_building(tile: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var stored = _building_road_stops.get(tile)
	if stored:
		result.assign(stored)
	return result

func road_meta_for(sid: int) -> RoadMetadata:
	return _road_meta_for(sid)

func is_building_sid(sid: int) -> bool:
	return _is_building(sid)

func get_edge_cost(from: Vector3i, to: Vector3i) -> float:
	return _edge_cost(from, to)

func get_lane_position(tile: Vector3i, dir: Vector2i) -> Vector3:
	return _lane_position(tile, dir)

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	GameEvents.structure_placed.connect(func(_a, _b, _c): _rebuild())
	GameEvents.structure_demolished.connect(func(_a): _rebuild())
	GameEvents.map_loaded.connect(func(_a): _rebuild())
	_rebuild()

# ── Build ─────────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	_build_graph()
	_build_walk_graph()
	_find_building_stops()
	print("[RoadNetwork] road tiles: %d | walk tiles: %d | building stops: %d" % [
			_graph.size(), _walk_graph.size(), _building_stops.size()])

func _build_graph() -> void:
	_graph.clear()
	for cell in GameState.gridmap.get_used_cells():
		var road_meta := _road_meta_for(GameState.gridmap.get_cell_item(cell))
		if not road_meta:
			continue
		var orientation := GameState.gridmap.get_cell_item_orientation(cell)
		var conns := road_meta.get_world_connections(orientation, GameState.gridmap)
		var neighbors: Array[Vector3i] = []
		for conn in conns:
			var nb := Vector3i(cell.x + conn.x, 0, cell.z + conn.y)
			if _connects_back(nb, Vector2i(-conn.x, -conn.y)):
				neighbors.append(nb)
		_graph[cell] = neighbors

func _connects_back(tile: Vector3i, from_dir: Vector2i) -> bool:
	var road_meta := _road_meta_for(GameState.gridmap.get_cell_item(tile))
	if not road_meta:
		return false
	var orientation := GameState.gridmap.get_cell_item_orientation(tile)
	return from_dir in road_meta.get_world_connections(orientation, GameState.gridmap)

func _build_walk_graph() -> void:
	_walk_graph.clear()
	var occupied: Dictionary = {}
	for cell in GameState.gridmap.get_used_cells():
		occupied[cell] = true
	for cell in GameState.gridmap.get_used_cells():
		var neighbors: Array[Vector3i] = []
		for offset: Vector3i in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
			var nb: Vector3i = cell + offset
			if occupied.has(nb):
				neighbors.append(nb)
		_walk_graph[cell] = neighbors

func _find_building_stops() -> void:
	_building_tiles.clear()
	_building_stops.clear()
	_building_road_stops.clear()

	var visited_bids: Array[int] = []

	for cell in GameState.gridmap.get_used_cells():
		if not _is_building(GameState.gridmap.get_cell_item(cell)):
			continue

		var cell_2d := Vector2i(cell.x, cell.z)
		var bid: int = GameState.cell_to_building.get(cell_2d, -1)
		if bid in visited_bids:
			continue
		visited_bids.append(bid)

		_building_tiles.append(cell)

		var all_cells: Array = GameState.building_registry.get(bid, {}).get("cells", [cell_2d])
		var stops: Array[Vector3i] = []
		for c2d in all_cells:
			var c3d := Vector3i(c2d.x, 0, c2d.y)
			for offset: Vector3i in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
				var nb: Vector3i = c3d + offset
				if _graph.has(nb) and not nb in stops:
					stops.append(nb)
					if not nb in _building_stops:
						_building_stops.append(nb)
		_building_road_stops[cell] = stops

# ── Edge cost ─────────────────────────────────────────────────────────────────

func _edge_cost(_from: Vector3i, to: Vector3i) -> float:
	var road_meta := _road_meta_for(GameState.gridmap.get_cell_item(to))
	if not road_meta:
		return 1.0
	return 30.0 / float(road_meta.speed_limit)

# ── Lane helpers ──────────────────────────────────────────────────────────────

func _lane_position(tile: Vector3i, dir: Vector2i) -> Vector3:
	var base := Vector3(tile.x, 0.1, tile.z)
	if dir == Vector2i.ZERO:
		return base
	var left := Vector3(dir.y, 0.0, -dir.x).normalized() * LANE_OFFSET
	return base + left

# ── Metadata helpers ──────────────────────────────────────────────────────────

func _road_meta_for(sid: int) -> RoadMetadata:
	if sid < 0 or sid >= GameState.structures.size():
		return null
	return GameState.structures[sid].find_metadata(RoadMetadata) as RoadMetadata

func _is_building(sid: int) -> bool:
	if sid < 0 or sid >= GameState.structures.size():
		return false
	return GameState.structures[sid].find_metadata(BuildingMetadata) != null
