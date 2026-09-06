extends PluginBase

## CarManager — owns all active car journeys across all vehicle types.
##
## Uses one MultiMeshInstance3D per car type for GPU-instanced rendering.
## Callers pass building tiles; road-stop resolution happens internally.
##
## Resolved civilian requests begin as non-physical pending departures. Admission,
## tile claims, and rendering are transient presentation concerns only.
##
## Usage:
##   var jid := _car_manager.request_journey(origin_tile, [dest_tile, ...], CarSlot.CarType.CIVILIAN)
##   _car_manager.journey_completed.connect(func(jid, tile, pos): ...)

const CONGESTION_PENALTY := 8.0   # pathfinding cost multiplier for occupied tiles
const TILE_CAPACITY       := 2     # visible cars total, regardless of direction
const QUEUE_OFFSET        := 0.18  # bounded front/rear displacement within one tile

# ── Car type definitions ───────────────────────────────────────────────────────

const _TYPE_DEFS: Dictionary = {
	CarSlot.CarType.CIVILIAN: {
		"mesh_path": "res://models/Meshy_AI_Car_0403170715/Meshy_AI_Car_0403170715_texture.glb",
		"scale": 0.15, "rot_y": 270.0, "speed": 3.0, "max": 256
	},
}

# ── Per-type pool ──────────────────────────────────────────────────────────────

class TypePool:
	var mminstance:   MultiMeshInstance3D
	var ground_y:     float      = 0.0
	var free_indices: Array[int] = []

var _pools: Dictionary = {}

# ── Journey state ──────────────────────────────────────────────────────────────

var _active:       Dictionary = {}   # journey_id → CarSlot
var _pending:      Dictionary = {}   # journey_id → detached request record
var _pending_order: Array[int] = []
var _next_id:      int        = 0
var _pending_done: Dictionary = {}   # journey_id → {"tile": Vector3i, "pos": Vector3}
var _request_epoch: int = 0
var _request_sequence: int = 0
var _claim_sequence: int = 0

## Tile reservation: Vector3i → { journey_id → {"dir": Vector2i, "slot": int} }
var _reserved: Dictionary = {}

# ── Signals ───────────────────────────────────────────────────────────────────

signal journey_completed(journey_id: int, arrived_road_tile: Vector3i, exit_pos: Vector3)
signal journey_started(journey_id: int, origin_stop: Vector3i, position: Vector3)

# ── DI ────────────────────────────────────────────────────────────────────────

func get_plugin_name() -> String: return "CarManager"
func get_dependencies() -> Array[String]: return ["RoadNetwork"]

var _road_network: PluginBase

func inject(deps: Dictionary) -> void:
	_road_network = deps.get("RoadNetwork")

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	for car_type: int in _TYPE_DEFS:
		_setup_pool(car_type, _TYPE_DEFS[car_type])
	GameEvents.structure_placed.connect(_on_structure_placed)
	GameEvents.structure_demolished.connect(_on_structure_demolished)
	GameEvents.map_loaded.connect(_on_map_loaded)

func _setup_pool(car_type: int, def: Dictionary) -> void:
	var pool  := TypePool.new()
	var max_n: int   = def.get("max", 64)
	var scale: float = def.get("scale", 1.0)
	var mesh := _mesh_from_glb(def.mesh_path)
	pool.ground_y = (-mesh.get_aabb().position.y * scale) if mesh else 0.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count   = max_n
	mm.mesh             = mesh if mesh else _fallback_mesh()
	for i in max_n:
		mm.set_instance_transform(i, _hidden_transform())
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	pool.mminstance = mmi
	for i in max_n:
		pool.free_indices.append(i)
	_pools[car_type] = pool

func _cancel_all() -> void:
	for jid: int in _active.keys():
		_release_silent(_active[jid])
	_active.clear()
	_pending.clear()
	_pending_order.clear()
	_reserved.clear()
	_pending_done.clear()
	_next_id = 0
	_request_epoch = 0
	_request_sequence = 0
	_claim_sequence = 0

# ── Public API ────────────────────────────────────────────────────────────────

