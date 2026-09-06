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
var _component_by_cell: Dictionary = {}            # road tile -> stable component id
var _components: Dictionary = {}                   # component id -> sorted road tiles
var _access_by_building: Dictionary = {}           # internal building id -> access evidence
var _revision: int = 0
var _route_cache: Dictionary = {}                   # origin>destination -> detached route result
var _internal_id_by_anchor: Dictionary = {}         # Vector2i anchor -> stable internal id
var _route_cache_hits: int = 0
var _route_cache_misses: int = 0

const TOWN_HALL_BUILDING_ID := "building_town_hall"

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

func get_revision() -> int:
	return _revision

func get_route_cache_stats() -> Dictionary:
	return {
		"hits": _route_cache_hits,
		"misses": _route_cache_misses,
		"entries": _route_cache.size(),
		"anchor_entries": _internal_id_by_anchor.size(),
	}

func get_internal_id_for_anchor(anchor: Vector2i) -> int:
	if _internal_id_by_anchor.has(anchor):
		return int(_internal_id_by_anchor[anchor])
	# Unit fixtures and startup ordering can query before the first projection;
	# pay the stable scan once, then keep the same O(1) runtime path.
	var ids := GameState.building_registry.keys()
	ids.sort()
	for raw_id in ids:
		if GameState.building_registry[raw_id].get("anchor", Vector2i.ZERO) == anchor:
			_internal_id_by_anchor[anchor] = int(raw_id)
			return int(raw_id)
	return -1

func get_town_hall_internal_id() -> int:
	var catalog := PluginManager.get_plugin("BuildingCatalog")
	var ids := GameState.building_registry.keys()
	ids.sort()
	for internal_id_raw in ids:
		var sid := int(GameState.building_registry[internal_id_raw].get("structure", -1))
		if catalog and String(catalog.get_id_by_index(sid)) == TOWN_HALL_BUILDING_ID:
			return int(internal_id_raw)
	return -1

func get_rooted_component_ids() -> Array[String]:
	var hall_id := get_town_hall_internal_id()
	if hall_id < 0:
		return []
	var result: Array[String] = []
	result.assign(get_access_for_building(hall_id).get("component_ids", []))
	result.sort()
	return result

## Canonical, mutation-free placement gate for the rooted first-town layout.
func evaluate_rooted_placement(building_id: String, footprint: Array[Vector2i],
		is_road: bool, requires_road_access: bool) -> Dictionary:
	if GameState.map == null or not bool(GameState.map.rooted_town_rules):
		return {"ok": true, "reason": "", "rooted_component_ids": []}
	var hall_id := get_town_hall_internal_id()
	if hall_id < 0:
		if building_id == TOWN_HALL_BUILDING_ID:
			return {"ok": true, "reason": "", "rooted_component_ids": []}
		return {"ok": false, "reason": PlaytestActionResult.TOWN_HALL_REQUIRED,
			"rooted_component_ids": []}
	if building_id == TOWN_HALL_BUILDING_ID:
		return {"ok": false, "reason": PlaytestActionResult.TOWN_HALL_ALREADY_PLACED,
			"town_hall_internal_id": hall_id, "rooted_component_ids": get_rooted_component_ids()}
	if not is_road and not requires_road_access:
		return {"ok": true, "reason": "", "town_hall_internal_id": hall_id,
			"rooted_component_ids": get_rooted_component_ids(), "exempt": true}
	var rooted := get_rooted_component_ids()
	var hall_cells: Dictionary = {}
	for cell in GameState.building_registry.get(hall_id, {}).get("cells", []):
		hall_cells[Vector2i(cell.x, cell.y)] = true
	var touches: Array = []
	for cell in footprint:
		for offset: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var neighbor_2d := cell + offset
			if is_road and hall_cells.has(neighbor_2d):
				touches.append(_coordinate_record(neighbor_2d))
				continue
			var neighbor := Vector3i(neighbor_2d.x, 0, neighbor_2d.y)
			var component_id := String(_component_by_cell.get(neighbor, ""))
			if not component_id.is_empty() and component_id in rooted:
				touches.append(_coordinate_record(neighbor))
	if not touches.is_empty():
		return {"ok": true, "reason": "", "town_hall_internal_id": hall_id,
			"rooted_component_ids": rooted, "touching_root_cells": touches}
	return {"ok": false, "reason": PlaytestActionResult.NOT_CONNECTED_TO_TOWN_HALL,
		"town_hall_internal_id": hall_id, "rooted_component_ids": rooted,
		"requires_road_access": requires_road_access, "is_road": is_road}

