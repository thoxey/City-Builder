extends Node3D

@export var structures: Array[Structure] = []

var map: DataMap

var index: int = 0               # Index of structure being built
var _rotation_steps: int = 0     # 0–3, incremented by action_rotate()
var _preview_indicators: Array[MeshInstance3D] = []

# Road auto-tiling: precomputed at _ready()
var _road_straight_idx: int = -1
var _road_corner_idx: int = -1
var _road_split_idx: int = -1
var _road_intersection_idx: int = -1

# Hold-to-paint roads: track last painted cell so drag doesn't repaint same tile
var _paint_last_cell: Vector2i = Vector2i(-99999, -99999)

@export var selector: Node3D           # The 'cursor'
@export var selector_container: Node3D # Node that holds a preview of the structure
@export var view_camera: Camera3D      # Used for raycasting mouse
@export var gridmap: GridMap
@export var ground_gridmap: GridMap    # Pavement base layer under all placed buildings
@export var cash_display: Label
@export var toast_label: Label
@export var residential_label: Label
@export var commercial_label: Label
@export var workplace_label: Label

var plane: Plane # Used for raycasting mouse

const SAVE_SLOT_1 := "user://map_slot1.res"
const SAVE_SLOT_2 := "user://map_slot2.res"
const SAVE_TEMP   := "user://map.res"

func _ready():

	map = DataMap.new()
	plane = Plane(Vector3.UP, Vector3.ZERO)

	# Create new MeshLibrary dynamically, can also be done in the editor
	# See: https://docs.godotengine.org/en/stable/tutorials/3d/using_gridmaps.html

	var mesh_library = MeshLibrary.new()

	for structure in structures:

		var id = mesh_library.get_last_unused_item_id()

		mesh_library.create_item(id)
		var mesh: Mesh = get_mesh(structure.model)
		var s := structure.model_scale
		# Ground-align: shift up so the bottom of the mesh's bounding box sits at y=0
		var ground_offset := -mesh.get_aabb().position.y * s
		mesh_library.set_item_mesh(id, mesh)
		var rot_basis := Basis(Vector3.UP, deg_to_rad(structure.model_rotation_y)).scaled(Vector3.ONE * s)
		mesh_library.set_item_mesh_transform(id, Transform3D(
				rot_basis,
				Vector3(0, ground_offset, 0) + structure.model_offset))

	gridmap.mesh_library = mesh_library
	_setup_ground_gridmap()
	_find_road_indices()

	update_structure()
	update_cash()

	GameState.gridmap = gridmap
	GameState.structures = structures

	GameEvents.population_updated.connect(_on_population_updated)

	# Auto-load slot 1 on startup if it exists, otherwise start blank
	var slot1 = ResourceLoader.load(SAVE_SLOT_1)
	if slot1:
		_apply_map(slot1)

	GameState.map = map
	GameState._notify_ready()

func _process(delta):

	# Controls

	action_rotate()            # Rotates selection 90 degrees
	action_structure_toggle()  # Toggles between structures

	action_save_slot1()        # 1 — Save to slot 1
	action_load_temp()         # 2 — Load from temp
	action_save_slot2()        # 3 — Save to slot 2
	action_load_slot2()        # 4 — Load from slot 2
	action_clear()             # C — Clear map

	# Map position based on mouse

	var world_position = plane.intersects_ray(
		view_camera.project_ray_origin(get_viewport().get_mouse_position()),
		view_camera.project_ray_normal(get_viewport().get_mouse_position()))

	var gridmap_position = Vector3(round(world_position.x), 0, round(world_position.z))
	selector.position = lerp(selector.position, gridmap_position, min(delta * 40, 1.0))

	var anchor := Vector2i(int(gridmap_position.x), int(gridmap_position.z))
	_update_preview_color(anchor)

	action_build(gridmap_position)
	action_demolish(gridmap_position)

# Retrieve the mesh from a PackedScene, used for dynamically creating a MeshLibrary

func get_mesh(packed_scene):
	var scene_state: SceneState = packed_scene.get_state()
	for i in range(scene_state.get_node_count()):
		if(scene_state.get_node_type(i) == "MeshInstance3D"):
			for j in scene_state.get_node_property_count(i):
				var prop_name = scene_state.get_node_property_name(i, j)
				if prop_name == "mesh":
					var prop_value = scene_state.get_node_property_value(i, j)
					return prop_value.duplicate()