## Spawn a car at origin_tile and drive through route (ordered building tiles).
## loop=true → route restarts after last destination (patrol cars).
## Returns journey_id ≥ 0, or -1 on failure.
func request_journey(origin_tile: Vector3i, route: Array[Vector3i],
		car_type: int, loop: bool = false) -> int:
	var pool: TypePool = _pools.get(car_type)
	if not pool or pool.free_indices.is_empty():
		push_warning("[CarManager] pool full for type %d" % car_type)
		return -1
	if route.is_empty():
		push_warning("[CarManager] empty route from %s" % str(origin_tile))
		return -1
	var origin_stops: Array[Vector3i] = _road_network.get_stops_for_building(origin_tile)
	if origin_stops.is_empty():
		push_warning("[CarManager] no road access at %s" % str(origin_tile))
		return -1

	var def: Dictionary = _TYPE_DEFS[car_type]
	var slot := CarSlot.new()
	slot.journey_id   = _next_id
	_next_id         += 1
	slot.car_type     = car_type
	slot.route        = route.duplicate()
	slot.loop         = loop
	slot.speed        = def.get("speed", 3.0)
	slot.slot_index   = pool.free_indices.pop_back()
	slot.current_tile = origin_stops[0]
	slot.position     = _road_network.get_lane_position(origin_stops[0], Vector2i.ZERO)
	var claim_slot := _claim_tile(slot.current_tile, slot.journey_id, Vector2i.ZERO)
	if claim_slot < 0:
		pool.free_indices.append(slot.slot_index)
		return -1
	slot.current_claim_slot = claim_slot
	slot.lane_slot = claim_slot
	slot.admitted = true

	_active[slot.journey_id] = slot
	_pathfind_next(slot)
	return slot.journey_id

func request_resolved_journey(resident_id: int, origin_stop: Vector3i,
		destination_stop: Vector3i, road_path: Array[Vector3i], road_revision: int,
		plan_key: String, car_type: int = CarSlot.CarType.CIVILIAN) -> int:
	var pool: TypePool = _pools.get(car_type)
	if not pool or road_path.size() < 2 or resident_id < 0 or road_revision < 0 \
			or plan_key.is_empty():
		return -1
	if road_path.front() != origin_stop or road_path.back() != destination_stop:
		return -1
	for index in range(1, road_path.size()):
		if Pathfinder.manhattan(road_path[index - 1], road_path[index]) != 1:
			return -1
	for pending: Dictionary in _pending.values():
		if int(pending.get("resident_id", -1)) == resident_id:
			return -1
	for active_slot: CarSlot in _active.values():
		if active_slot.resident_id == resident_id:
			return -1
	var first_direction := Vector2i(road_path[1].x - origin_stop.x,
		road_path[1].z - origin_stop.z)
	if first_direction == Vector2i.ZERO:
		return -1
	var journey_id := _next_id
	_next_id += 1
	_pending[journey_id] = {
		"journey_id": journey_id,
		"resident_id": resident_id,
		"plan_key": plan_key,
		"origin_stop": origin_stop,
		"destination_stop": destination_stop,
		"road_path": road_path.duplicate(),
		"road_revision": road_revision,
		"request_epoch": _request_epoch,
		"request_sequence": _request_sequence,
		"first_direction": first_direction,
		"car_type": car_type,
		"waiting_reason": "",
	}
	_request_sequence += 1
	_pending_order.append(journey_id)
	return journey_id

func _admit_pending() -> void:
	var origins: Array[Vector3i] = []
	for journey_id in _pending_order:
		if not _pending.has(journey_id):
			continue
		var origin: Vector3i = _pending[journey_id]["origin_stop"]
		if origin not in origins:
			origins.append(origin)
	origins.sort_custom(func(a: Vector3i, b: Vector3i):
		return a.x < b.x if a.x != b.x else (a.z < b.z if a.z != b.z else a.y < b.y))
	for origin in origins:
		for journey_id in _pending_order.duplicate():
			if not _pending.has(journey_id):
				continue
			var pending: Dictionary = _pending[journey_id]
			if pending["origin_stop"] != origin:
				continue
			if not _tile_is_clear(origin, journey_id, pending["first_direction"]):
				pending["waiting_reason"] = "origin_capacity"
				continue
			var pool: TypePool = _pools.get(int(pending["car_type"]))
			if not pool or pool.free_indices.is_empty():
				pending["waiting_reason"] = "car_pool_capacity"
				continue
			_activate_pending(journey_id, pending, pool)