## Canonical footprint-aware access decision for one placed building.
func get_access_for_building(internal_id: int) -> Dictionary:
	if not _access_by_building.has(internal_id):
		return {
			"internal_id": internal_id,
			"road_accessible": false,
			"stops": [],
			"component_ids": [],
			"reasons": ["unknown_building"],
			"primary_reason": "unknown_building",
		}
	return (_access_by_building[internal_id] as Dictionary).duplicate(true)

## Stable shortest road route between two placed buildings.
func get_route_between_buildings(origin_id: int, destination_id: int) -> Dictionary:
	var cache_key := "%d>%d" % [origin_id, destination_id]
	if _route_cache.has(cache_key):
		_route_cache_hits += 1
		return (_route_cache[cache_key] as Dictionary).duplicate(true)
	_route_cache_misses += 1
	var origin := get_access_for_building(origin_id)
	var destination := get_access_for_building(destination_id)
	var result := {
		"origin_internal_id": origin_id,
		"destination_internal_id": destination_id,
		"reachable": false,
		"distance": -1,
		"path": [],
		"shared_component_ids": [],
		"reason": "",
	}
	if not bool(origin.get("road_accessible", false)) or not bool(destination.get("road_accessible", false)):
		result["reason"] = "no_road_access"
		return _store_route(cache_key, result)
	var destination_components: Dictionary = {}
	for component_id in destination.get("component_ids", []):
		destination_components[String(component_id)] = true
	var shared: Array[String] = []
	for component_id in origin.get("component_ids", []):
		if destination_components.has(String(component_id)):
			shared.append(String(component_id))
	shared.sort()
	result["shared_component_ids"] = shared
	if shared.is_empty():
		result["reason"] = "isolated_road_component"
		return _store_route(cache_key, result)
	var target_cells: Dictionary = {}
	for stop_record in destination.get("stops", []):
		var stop: Variant = _record_cell(stop_record)
		if stop != null and String(_component_by_cell.get(stop, "")) in shared:
			target_cells[stop] = true
	var starts: Array[Vector3i] = []
	for stop_record in origin.get("stops", []):
		var stop: Variant = _record_cell(stop_record)
		if stop != null and String(_component_by_cell.get(stop, "")) in shared:
			starts.append(stop)
	_sort_cells(starts)
	var path := _shortest_path(starts, target_cells)
	if path.is_empty():
		result["reason"] = "isolated_road_component"
		return _store_route(cache_key, result)
	result["reachable"] = true
	result["distance"] = maxi(0, path.size() - 1)
	result["path"] = _cell_records(path)
	return _store_route(cache_key, result)

## Lightweight view for high-frequency simulation consumers that need route
## truth but not the full path. Warm-cache calls avoid duplicating every cell.
func get_route_summary_between_buildings(origin_id: int, destination_id: int) -> Dictionary:
	var cache_key := "%d>%d" % [origin_id, destination_id]
	var route: Dictionary
	if _route_cache.has(cache_key):
		_route_cache_hits += 1
		route = _route_cache[cache_key]
	else:
		route = get_route_between_buildings(origin_id, destination_id)
	return {
		"origin_internal_id": origin_id,
		"destination_internal_id": destination_id,
		"reachable": bool(route.get("reachable", false)),
		"distance": int(route.get("distance", -1)),
		"shared_component_ids": route.get("shared_component_ids", []).duplicate(),
		"reason": String(route.get("reason", "")),
	}

func _store_route(cache_key: String, result: Dictionary) -> Dictionary:
	_route_cache[cache_key] = result.duplicate(true)
	return result.duplicate(true)

func _clear_query_caches() -> void:
	_route_cache.clear()
	_internal_id_by_anchor.clear()
	_route_cache_hits = 0
	_route_cache_misses = 0