# ── Ground GridMap (pavement base layer) ──────────────────────────────────────

const GROUND_ITEM_ID := 0

func _setup_ground_gridmap() -> void:
	var ml := MeshLibrary.new()
	ml.create_item(GROUND_ITEM_ID)
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.98, 0.98)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.69, 0.64)   # warm stone/pavement grey
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	ml.set_item_mesh(GROUND_ITEM_ID, quad)
	ground_gridmap.mesh_library = ml

func _place_ground_tiles(cells: Array) -> void:
	for cell in cells:
		ground_gridmap.set_cell_item(Vector3i(cell.x, 0, cell.y), GROUND_ITEM_ID, 0)

func _clear_ground_tiles(cells: Array) -> void:
	for cell in cells:
		ground_gridmap.set_cell_item(Vector3i(cell.x, 0, cell.y), -1)

# ── Footprint helpers ──────────────────────────────────────────────────────────

## Rotate a footprint offset by steps * 90° clockwise.
static func _rotate_offset(offset: Vector2i, steps: int) -> Vector2i:
	var v := offset
	for _i in (steps % 4):
		v = Vector2i(v.y, -v.x)
	return v

## Return the world-space grid cells covered by a building placed at anchor.
func _get_footprint_cells(anchor: Vector2i, structure_idx: int, rot_steps: int) -> Array[Vector2i]:
	var fp: Array[Vector2i] = structures[structure_idx].footprint
	if fp.is_empty():
		fp = [Vector2i(0, 0)]
	var result: Array[Vector2i] = []
	for offset in fp:
		result.append(anchor + _rotate_offset(offset, rot_steps))
	return result

## Best-effort map of a GridMap orientation int back to rotation steps 0–3.
## Only used for migration of legacy saves (where footprint_cells was not stored).
## Single-cell buildings are unaffected regardless of accuracy.
static func _orientation_to_steps(orientation: int) -> int:
	match orientation:
		0:  return 0
		16: return 1
		10: return 2
		22: return 3
	return 0

# ── Build (place) a structure ──────────────────────────────────────────────────

func action_build(gridmap_position):
	var anchor := Vector2i(int(gridmap_position.x), int(gridmap_position.z))
	var is_road := _is_road_structure(index)

	var trigger := false
	if Input.is_action_just_pressed("build"):
		_paint_last_cell = Vector2i(-99999, -99999)
		trigger = true
	elif is_road and Input.is_action_pressed("build") and anchor != _paint_last_cell:
		trigger = true

	if not trigger:
		return
	_paint_last_cell = anchor

	var fp_cells := _get_footprint_cells(anchor, index, _rotation_steps)

	# Block if any footprint cell is already occupied
	for cell in fp_cells:
		if GameState.cell_to_building.has(cell):
			return

	var bid := GameState._next_building_id
	GameState._next_building_id += 1

	var orient := gridmap.get_orthogonal_index_from_basis(selector.basis)

	# Only the anchor cell goes into the GridMap (visual renderer)
	gridmap.set_cell_item(Vector3i(anchor.x, 0, anchor.y), index, orient)

	# All footprint cells go into the occupancy map
	for cell in fp_cells:
		GameState.cell_to_building[cell] = bid

	GameState.building_registry[bid] = {
		"anchor": anchor,
		"structure": index,
		"orientation": orient,
		"cells": fp_cells
	}

	_place_ground_tiles(fp_cells)

	# Road auto-tiling: fix this tile and all neighbouring road tiles
	if is_road:
		_retile_road_at(anchor)
		for dir in [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]:
			var nb: Vector2i = anchor + dir
			var nb_bid: int = GameState.cell_to_building.get(nb, -1)
			if nb_bid >= 0:
				var nb_sid: int = GameState.building_registry.get(nb_bid, {}).get("structure", -1)
				if nb_sid >= 0 and _is_road_structure(nb_sid):
					_retile_road_at(nb)

	map.cash -= structures[index].price
	update_cash()
	GameEvents.cash_changed.emit(map.cash)

	var placed_pos := Vector3i(anchor.x, 0, anchor.y)
	GameEvents.structure_placed.emit(placed_pos, index, orient)

	_emit_population_stats()
	Audio.play("sounds/placement-a.ogg, sounds/placement-b.ogg, sounds/placement-c.ogg, sounds/placement-d.ogg", -20)

# ── Demolish (remove) a structure ─────────────────────────────────────────────