func _activate_pending(journey_id: int, pending: Dictionary, pool: TypePool) -> void:
	var slot := CarSlot.new()
	slot.journey_id = journey_id
	slot.car_type = int(pending["car_type"])
	slot.resident_id = int(pending["resident_id"])
	slot.plan_key = String(pending["plan_key"])
	slot.origin_stop = pending["origin_stop"]
	slot.destination_stop = pending["destination_stop"]
	slot.road_revision = int(pending["road_revision"])
	slot.request_epoch = int(pending["request_epoch"])
	slot.request_sequence = int(pending["request_sequence"])
	slot.resolved_journey = true
	slot.admitted = true
	slot.route.assign(pending["road_path"].duplicate())
	slot.canonical_route.assign(pending["road_path"].duplicate())
	slot.speed = float(_TYPE_DEFS[slot.car_type].get("speed", 3.0))
	slot.slot_index = pool.free_indices.pop_back()
	slot.current_tile = slot.origin_stop
	slot.travel_dir = pending["first_direction"]
	slot.current_claim_slot = _claim_tile(slot.current_tile, journey_id,
		slot.travel_dir, "current")
	slot.lane_slot = slot.current_claim_slot
	slot.position = _display_anchor(slot.current_tile, slot.travel_dir,
		slot.current_claim_slot)
	_active[journey_id] = slot
	_pending.erase(journey_id)
	_pending_order.erase(journey_id)
	_set_resolved_waypoints(slot)
	_write_transform(slot)
	journey_started.emit(journey_id, slot.origin_stop, slot.position)

func _set_resolved_waypoints(slot: CarSlot) -> void:
	var path: Array[Vector3i] = slot.route.duplicate()
	if not path.is_empty() and path.front() == slot.current_tile:
		path.pop_front()
	var positions: Array[Vector3] = []
	var previous := slot.current_tile
	for cell in path:
		var direction := Vector2i(cell.x - previous.x, cell.z - previous.z)
		positions.append(_road_network.get_lane_position(cell, direction))
		previous = cell
	slot._waypoints.assign(positions)
	slot._waypoint_tiles.assign(path)
	if path.is_empty():
		_complete(slot)
		return
	var first_direction := Vector2i(path[0].x - slot.current_tile.x, path[0].z - slot.current_tile.z)
	slot.travel_dir = first_direction
	slot._seg_start_basis = _dir_to_basis(first_direction)
	slot._seg_end_basis = slot._seg_start_basis
	slot._seg_total_dist = slot.position.distance_to(slot._waypoints[0])
	slot._seg_progress = 0.0

func cancel_journey(journey_id: int) -> void:
	if _pending.has(journey_id):
		_pending.erase(journey_id)
		_pending_order.erase(journey_id)
		return
	var slot: CarSlot = _active.get(journey_id)
	if not slot:
		return
	_release_silent(slot)
	_active.erase(journey_id)

func refresh_resolved_journey_revision(journey_id: int, plan_key: String, road_revision: int) -> bool:
	var pending: Dictionary = _pending.get(journey_id, {})
	if not pending.is_empty():
		if String(pending.get("plan_key", "")) != plan_key:
			return false
		pending["road_revision"] = road_revision
		return true
	var slot: CarSlot = _active.get(journey_id)
	if not slot or slot.plan_key != plan_key:
		return false
	slot.road_revision = road_revision
	return true

func _on_structure_placed(_position: Vector3i, _structure_index: int, _orientation: int) -> void:
	pass

func _on_structure_demolished(position: Vector3i) -> void:
	var pending_ids: Array = _pending.keys()
	pending_ids.sort()
	for journey_id in pending_ids:
		var pending: Dictionary = _pending.get(journey_id, {})
		if position == pending.get("origin_stop") or position == pending.get("destination_stop") \
				or position in pending.get("road_path", []):
			cancel_journey(journey_id)
	var ids: Array = _active.keys()
	ids.sort()
	for jid in ids:
		var slot: CarSlot = _active.get(jid)
		if slot and (position == slot.origin_stop or position == slot.destination_stop or position in slot.route):
			cancel_journey(jid)

func _on_map_loaded(_map: Variant) -> void:
	_cancel_all()

func get_civilian_snapshot() -> Dictionary:
	var rows: Array = []
	var violations: Array = []
	var resident_journeys: Dictionary = {}
	var waiting_count := 0
	for slot: CarSlot in _active.values():
		if slot.resident_id < 0: continue
		if resident_journeys.has(slot.resident_id):
			violations.append({"resident_id":slot.resident_id,"code":"duplicate_car_binding"})
		resident_journeys[slot.resident_id] = slot.journey_id
		for index in range(1, slot.route.size()):
			if Pathfinder.manhattan(slot.route[index - 1], slot.route[index]) != 1:
				violations.append({"resident_id":slot.resident_id,"code":"invalid_waypoint_cell"})
				break
		if slot.waiting: waiting_count += 1
		rows.append({
			"journey_id": slot.journey_id, "resident_id": slot.resident_id,
			"plan_key": slot.plan_key, "origin_stop": _cell_record(slot.origin_stop),
			"destination_stop": _cell_record(slot.destination_stop),
			"road_path": slot.route.map(func(cell): return _cell_record(cell)),
			"road_revision": slot.road_revision, "waiting": slot.waiting,
			"current_tile": _cell_record(slot.current_tile),
		})
	rows.sort_custom(func(a, b):
		return a["resident_id"] < b["resident_id"] if a["resident_id"] != b["resident_id"] else a["journey_id"] < b["journey_id"])
	violations.append_array(_traffic_violations())
	violations.sort_custom(_violation_less)
	return {"schema_version": 1, "pending_departure_count": _pending.size(),
		"active_car_count": rows.size(), "waiting_car_count": waiting_count,
		"journeys": rows.duplicate(true), "pending_departures": _pending_rows(),
		"violations":violations.duplicate(true)}