## Detached route evidence for civilian presentation. Anchors are resolved through
## the same building/access projection used by Community assignments.
func resolve_civilian_route(origin_anchor: Vector2i, destination_anchor: Vector2i) -> Dictionary:
	var origin_id := _internal_id_for_anchor(origin_anchor)
	var destination_id := _internal_id_for_anchor(destination_anchor)
	if origin_id < 0:
		return {"ok":false, "road_revision":_revision, "blocked_reason":"missing_origin"}
	if destination_id < 0:
		return {"ok":false, "road_revision":_revision, "blocked_reason":"missing_destination"}
	var origin_access := get_access_for_building(origin_id)
	var destination_access := get_access_for_building(destination_id)
	if not bool(origin_access.get("road_accessible", false)):
		return {"ok":false, "road_revision":_revision, "blocked_reason":"origin_has_no_road_access"}
	if not bool(destination_access.get("road_accessible", false)):
		return {"ok":false, "road_revision":_revision, "blocked_reason":"destination_has_no_road_access"}
	var route := get_route_between_buildings(origin_id, destination_id)
	if not bool(route.get("reachable", false)):
		return {"ok":false, "road_revision":_revision, "blocked_reason":"disconnected"}
	var road_path: Array = route.get("path", []).duplicate(true)
	if road_path.is_empty():
		return {"ok":false, "road_revision":_revision, "blocked_reason":"disconnected"}
	return {
		"ok": true,
		"origin_internal_id": origin_id,
		"destination_internal_id": destination_id,
		"origin_stop": _record3(road_path.front()),
		"destination_stop": _record3(road_path.back()),
		"road_path": road_path.map(func(record): return _record3(record)),
		"route_distance": int(route.get("distance", maxi(0, road_path.size() - 1))),
		"road_revision": _revision,
		"dependency_cells": road_path.map(func(record): return _record3(record)),
		"blocked_reason": "",
	}

func _internal_id_for_anchor(anchor: Vector2i) -> int:
	return get_internal_id_for_anchor(anchor)

static func _record3(value: Variant) -> Dictionary:
	var cell: Variant = _record_cell(value)
	return {"x":cell.x, "y":cell.y, "z":cell.z} if cell != null else {}

func get_route_from_town_hall(destination_id: int) -> Dictionary:
	var hall_id := get_town_hall_internal_id()
	if hall_id < 0:
		return {"origin_internal_id": -1, "destination_internal_id": destination_id,
			"reachable": false, "distance": -1, "path": [], "reason": "town_hall_required"}
	return get_route_between_buildings(hall_id, destination_id)

func get_connectivity_snapshot() -> Dictionary:
	var component_rows: Array = []
	var component_ids := _components.keys()
	component_ids.sort()
	for component_id in component_ids:
		var cells: Array = _components[component_id]
		component_rows.append({
			"component_id": component_id,
			"cell_count": cells.size(),
			"cells": _cell_records(cells),
		})
	var building_rows: Array = []
	var building_ids := _access_by_building.keys()
	building_ids.sort()
	for internal_id in building_ids:
		building_rows.append((_access_by_building[internal_id] as Dictionary).duplicate(true))
	var road_cells: Array[Vector3i] = []
	road_cells.assign(_graph.keys())
	_sort_cells(road_cells)
	return {
		"revision": _revision,
		"road_cell_count": road_cells.size(),
		"road_cells": _cell_records(road_cells),
		"components": component_rows,
		"buildings": building_rows,
	}

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
	_clear_query_caches()
	if GameState.gridmap == null:
		return
	_build_graph()
	_build_walk_graph()
	_find_building_stops()
	_build_components()
	_build_access_projection()
	_revision += 1
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

func _build_components() -> void:
	_component_by_cell.clear()
	_components.clear()
	var road_cells: Array[Vector3i] = []
	road_cells.assign(_graph.keys())
	_sort_cells(road_cells)
	for start in road_cells:
		if _component_by_cell.has(start):
			continue
		var pending: Array[Vector3i] = [start]
		var found: Array[Vector3i] = []
		var seen := {start: true}
		while not pending.is_empty():
			var current: Vector3i = pending.pop_front()
			found.append(current)
			var neighbors: Array[Vector3i] = []
			neighbors.assign(_graph.get(current, []))
			_sort_cells(neighbors)
			for neighbor in neighbors:
				if seen.has(neighbor):
					continue
				seen[neighbor] = true
				pending.append(neighbor)
		_sort_cells(found)
		var component_id := _cell_key(found[0])
		_components[component_id] = found
		for cell in found:
			_component_by_cell[cell] = component_id