func action_demolish(gridmap_position):
	if Input.is_action_just_pressed("demolish"):
		var clicked_cell := Vector2i(int(gridmap_position.x), int(gridmap_position.z))

		# Check occupancy map — catches both anchor and satellite cells
		if not GameState.cell_to_building.has(clicked_cell):
			return

		var bid: int = GameState.cell_to_building[clicked_cell]
		var entry: Dictionary = GameState.building_registry.get(bid, {})
		var anchor: Vector2i = entry.get("anchor", clicked_cell)
		var cells_to_remove: Array = entry.get("cells", [clicked_cell])

		for cell in cells_to_remove:
			GameState.cell_to_building.erase(cell)

		gridmap.set_cell_item(Vector3i(anchor.x, 0, anchor.y), -1)
		_clear_ground_tiles(cells_to_remove)
		GameState.building_registry.erase(bid)

		GameEvents.structure_demolished.emit(Vector3i(anchor.x, 0, anchor.y))

		# Retile neighbouring roads now that this tile is gone
		for dir in [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]:
			var nb: Vector2i = anchor + dir
			var nb_bid: int = GameState.cell_to_building.get(nb, -1)
			if nb_bid >= 0:
				var nb_sid: int = GameState.building_registry.get(nb_bid, {}).get("structure", -1)
				if nb_sid >= 0 and _is_road_structure(nb_sid):
					_retile_road_at(nb)

		_emit_population_stats()
		Audio.play("sounds/removal-a.ogg, sounds/removal-b.ogg, sounds/removal-c.ogg, sounds/removal-d.ogg", -20)

# ── Rotate the 'cursor' 90 degrees ────────────────────────────────────────────

func action_rotate():
	if Input.is_action_just_pressed("rotate"):
		selector.rotate_y(deg_to_rad(90))
		_rotation_steps = (_rotation_steps + 1) % 4

		Audio.play("sounds/rotate.ogg", -30)

# ── Toggle between structures to build ────────────────────────────────────────

func action_structure_toggle():
	var prev_index := index

	if Input.is_action_just_pressed("structure_next"):
		index = wrap(index + 1, 0, structures.size())
		Audio.play("sounds/toggle.ogg", -30)

	if Input.is_action_just_pressed("structure_previous"):
		index = wrap(index - 1, 0, structures.size())
		Audio.play("sounds/toggle.ogg", -30)

	if index != prev_index:
		update_structure()

# ── Update the structure visual in the 'cursor' ───────────────────────────────

func update_structure():
	# Clear previous structure preview in selector
	for n in selector_container.get_children():
		selector_container.remove_child(n)
		n.queue_free()
	_preview_indicators.clear()

	# Create new structure preview in selector at the anchor position
	var _model = structures[index].model.instantiate()
	selector_container.add_child(_model)
	var s := structures[index].model_scale
	_model.scale = Vector3.ONE * s
	_model.rotation_degrees.y = structures[index].model_rotation_y
	var mesh: Mesh = get_mesh(structures[index].model)
	var ground_offset := -mesh.get_aabb().position.y * s if mesh else 0.0
	_model.position = structures[index].model_offset + Vector3(0, ground_offset + 0.25, 0)

	# Add a flat coloured indicator quad for every footprint cell (including anchor).
	# Offsets are in local (unrotated) space — the selector node's rotation handles
	# visual alignment automatically when selector_container is a child of selector.
	var fp: Array[Vector2i] = structures[index].footprint
	if fp.is_empty():
		fp = [Vector2i(0, 0)]

	for offset in fp:
		var indicator := _make_cell_indicator()
		indicator.position = Vector3(offset.x, 0.05, offset.y)
		selector_container.add_child(indicator)
		_preview_indicators.append(indicator)

func _make_cell_indicator() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.9, 0.9)
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 1.0, 0.0, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi

## Called every frame to colour footprint indicators green (valid) or red (blocked).
func _update_preview_color(anchor: Vector2i) -> void:
	if _preview_indicators.is_empty():
		return
	var fp_cells := _get_footprint_cells(anchor, index, _rotation_steps)
	var is_valid := true
	for cell in fp_cells:
		if GameState.cell_to_building.has(cell):
			is_valid = false
			break
	var color := Color(0.0, 1.0, 0.0, 0.4) if is_valid else Color(1.0, 0.2, 0.2, 0.4)
	for ind in _preview_indicators:
		(ind.material_override as StandardMaterial3D).albedo_color = color