func get_traffic_flow_snapshot(_pedestrian_spacing: Array = []) -> Dictionary:
	var active_rows: Array = []
	for journey_id in _sorted_active_ids():
		var slot: CarSlot = _active[journey_id]
		active_rows.append({
			"journey_id": slot.journey_id,
			"resident_id": slot.resident_id,
			"plan_key": slot.plan_key,
			"origin_stop": _cell_record(slot.origin_stop),
			"destination_stop": _cell_record(slot.destination_stop),
			"road_path": slot.route.map(func(cell): return _cell_record(cell)),
			"road_revision": slot.road_revision,
			"travel_direction": _direction_record(slot.travel_dir),
			"current_tile": _cell_record(slot.current_tile),
			"current_claim_slot": slot.current_claim_slot,
			"next_tile": null if slot.next_tile == null else _cell_record(slot.next_tile),
			"next_claim_slot": null if slot.next_claim_slot < 0 else slot.next_claim_slot,
			"segment_progress": snappedf(slot._seg_progress, 0.0001),
			"waiting": slot.waiting,
			"display_position": _position_record(slot.position),
		})
	return {
		"schema_version": 1,
		"pending_departure_count": _pending.size(),
		"active_car_count": active_rows.size(),
		"waiting_car_count": active_rows.filter(func(row): return row["waiting"]).size(),
		"pending_departures": _pending_rows(),
		"active_journeys": active_rows,
		"tile_occupancy": _occupancy_rows(),
		"pedestrian_spacing": _pedestrian_spacing.duplicate(true),
		"violations": _traffic_violations(),
	}

func _traffic_violations() -> Array:
	var violations: Array = []
	for tile: Vector3i in _reserved:
		var claims: Dictionary = _reserved[tile]
		if claims.size() > TILE_CAPACITY:
			violations.append({"code":"road_tile_over_capacity", "tile":_cell_record(tile),
				"resident_id":-1, "journey_id":-1, "claim_count":claims.size()})

	var positions: Dictionary = {}
	for journey_id in _sorted_active_ids():
		var slot: CarSlot = _active[journey_id]
		if slot.resolved_journey and not slot.admitted:
			violations.append(_slot_violation("spawned_without_admission", slot))
		var current_claims: Dictionary = _reserved.get(slot.current_tile, {})
		if not current_claims.has(journey_id):
			violations.append(_slot_violation("missing_current_tile_claim", slot,
				slot.current_tile))
		if slot.next_tile != null:
			var next_claims: Dictionary = _reserved.get(slot.next_tile, {})
			var valid_next := Pathfinder.manhattan(slot.current_tile, slot.next_tile) == 1 \
				and next_claims.has(journey_id) \
				and String(next_claims[journey_id].get("phase", "")) == "next"
			if not valid_next:
				violations.append(_slot_violation("invalid_next_tile_claim", slot,
					slot.next_tile))
		else:
			for tile: Vector3i in _reserved:
				if _reserved[tile].has(journey_id) \
						and String(_reserved[tile][journey_id].get("phase", "")) == "next":
					violations.append(_slot_violation("invalid_next_tile_claim", slot, tile))
					break
		if not _position_is_on_claimed_road(slot):
			violations.append(_slot_violation("car_transform_off_road", slot,
				slot.current_tile))
		var position_key := _position_key(slot.position)
		if positions.has(position_key):
			violations.append(_slot_violation("duplicate_car_position", slot,
				slot.current_tile))
		else:
			positions[position_key] = journey_id
		if slot.resolved_journey and not slot.canonical_route.is_empty() \
				and slot.route != slot.canonical_route:
			violations.append(_slot_violation("canonical_route_changed_by_congestion", slot))

	var actual_pending: Array = []
	for journey_id in _pending_order:
		if _pending.has(journey_id):
			actual_pending.append(journey_id)
	var expected_pending := actual_pending.duplicate()
	expected_pending.sort_custom(_pending_less)
	if actual_pending != expected_pending:
		var bad_id := int(actual_pending[0]) if not actual_pending.is_empty() else -1
		violations.append({"code":"pending_order_violation", "resident_id":
			int(_pending.get(bad_id, {}).get("resident_id", -1)), "journey_id":bad_id})
	violations.sort_custom(_violation_less)
	return violations