func _build_access_projection() -> void:
	_access_by_building.clear()
	_internal_id_by_anchor.clear()
	var ids := GameState.building_registry.keys()
	ids.sort()
	var catalog := PluginManager.get_plugin("BuildingCatalog")
	for internal_id_raw in ids:
		var internal_id := int(internal_id_raw)
		var entry: Dictionary = GameState.building_registry[internal_id_raw]
		var stable_anchor: Variant = entry.get("anchor", Vector2i.ZERO)
		if stable_anchor is Vector2i:
			_internal_id_by_anchor[stable_anchor] = internal_id
		var sid := int(entry.get("structure", -1))
		if sid < 0 or sid >= GameState.structures.size():
			continue
		if _road_meta_for(sid) != null:
			continue
		var footprint: Array[Vector3i] = []
		for cell_raw in entry.get("cells", [entry.get("anchor", Vector2i.ZERO)]):
			var cell_2d: Variant = cell_raw
			if cell_2d is Vector3i:
				footprint.append(cell_2d)
			elif cell_2d is Vector2i:
				footprint.append(Vector3i(cell_2d.x, 0, cell_2d.y))
		_sort_cells(footprint)
		var stops: Array[Vector3i] = []
		for cell in footprint:
			for offset: Vector3i in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
				var neighbor := cell + offset
				if _graph.has(neighbor) and neighbor not in stops:
					stops.append(neighbor)
		_sort_cells(stops)
		var component_ids: Array[String] = []
		for stop in stops:
			var component_id := String(_component_by_cell.get(stop, ""))
			if not component_id.is_empty() and component_id not in component_ids:
				component_ids.append(component_id)
		component_ids.sort()
		var anchor: Variant = entry.get("anchor", Vector2i.ZERO)
		var building_id := ""
		if catalog and catalog.has_method("get_id_by_index"):
			building_id = String(catalog.get_id_by_index(sid))
		var accessible := not stops.is_empty()
		_access_by_building[internal_id] = {
			"internal_id": internal_id,
			"building_id": building_id,
			"anchor": _coordinate_record(anchor),
			"footprint_cells": _cell_records(footprint),
			"road_accessible": accessible,
			"stops": _cell_records(stops),
			"component_ids": component_ids,
			"reasons": [] if accessible else ["no_road_access"],
			"primary_reason": "" if accessible else "no_road_access",
		}

func _shortest_path(starts: Array[Vector3i], targets: Dictionary) -> Array[Vector3i]:
	var pending: Array[Vector3i] = []
	var previous: Dictionary = {}
	for start in starts:
		if previous.has(start):
			continue
		previous[start] = null
		pending.append(start)
	while not pending.is_empty():
		var current: Vector3i = pending.pop_front()
		if targets.has(current):
			var path: Array[Vector3i] = []
			var cursor: Variant = current
			while cursor != null:
				path.push_front(cursor)
				cursor = previous[cursor]
			return path
		var neighbors: Array[Vector3i] = []
		neighbors.assign(_graph.get(current, []))
		_sort_cells(neighbors)
		for neighbor in neighbors:
			if previous.has(neighbor):
				continue
			previous[neighbor] = current
			pending.append(neighbor)
	return []

static func _sort_cells(cells: Array[Vector3i]) -> void:
	cells.sort_custom(func(a: Vector3i, b: Vector3i):
		return a.x < b.x if a.x != b.x else (a.z < b.z if a.z != b.z else a.y < b.y))

static func _cell_key(cell: Vector3i) -> String:
	return "%d,%d" % [cell.x, cell.z]

static func _coordinate_record(value: Variant) -> Dictionary:
	if value is Vector2i:
		return {"x": value.x, "z": value.y}
	if value is Vector3i:
		return {"x": value.x, "z": value.z}
	return {"x": int(value.get("x", 0)), "z": int(value.get("z", value.get("y", 0)))} if value is Dictionary else {"x": 0, "z": 0}

static func _cell_records(cells: Array) -> Array:
	var result: Array = []
	for cell in cells:
		result.append(_coordinate_record(cell))
	return result

static func _record_cell(value: Variant) -> Variant:
	if value is Vector3i:
		return value
	if value is Vector2i:
		return Vector3i(value.x, 0, value.y)
	if value is Dictionary:
		return Vector3i(int(value.get("x", 0)), 0, int(value.get("z", value.get("y", 0))))
	return null

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