# ── Road auto-tiling ──────────────────────────────────────────────────────────

## Scan structures array to find the canonical road type indices.
func _find_road_indices() -> void:
	for i in structures.size():
		var meta: RoadMetadata = structures[i].find_metadata(RoadMetadata) as RoadMetadata
		if not meta:
			continue
		match meta.road_type:
			RoadMetadata.RoadType.STRAIGHT:
				if _road_straight_idx < 0:
					_road_straight_idx = i
			RoadMetadata.RoadType.CORNER:
				if _road_corner_idx < 0:
					_road_corner_idx = i
			RoadMetadata.RoadType.SPLIT:
				if _road_split_idx < 0:
					_road_split_idx = i
			RoadMetadata.RoadType.INTERSECTION:
				if _road_intersection_idx < 0:
					_road_intersection_idx = i

func _is_road_structure(struct_idx: int) -> bool:
	if struct_idx < 0 or struct_idx >= structures.size():
		return false
	return structures[struct_idx].find_metadata(RoadMetadata) != null

## Returns a bitmask of which cardinal neighbours of anchor contain a road tile.
## N=1, E=2, S=4, W=8
func _road_neighbor_mask(anchor: Vector2i) -> int:
	var dirs := [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]
	var bits := [1, 2, 4, 8]
	var mask := 0
	for i in 4:
		var nb: Vector2i = anchor + dirs[i]
		var nb_bid: int = GameState.cell_to_building.get(nb, -1)
		if nb_bid < 0:
			continue
		var nb_sid: int = GameState.building_registry.get(nb_bid, {}).get("structure", -1)
		if nb_sid >= 0 and _is_road_structure(nb_sid):
			mask |= bits[i]
	return mask

## Returns [structure_index, gridmap_orientation] for the correct road piece
## given a neighbour bitmask (N=1, E=2, S=4, W=8).
## Corner default orient=0 → S+W; rotations per step: S→E→N→W, W→S→E→N.
## Split  default orient=0 → E+S+W.
## Orientations: 0 steps=0, 1 step=16, 2 steps=10, 3 steps=22.
func _road_for_mask(mask: int) -> Array:
	var s  := _road_straight_idx     if _road_straight_idx >= 0     else 0
	var c  := _road_corner_idx       if _road_corner_idx >= 0       else s
	var sp := _road_split_idx        if _road_split_idx >= 0        else s
	var x  := _road_intersection_idx if _road_intersection_idx >= 0 else s
	# [struct_idx, gridmap_orientation]
	var lookup := [
		[s,  0 ],  # 0:  no neighbours   → straight N/S
		[s,  0 ],  # 1:  N               → straight N/S
		[s,  16],  # 2:  E               → straight E/W
		[c,  10],  # 3:  N+E             → corner 2 steps
		[s,  0 ],  # 4:  S               → straight N/S
		[s,  0 ],  # 5:  N+S             → straight N/S
		[c,  16],  # 6:  E+S             → corner 1 step
		[sp, 16],  # 7:  N+E+S           → split 1 step
		[s,  16],  # 8:  W               → straight E/W
		[c,  22],  # 9:  N+W             → corner 3 steps
		[s,  16],  # 10: E+W             → straight E/W
		[sp, 10],  # 11: N+E+W           → split 2 steps
		[c,  0 ],  # 12: S+W             → corner 0 steps
		[sp, 22],  # 13: N+S+W           → split 3 steps
		[sp, 0 ],  # 14: E+S+W           → split 0 steps
		[x,  0 ],  # 15: all             → intersection
	]
	if mask < 0 or mask > 15:
		return [s, 0]
	return lookup[mask]

## Update an existing road tile's type and orientation based on its current neighbours.
func _retile_road_at(anchor: Vector2i) -> void:
	var bid: int = GameState.cell_to_building.get(anchor, -1)
	if bid < 0:
		return
	var entry: Dictionary = GameState.building_registry.get(bid, {})
	var sid: int = entry.get("structure", -1)
	if sid < 0 or not _is_road_structure(sid):
		return
	var mask := _road_neighbor_mask(anchor)
	var result := _road_for_mask(mask)
	var new_sid: int = result[0]
	var new_orient: int = result[1]
	if new_sid < 0:
		return
	gridmap.set_cell_item(Vector3i(anchor.x, 0, anchor.y), new_sid, new_orient)
	entry["structure"] = new_sid
	entry["orientation"] = new_orient
	GameState.building_registry[bid] = entry