func _pending_less(a: int, b: int) -> bool:
	var pa: Dictionary = _pending[a]
	var pb: Dictionary = _pending[b]
	for field in ["request_epoch", "request_sequence", "resident_id"]:
		var av := int(pa[field])
		var bv := int(pb[field])
		if av != bv:
			return av < bv
	return a < b

func _slot_violation(code: String, slot: CarSlot, tile: Variant = null) -> Dictionary:
	var result := {"code":code, "resident_id":slot.resident_id,
		"journey_id":slot.journey_id}
	if tile is Vector3i:
		result["tile"] = _cell_record(tile)
	return result

func _position_is_on_claimed_road(slot: CarSlot) -> bool:
	if _position_is_in_tile(slot.position, slot.current_tile):
		return true
	return slot.next_tile is Vector3i and _position_is_in_tile(slot.position, slot.next_tile)

func _position_is_in_tile(position: Vector3, tile: Vector3i) -> bool:
	return absf(position.x - float(tile.x)) <= 0.5001 \
		and absf(position.z - float(tile.z)) <= 0.5001

func _position_key(position: Vector3) -> String:
	return "%.4f,%.4f,%.4f" % [position.x, position.y, position.z]

func _violation_less(a: Dictionary, b: Dictionary) -> bool:
	var a_code := String(a.get("code", ""))
	var b_code := String(b.get("code", ""))
	if a_code != b_code:
		return a_code < b_code
	var a_tile: Dictionary = a.get("tile", {})
	var b_tile: Dictionary = b.get("tile", {})
	for axis in ["x", "z", "y"]:
		var av := int(a_tile.get(axis, -2147483648))
		var bv := int(b_tile.get(axis, -2147483648))
		if av != bv:
			return av < bv
	var a_resident := int(a.get("resident_id", -1))
	var b_resident := int(b.get("resident_id", -1))
	if a_resident != b_resident:
		return a_resident < b_resident
	return int(a.get("journey_id", -1)) < int(b.get("journey_id", -1))

func _pending_rows() -> Array:
	var result: Array = []
	for journey_id in _pending_order:
		if not _pending.has(journey_id):
			continue
		var pending: Dictionary = _pending[journey_id]
		result.append({
			"journey_id": journey_id,
			"resident_id": int(pending["resident_id"]),
			"plan_key": String(pending["plan_key"]),
			"origin_stop": _cell_record(pending["origin_stop"]),
			"destination_stop": _cell_record(pending["destination_stop"]),
			"road_path": pending["road_path"].map(func(cell): return _cell_record(cell)),
			"road_revision": int(pending["road_revision"]),
			"request_epoch": int(pending["request_epoch"]),
			"request_sequence": int(pending["request_sequence"]),
			"first_direction": _direction_record(pending["first_direction"]),
			"waiting_reason": String(pending["waiting_reason"]),
		})
	return result

func _occupancy_rows() -> Array:
	var tiles: Array[Vector3i] = []
	tiles.assign(_reserved.keys())
	tiles.sort_custom(func(a: Vector3i, b: Vector3i):
		return a.x < b.x if a.x != b.x else (a.z < b.z if a.z != b.z else a.y < b.y))
	var result: Array = []
	for tile in tiles:
		var claims: Array = []
		var ids: Array = _reserved[tile].keys()
		ids.sort_custom(func(a, b):
			var ca: Dictionary = _reserved[tile][a]
			var cb: Dictionary = _reserved[tile][b]
			return int(ca["slot"]) < int(cb["slot"]) if ca["slot"] != cb["slot"] \
				else int(ca.get("claim_order", 0)) < int(cb.get("claim_order", 0)))
		for journey_id in ids:
			var claim: Dictionary = _reserved[tile][journey_id]
			claims.append({"journey_id": journey_id,
				"direction": _direction_record(claim["dir"]), "phase": claim.get("phase", "current"),
				"slot": int(claim["slot"]), "claim_order": int(claim.get("claim_order", 0))})
		result.append({"tile": _cell_record(tile), "capacity": TILE_CAPACITY,
			"claim_count": claims.size(), "claims": claims})
	return result