# ── Population stats ──────────────────────────────────────────────────────────

func _emit_population_stats() -> void:
	var residential := 0
	var commercial  := 0
	var workplace   := 0
	for bid in GameState.building_registry:
		var entry: Dictionary = GameState.building_registry[bid]
		var sid: int = entry.get("structure", -1)
		if sid < 0 or sid >= structures.size():
			continue
		var profile: BuildingProfile = structures[sid].find_metadata(BuildingProfile) as BuildingProfile
		if not profile:
			continue
		match profile.category:
			"residential": residential += profile.capacity
			"commercial":  commercial  += profile.capacity
			"workplace":   workplace   += profile.capacity
	GameEvents.population_updated.emit(residential, commercial, workplace)

func _on_population_updated(residential: int, commercial: int, workplace: int) -> void:
	if residential_label:
		residential_label.text = "Res: %d" % residential
	if commercial_label:
		commercial_label.text = "Com: %d" % commercial
	if workplace_label:
		workplace_label.text = "Work: %d" % workplace

func update_cash():
	cash_display.text = "$" + str(map.cash)

func show_toast(message: String) -> void:
	toast_label.text = message
	toast_label.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)

# ── Save / Load ────────────────────────────────────────────────────────────────

func _save_to(path: String, label: String) -> void:
	map.structures.clear()
	for bid in GameState.building_registry:
		var entry: Dictionary = GameState.building_registry[bid]
		var ds := DataStructure.new()
		ds.position = entry["anchor"]
		ds.orientation = entry["orientation"]
		ds.structure = entry["structure"]
		for cell in entry.get("cells", []):
			ds.footprint_cells.append(cell)
		map.structures.append(ds)
	ResourceSaver.save(map, path)
	show_toast(label)
	print("Saved to %s" % path)

func _load_from(path: String, label: String) -> void:
	var loaded = ResourceLoader.load(path)
	if not loaded:
		show_toast("No save found")
		return
	_apply_map(loaded)
	GameState.map = map
	GameEvents.map_loaded.emit(map)
	show_toast(label)
	print("Loaded from %s" % path)

func action_save_slot1():
	if Input.is_action_just_pressed("save_slot1"):
		_save_to(SAVE_SLOT_1, "Saved — Slot 1")

func action_load_temp():
	if Input.is_action_just_pressed("load_temp"):
		_load_from(SAVE_TEMP, "Loaded — Temp")

func action_save_slot2():
	if Input.is_action_just_pressed("save_slot2"):
		_save_to(SAVE_SLOT_2, "Saved — Slot 2")

func action_load_slot2():
	if Input.is_action_just_pressed("load_slot2"):
		_load_from(SAVE_SLOT_2, "Loaded — Slot 2")

func action_clear():
	if Input.is_action_just_pressed("clear"):
		_apply_map(DataMap.new())
		GameState.map = map
		GameEvents.map_loaded.emit(map)
		show_toast("Map cleared")

## Shared helper: clear state, populate GridMap + occupancy registry from a DataMap.
func _apply_map(loaded_map: DataMap) -> void:
	map = loaded_map
	gridmap.clear()
	ground_gridmap.clear()
	GameState.cell_to_building.clear()
	GameState.building_registry.clear()
	GameState._next_building_id = 0

	for ds in map.structures:
		var bid := GameState._next_building_id
		GameState._next_building_id += 1

		# Migration: recompute footprint cells for legacy saves that lack them.
		# For 1×1 buildings this always returns [anchor], so it's always correct.
		var cells: Array[Vector2i] = []
		if ds.footprint_cells.is_empty():
			cells = _get_footprint_cells(ds.position, ds.structure, _orientation_to_steps(ds.orientation))
		else:
			for c in ds.footprint_cells:
				cells.append(c)

		# Only the anchor cell goes into the GridMap
		gridmap.set_cell_item(Vector3i(ds.position.x, 0, ds.position.y), ds.structure, ds.orientation)

		# Register occupancy for all footprint cells
		for cell in cells:
			GameState.cell_to_building[cell] = bid

		_place_ground_tiles(cells)

		GameState.building_registry[bid] = {
			"anchor": ds.position,
			"structure": ds.structure,
			"orientation": ds.orientation,
			"cells": cells
		}

	update_cash()
	_emit_population_stats()