func _sorted_active_ids() -> Array:
	var ids: Array = _active.keys()
	ids.sort()
	return ids

func _direction_record(direction: Vector2i) -> Dictionary:
	return {"x": direction.x, "z": direction.y}

func _position_record(position: Vector3) -> Dictionary:
	return {"x": snappedf(position.x, 0.0001), "y": snappedf(position.y, 0.0001),
		"z": snappedf(position.z, 0.0001)}

func _cell_record(cell: Vector3i) -> Dictionary:
	return {"x": cell.x, "y": cell.y, "z": cell.z}

# ── Process ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_request_epoch += 1
	_admit_pending()
	for jid in _sorted_active_ids():
		if jid in _pending_done:
			continue
		var slot: CarSlot = _active[jid]
		_advance(slot, delta)
		if not jid in _pending_done:
			_write_transform(slot)

	var completed_ids: Array = _pending_done.keys()
	completed_ids.sort()
	for jid in completed_ids:
		var data: Dictionary = _pending_done[jid]
		_active.erase(jid)
		journey_completed.emit(jid, data["tile"], data["pos"])
	_pending_done.clear()

# ── Movement ──────────────────────────────────────────────────────────────────

func _advance(slot: CarSlot, delta: float) -> void:
	if slot._waypoints.is_empty():
		return

	if slot.next_tile == null:
		var requested_next: Vector3i = slot._waypoint_tiles[0]
		var requested_direction := Vector2i(requested_next.x - slot.current_tile.x,
			requested_next.z - slot.current_tile.z)
		if not _tile_is_clear(requested_next, slot.journey_id, requested_direction):
			slot.waiting = true
			slot.wait_time += delta
			slot.position = _current_display_anchor(slot)
			return
		var reserved_slot := _claim_tile(requested_next, slot.journey_id,
			requested_direction, "next")
		if reserved_slot < 0:
			slot.waiting = true
			slot.wait_time += delta
			slot.position = _current_display_anchor(slot)
			return
		slot.next_tile = requested_next
		slot.next_claim_slot = reserved_slot
		slot.travel_dir = requested_direction
		slot.waiting = false
		slot.wait_time = 0.0
		slot._seg_progress = 0.0
		slot._seg_start_basis = _dir_to_basis(_current_claim_direction(slot))
		slot._seg_end_basis = _dir_to_basis(requested_direction)
		slot._cross_start = _current_display_anchor(slot)
		slot._cross_end = _display_anchor(requested_next, requested_direction,
			reserved_slot)
		slot._seg_total_dist = maxf(0.001,
			slot._cross_start.distance_to(slot._cross_end))

	slot.waiting = false
	slot._cross_start = _current_display_anchor(slot)
	slot._cross_end = _display_anchor(slot.next_tile, slot.travel_dir,
		slot.next_claim_slot)
	var progress_step := maxf(0.0, slot.speed * delta) / slot._seg_total_dist
	slot._seg_progress = minf(1.0, slot._seg_progress + progress_step)
	slot.position = slot._cross_start.lerp(slot._cross_end, slot._seg_progress)
	if slot._seg_progress < 1.0:
		return

	var previous_tile := slot.current_tile
	var arrived_tile: Vector3i = slot.next_tile
	_release_tile(previous_tile, slot.journey_id)
	slot.current_tile = arrived_tile
	slot.current_claim_slot = slot.next_claim_slot
	slot.lane_slot = slot.current_claim_slot
	slot.next_tile = null
	slot.next_claim_slot = -1
	if _reserved.has(arrived_tile) and _reserved[arrived_tile].has(slot.journey_id):
		_reserved[arrived_tile][slot.journey_id]["phase"] = "current"
	slot._waypoints.pop_front()
	slot._waypoint_tiles.pop_front()
	slot._seg_progress = 0.0
	slot.position = _current_display_anchor(slot)
	if slot._waypoints.is_empty():
		_on_segment_done(slot)

func _on_segment_done(slot: CarSlot) -> void:
	if slot.resolved_journey:
		_complete(slot)
		return
	slot.route_index += 1
	if slot.route_index >= slot.route.size():
		if slot.loop:
			slot.route_index = 0
		else:
			_complete(slot)
			return
	_pathfind_next(slot)

func _complete(slot: CarSlot) -> void:
	for tile: Vector3i in _reserved.keys():
		if _reserved[tile].has(slot.journey_id):
			_release_tile(tile, slot.journey_id)
	var pool: TypePool = _pools.get(slot.car_type)
	if pool and slot.slot_index >= 0 and slot.slot_index not in pool.free_indices:
		pool.free_indices.append(slot.slot_index)
	_hide_slot(slot)
	_pending_done[slot.journey_id] = {"tile": slot.current_tile, "pos": slot.position}

func _release_silent(slot: CarSlot) -> void:
	for tile: Vector3i in _reserved.keys():
		if _reserved[tile].has(slot.journey_id):
			_release_tile(tile, slot.journey_id)
	var pool: TypePool = _pools.get(slot.car_type)
	if pool and slot.slot_index >= 0 and slot.slot_index not in pool.free_indices:
		pool.free_indices.append(slot.slot_index)
	_hide_slot(slot)

# ── Pathfinding ───────────────────────────────────────────────────────────────

func _pathfind_next(slot: CarSlot) -> void:
	var dest_building: Vector3i = slot.route[slot.route_index]
	var dest_stops: Array[Vector3i] = _road_network.get_stops_for_building(dest_building)
	if dest_stops.is_empty():
		push_warning("[CarManager] no road stop for %s — skipping" % str(dest_building))
		_skip_or_complete(slot)
		return

	var goal: Vector3i = dest_stops[0]
	if goal == slot.current_tile:
		_on_segment_done(slot)
		return

	var path: Array[Vector3i] = Pathfinder.find_path(
		_road_network.get_road_graph(), slot.current_tile, goal,
		func(f: Vector3i, t: Vector3i) -> float:
			var base: float = _road_network.get_edge_cost(f, t)
			var dir: Vector2i = Vector2i(t.x - f.x, t.z - f.z)
			return base * CONGESTION_PENALTY if not _tile_is_clear(t, slot.journey_id, dir) else base,
		func(a: Vector3i, b: Vector3i) -> float: return Pathfinder.manhattan(a, b))

	if path.size() <= 1:
		push_warning("[CarManager] no path %s → %s" % [str(slot.current_tile), str(goal)])
		_skip_or_complete(slot)
		return

	path.remove_at(0)
	var positions: Array[Vector3] = []
	var prev: Vector3i = slot.current_tile
	for tile: Vector3i in path:
		var dir := Vector2i(tile.x - prev.x, tile.z - prev.z)
		positions.append(_road_network.get_lane_position(tile, dir))
		prev = tile
	slot._waypoints.assign(positions)
	slot._waypoint_tiles.assign(path)

	if not slot._waypoints.is_empty():
		var first_tile := slot._waypoint_tiles[0]
		var first_dir  := Vector2i(
			first_tile.x - slot.current_tile.x,
			first_tile.z - slot.current_tile.z)
		var new_basis := _dir_to_basis(first_dir)
		if slot.travel_dir == Vector2i.ZERO:
			# First ever path — snap directly to correct orientation, no spin-up
			slot._seg_start_basis = new_basis
			slot._seg_end_basis   = new_basis
		else:
			# Reroute or next segment — carry current visual heading as start
			slot._seg_start_basis = slot._seg_start_basis.slerp(
				slot._seg_end_basis, slot._seg_progress)
			slot._seg_end_basis = new_basis
		slot.travel_dir      = first_dir
		slot._seg_total_dist = slot.position.distance_to(slot._waypoints[0])
		slot._seg_progress   = 0.0
		# Re-claim current tile in the correct lane now direction is known
		if slot.travel_dir != Vector2i.ZERO:
			_release_tile(slot.current_tile, slot.journey_id)
			var assigned := _claim_tile(slot.current_tile, slot.journey_id, slot.travel_dir)
			slot.lane_slot = assigned
			slot.current_claim_slot = assigned
			slot.position  = _display_anchor(slot.current_tile, slot.travel_dir, assigned)

func _skip_or_complete(slot: CarSlot) -> void:
	slot.route_index += 1
	if slot.route_index < slot.route.size():
		_pathfind_next(slot)
	else:
		_complete(slot)

# ── Tile reservation ──────────────────────────────────────────────────────────

func _tile_is_clear(tile: Vector3i, jid: int, entry_dir: Vector2i) -> bool:
	var claims: Dictionary = _reserved.get(tile, {})
	return claims.has(jid) or claims.size() < TILE_CAPACITY

## Returns the assigned lane slot (0 or 1).
func _claim_tile(tile: Vector3i, jid: int, entry_dir: Vector2i,
		phase := "current") -> int:
	if not _reserved.has(tile):
		_reserved[tile] = {}
	if _reserved[tile].has(jid):
		return int(_reserved[tile][jid]["slot"])
	if _reserved[tile].size() >= TILE_CAPACITY:
		return -1
	var taken: Array[int] = []
	for existing_jid: int in _reserved[tile]:
		if existing_jid == jid:
			continue
		var entry: Dictionary = _reserved[tile][existing_jid]
		taken.append(entry["slot"])
	var lane_slot := 0
	while lane_slot in taken:
		lane_slot += 1
	_reserved[tile][jid] = {"dir": entry_dir, "slot": lane_slot,
		"phase": phase, "claim_order": _claim_sequence}
	_claim_sequence += 1
	return lane_slot

func _release_tile(tile: Vector3i, jid: int) -> void:
	if not _reserved.has(tile):
		return
	var released_slot := -1
	if _reserved[tile].has(jid):
		released_slot = _reserved[tile][jid]["slot"]
	_reserved[tile].erase(jid)
	# Slots are total per tile. Promote in stable claim order after any release.
	if released_slot >= 0:
		var remaining_ids: Array = _reserved[tile].keys()
		remaining_ids.sort_custom(func(a, b):
			return int(_reserved[tile][a].get("claim_order", 0)) \
				< int(_reserved[tile][b].get("claim_order", 0)))
		for index in remaining_ids.size():
			var existing_jid: int = remaining_ids[index]
			_reserved[tile][existing_jid]["slot"] = index
			if _active.has(existing_jid):
				var active_slot: CarSlot = _active[existing_jid]
				if active_slot.current_tile == tile:
					active_slot.current_claim_slot = index
					active_slot.lane_slot = index
				if active_slot.next_tile == tile:
					active_slot.next_claim_slot = index
	if _reserved[tile].is_empty():
		_reserved.erase(tile)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _dir_to_basis(dir: Vector2i) -> Basis:
	if dir == Vector2i.ZERO:
		return Basis.IDENTITY
	return Basis.looking_at(Vector3(float(dir.x), 0.0, float(dir.y)))

func _display_anchor(tile: Vector3i, direction: Vector2i, claim_slot: int) -> Vector3:
	var base: Vector3 = _road_network.get_lane_position(tile, direction)
	if direction == Vector2i.ZERO or claim_slot < 0:
		return base
	var forward := Vector3(float(direction.x), 0.0, float(direction.y)).normalized()
	var longitudinal := QUEUE_OFFSET if claim_slot == 0 else -QUEUE_OFFSET
	return base + forward * longitudinal

func _current_claim_direction(slot: CarSlot) -> Vector2i:
	var claims: Dictionary = _reserved.get(slot.current_tile, {})
	return claims.get(slot.journey_id, {}).get("dir", slot.travel_dir)

func _current_display_anchor(slot: CarSlot) -> Vector3:
	return _display_anchor(slot.current_tile, _current_claim_direction(slot),
		slot.current_claim_slot)

func _write_transform(slot: CarSlot) -> void:
	var def:   Dictionary = _TYPE_DEFS[slot.car_type]
	var pool:  TypePool   = _pools[slot.car_type]
	var display_basis := slot._seg_start_basis.slerp(slot._seg_end_basis,
			minf(slot._seg_progress * 2.0, 1.0))
	var rot    := Basis(Vector3.UP, deg_to_rad(def.get("rot_y", 0.0)))
	var scale: float = def.get("scale", 1.0)
	var final_basis := display_basis * rot * Basis().scaled(Vector3.ONE * scale)
	var world_pos   := slot.position + Vector3(0.0, pool.ground_y, 0.0)
	pool.mminstance.multimesh.set_instance_transform(
		slot.slot_index, Transform3D(final_basis, world_pos))

func _hide_slot(slot: CarSlot) -> void:
	var pool: TypePool = _pools.get(slot.car_type)
	if pool and pool.mminstance and pool.mminstance.multimesh:
		pool.mminstance.multimesh.set_instance_transform(slot.slot_index, _hidden_transform())

func _hidden_transform() -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0.0, -9999.0, 0.0))

func _mesh_from_glb(path: String) -> Mesh:
	var packed := load(path) as PackedScene
	if not packed:
		return null
	var state := packed.get_state()
	for i in state.get_node_count():
		if state.get_node_type(i) == "MeshInstance3D":
			for j in state.get_node_property_count(i):
				if state.get_node_property_name(i, j) == "mesh":
					return state.get_node_property_value(i, j) as Mesh
	return null

func _fallback_mesh() -> Mesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.075
	sphere.height = 0.15
	return sphere
