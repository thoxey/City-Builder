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
# Hold-to-erase: track last erased cell so drag doesn't re-trigger on the same tile
var _erase_last_cell: Vector2i = Vector2i(-99999, -99999)

@export var selector: Node3D           # The 'cursor'
@export var selector_container: Node3D # Node that holds a preview of the structure
@export var view_camera: Camera3D      # Used for raycasting mouse
@export var gridmap: GridMap
@export var ground_gridmap: GridMap    # Grass/pavement base layer
@export var cash_display: Label
@export var toast_label: Label

var plane: Plane # Used for raycasting mouse

const SAVE_SLOT_1 := "user://map_slot1.res"
const SAVE_SLOT_2 := "user://map_slot2.res"
const SAVE_TEMP   := "user://map.res"

# ── Ground layer ──────────────────────────────────────────────────────────────
const GRASS_ITEM_ID   := 0
const GRASS_GRID_HALF := 256   # fills a 512×512 area (-256..255 on each axis)

# ── Overbuild confirmation ─────────────────────────────────────────────────────
var _overbuild_dialog:   ConfirmationDialog
var _overbuild_pending:  bool             = false
var _overbuild_anchor:   Vector2i         = Vector2i.ZERO
var _overbuild_orient:   int              = 0
var _overbuild_index:    int              = 0
var _overbuild_fp_cells: Array[Vector2i]  = []

func _ready():

	map = DataMap.new()
	plane = Plane(Vector3.UP, Vector3.ZERO)

	var mesh_library = MeshLibrary.new()

	for structure in structures:

		var id = mesh_library.get_last_unused_item_id()
		mesh_library.create_item(id)
		var mesh: Mesh = get_mesh(structure.model)
		var s := structure.model_scale
		var ground_offset := -mesh.get_aabb().position.y * s if mesh else 0.0

		# Auto-centre the model over its full footprint.
		# Average the footprint cell offsets so the mesh sits at the footprint's
		# geometric centre, not just the anchor cell.  model_offset is an
		# additional fine-tuning on top of this.
		var fp := structure.footprint if not structure.footprint.is_empty() else [Vector2i(0, 0)]
		var fp_cx := 0.0
		var fp_cz := 0.0
		for off: Vector2i in fp:
			fp_cx += off.x
			fp_cz += off.y
		fp_cx /= fp.size()
		fp_cz /= fp.size()

		mesh_library.set_item_mesh(id, mesh)
		var rot_basis := Basis(Vector3.UP, deg_to_rad(structure.model_rotation_y)).scaled(Vector3.ONE * s)
		mesh_library.set_item_mesh_transform(id, Transform3D(
				rot_basis,
				Vector3(fp_cx, ground_offset, fp_cz) + structure.model_offset))

	gridmap.mesh_library = mesh_library
	_setup_ground_gridmap()
	_find_road_indices()

	update_structure()
	update_cash()

	GameState.gridmap = gridmap
	GameState.structures = structures

	# Set up overbuild confirmation dialog
	_overbuild_dialog = ConfirmationDialog.new()
	_overbuild_dialog.title = "Replace Building?"
	_overbuild_dialog.dialog_text = "Demolish the existing building(s) here and build?"
	_overbuild_dialog.ok_button_text = "Replace"
	add_child(_overbuild_dialog)
	_overbuild_dialog.confirmed.connect(_on_overbuild_confirmed)
	_overbuild_dialog.canceled.connect(func(): _overbuild_pending = false)

	var slot1 = ResourceLoader.load(SAVE_SLOT_1)
	if slot1:
		_apply_map(slot1)

	_fill_grass_background()

	GameState.map = map
	GameState._notify_ready()

func _process(delta):

	if _overbuild_pending:
		return

	action_rotate()
	action_structure_toggle()

	action_save_slot1()
	action_load_temp()
	action_save_slot2()
	action_load_slot2()
	action_clear()

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

# ── Ground GridMap (grass background + pavement under buildings) ───────────────

func _setup_ground_gridmap() -> void:
	var ml := MeshLibrary.new()
	# Single item: the grass tile used for every blank cell on the map.
	ml.create_item(GRASS_ITEM_ID)
	var grass_packed := load("res://models/grass.glb") as PackedScene
	var grass_mesh: Mesh = get_mesh(grass_packed) if grass_packed else null
	if grass_mesh:
		var gy := -grass_mesh.get_aabb().position.y
		ml.set_item_mesh(GRASS_ITEM_ID, grass_mesh)
		ml.set_item_mesh_transform(GRASS_ITEM_ID,
				Transform3D(Basis.IDENTITY, Vector3(0.0, gy, 0.0)))
	else:
		var quad := PlaneMesh.new()
		quad.size = Vector2(0.98, 0.98)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.60, 0.22)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		quad.material = mat
		ml.set_item_mesh(GRASS_ITEM_ID, quad)
	ground_gridmap.mesh_library = ml

## Fills the 512×512 background with grass, spread over multiple frames.
## Skips cells already occupied by a building so that a startup map-load
## doesn't get its tiles covered over by the coroutine finishing later.
func _fill_grass_background() -> void:
	for x in range(-GRASS_GRID_HALF, GRASS_GRID_HALF):
		for z in range(-GRASS_GRID_HALF, GRASS_GRID_HALF):
			if gridmap.get_cell_item(Vector3i(x, 0, z)) == GridMap.INVALID_CELL_ITEM:
				ground_gridmap.set_cell_item(Vector3i(x, 0, z), GRASS_ITEM_ID, 0)
		if x % 16 == 0:
			await get_tree().process_frame

# ── Footprint helpers ──────────────────────────────────────────────────────────

static func _rotate_offset(offset: Vector2i, steps: int) -> Vector2i:
	var v := offset
	for _i in (steps % 4):
		v = Vector2i(v.y, -v.x)
	return v

func _get_footprint_cells(anchor: Vector2i, structure_idx: int, rot_steps: int) -> Array[Vector2i]:
	var fp: Array[Vector2i] = structures[structure_idx].footprint
	if fp.is_empty():
		fp = [Vector2i(0, 0)]
	var result: Array[Vector2i] = []
	for offset in fp:
		result.append(anchor + _rotate_offset(offset, rot_steps))
	return result

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
	var orient   := gridmap.get_orthogonal_index_from_basis(selector.basis)

	# Collect any buildings that need to be cleared
	var occupied_bids: Array[int] = []
	for cell: Vector2i in fp_cells:
		var bid: int = GameState.cell_to_building.get(cell, -1)
		if bid >= 0 and bid not in occupied_bids:
			occupied_bids.append(bid)

	if not occupied_bids.is_empty():
		# Only ask before demolishing proper buildings; roads/decorative go silently.
		var has_building := occupied_bids.any(func(bid):
			var sid: int = GameState.building_registry.get(bid, {}).get("structure", -1)
			return _is_building_structure(sid))

		if has_building:
			_overbuild_pending  = true
			_overbuild_anchor   = anchor
			_overbuild_orient   = orient
			_overbuild_index    = index
			_overbuild_fp_cells = fp_cells
			_overbuild_dialog.popup_centered()
			return

		# Roads / decorative — demolish silently then place
		for bid: int in occupied_bids:
			_demolish_by_bid(bid)

	_do_build(anchor, index, orient, fp_cells)

func _on_overbuild_confirmed() -> void:
	_overbuild_pending = false
	# Demolish all buildings occupying the footprint
	var occupied_bids: Array[int] = []
	for cell: Vector2i in _overbuild_fp_cells:
		var bid: int = GameState.cell_to_building.get(cell, -1)
		if bid >= 0 and bid not in occupied_bids:
			occupied_bids.append(bid)
	for bid: int in occupied_bids:
		_demolish_by_bid(bid)
	_do_build(_overbuild_anchor, _overbuild_index, _overbuild_orient, _overbuild_fp_cells)

func _do_build(anchor: Vector2i, struct_idx: int, orient: int, fp_cells: Array[Vector2i]) -> void:
	var bid := GameState._next_building_id
	GameState._next_building_id += 1

	gridmap.set_cell_item(Vector3i(anchor.x, 0, anchor.y), struct_idx, orient)

	for cell: Vector2i in fp_cells:
		GameState.cell_to_building[cell] = bid
		ground_gridmap.set_cell_item(Vector3i(cell.x, 0, cell.y), -1, 0)

	GameState.building_registry[bid] = {
		"anchor": anchor,
		"structure": struct_idx,
		"orientation": orient,
		"cells": fp_cells
	}

	if _is_road_structure(struct_idx):
		_retile_road_at(anchor)
		for dir in [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]:
			var nb: Vector2i = anchor + dir
			var nb_bid: int = GameState.cell_to_building.get(nb, -1)
			if nb_bid >= 0:
				var nb_sid: int = GameState.building_registry.get(nb_bid, {}).get("structure", -1)
				if nb_sid >= 0 and _is_road_structure(nb_sid):
					_retile_road_at(nb)

	map.cash -= structures[struct_idx].price
	update_cash()
	GameEvents.cash_changed.emit(map.cash)

	var placed_pos := Vector3i(anchor.x, 0, anchor.y)
	GameEvents.structure_placed.emit(placed_pos, struct_idx, orient)

	Audio.play("sounds/placement-a.ogg, sounds/placement-b.ogg, sounds/placement-c.ogg, sounds/placement-d.ogg", -20)

# ── Demolish ──────────────────────────────────────────────────────────────────

func action_demolish(gridmap_position):
	var clicked_cell := Vector2i(int(gridmap_position.x), int(gridmap_position.z))

	var trigger := false
	if Input.is_action_just_pressed("demolish"):
		_erase_last_cell = Vector2i(-99999, -99999)
		trigger = true
	elif Input.is_action_pressed("demolish") and clicked_cell != _erase_last_cell:
		trigger = true

	if not trigger:
		return
	_erase_last_cell = clicked_cell

	if not GameState.cell_to_building.has(clicked_cell):
		return
	var bid: int = GameState.cell_to_building[clicked_cell]
	_demolish_by_bid(bid)
	Audio.play("sounds/removal-a.ogg, sounds/removal-b.ogg, sounds/removal-c.ogg, sounds/removal-d.ogg", -20)

func _demolish_by_bid(bid: int) -> void:
	var entry: Dictionary = GameState.building_registry.get(bid, {})
	var anchor: Vector2i  = entry.get("anchor", Vector2i.ZERO)
	var cells: Array      = entry.get("cells", [])

	for cell in cells:
		GameState.cell_to_building.erase(cell)

	gridmap.set_cell_item(Vector3i(anchor.x, 0, anchor.y), -1)
	GameState.building_registry.erase(bid)

	# Restore grass under the demolished footprint
	for cell in cells:
		ground_gridmap.set_cell_item(Vector3i(cell.x, 0, cell.y), GRASS_ITEM_ID, 0)

	GameEvents.structure_demolished.emit(Vector3i(anchor.x, 0, anchor.y))

	# Retile neighbouring roads
	for dir in [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]:
		var nb: Vector2i = anchor + dir
		var nb_bid: int  = GameState.cell_to_building.get(nb, -1)
		if nb_bid >= 0:
			var nb_sid: int = GameState.building_registry.get(nb_bid, {}).get("structure", -1)
			if nb_sid >= 0 and _is_road_structure(nb_sid):
				_retile_road_at(nb)

# ── Rotate the 'cursor' ───────────────────────────────────────────────────────

func action_rotate():
	if Input.is_action_just_pressed("rotate"):
		selector.rotate_y(deg_to_rad(90))
		_rotation_steps = (_rotation_steps + 1) % 4
		Audio.play("sounds/rotate.ogg", -30)

# ── Toggle between structures ─────────────────────────────────────────────────

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
	for n in selector_container.get_children():
		selector_container.remove_child(n)
		n.queue_free()
	_preview_indicators.clear()

	var _model = structures[index].model.instantiate()
	selector_container.add_child(_model)
	var s := structures[index].model_scale
	_model.scale = Vector3.ONE * s
	_model.rotation_degrees.y = structures[index].model_rotation_y
	var mesh: Mesh = get_mesh(structures[index].model)
	var ground_offset := -mesh.get_aabb().position.y * s if mesh else 0.0

	# Same auto-centring as the MeshLibrary so the preview matches what gets placed.
	var fp: Array[Vector2i] = structures[index].footprint
	if fp.is_empty():
		fp = [Vector2i(0, 0)]
	var fp_cx := 0.0
	var fp_cz := 0.0
	for off: Vector2i in fp:
		fp_cx += off.x
		fp_cz += off.y
	fp_cx /= fp.size()
	fp_cz /= fp.size()

	_model.position = structures[index].model_offset + Vector3(fp_cx, ground_offset + 0.25, fp_cz)

	for offset: Vector2i in fp:
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

func _find_road_indices() -> void:
	for i in structures.size():
		var meta: RoadMetadata = structures[i].find_metadata(RoadMetadata) as RoadMetadata
		if not meta:
			continue
		match meta.road_type:
			RoadMetadata.RoadType.STRAIGHT:
				if _road_straight_idx < 0: _road_straight_idx = i
			RoadMetadata.RoadType.CORNER:
				if _road_corner_idx < 0:   _road_corner_idx = i
			RoadMetadata.RoadType.SPLIT:
				if _road_split_idx < 0:    _road_split_idx = i
			RoadMetadata.RoadType.INTERSECTION:
				if _road_intersection_idx < 0: _road_intersection_idx = i

func _is_road_structure(struct_idx: int) -> bool:
	if struct_idx < 0 or struct_idx >= structures.size():
		return false
	return structures[struct_idx].find_metadata(RoadMetadata) != null

## Returns true for proper buildings — those that warrant a confirmation before
## being demolished.  Roads and decorative tiles (no BuildingProfile/police/medical
## metadata) return false and are overwritten silently.
func _is_building_structure(struct_idx: int) -> bool:
	if struct_idx < 0 or struct_idx >= structures.size():
		return false
	var s := structures[struct_idx]
	return s.find_metadata(BuildingProfile) != null \
		or s.find_metadata(PoliceMetadata) != null \
		or s.find_metadata(MedicalMetadata) != null

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

func _road_for_mask(mask: int) -> Array:
	var s  := _road_straight_idx     if _road_straight_idx >= 0     else 0
	var c  := _road_corner_idx       if _road_corner_idx >= 0       else s
	var sp := _road_split_idx        if _road_split_idx >= 0        else s
	var x  := _road_intersection_idx if _road_intersection_idx >= 0 else s
	var lookup := [
		[s,  0 ], [s,  0 ], [s,  16], [c,  10],
		[s,  0 ], [s,  0 ], [c,  16], [sp, 16],
		[s,  16], [c,  22], [s,  16], [sp, 10],
		[c,  0 ], [sp, 22], [sp, 0 ], [x,  0 ],
	]
	if mask < 0 or mask > 15:
		return [s, 0]
	return lookup[mask]

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
	var new_sid: int    = result[0]
	var new_orient: int = result[1]
	if new_sid < 0:
		return
	gridmap.set_cell_item(Vector3i(anchor.x, 0, anchor.y), new_sid, new_orient)
	entry["structure"]   = new_sid
	entry["orientation"] = new_orient
	GameState.building_registry[bid] = entry

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
		ds.position    = entry["anchor"]
		ds.orientation = entry["orientation"]
		ds.structure   = entry["structure"]
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
	if Input.is_action_just_pressed("save_slot1"): _save_to(SAVE_SLOT_1, "Saved — Slot 1")

func action_load_temp():
	if Input.is_action_just_pressed("load_temp"):  _load_from(SAVE_TEMP, "Loaded — Temp")

func action_save_slot2():
	if Input.is_action_just_pressed("save_slot2"): _save_to(SAVE_SLOT_2, "Saved — Slot 2")

func action_load_slot2():
	if Input.is_action_just_pressed("load_slot2"): _load_from(SAVE_SLOT_2, "Loaded — Slot 2")

func action_clear():
	if Input.is_action_just_pressed("clear"):
		_apply_map(DataMap.new())
		GameState.map = map
		GameEvents.map_loaded.emit(map)
		show_toast("Map cleared")

## Shared helper: clear all building state and rebuild from a DataMap.
## Restores grass under old buildings and removes it under new ones.
func _apply_map(loaded_map: DataMap) -> void:
	_overbuild_pending = false
	map = loaded_map
	GameState.map = map

	# Restore grass under all currently-placed buildings before wiping the registry
	for bid in GameState.building_registry:
		for cell in GameState.building_registry[bid]["cells"]:
			ground_gridmap.set_cell_item(Vector3i(cell.x, 0, cell.y), GRASS_ITEM_ID, 0)

	# Clear visual tiles and occupancy tracking
	gridmap.clear()
	GameState.cell_to_building.clear()
	GameState.building_registry.clear()
	GameState._next_building_id = 0

	for ds in loaded_map.structures:
		var bid := GameState._next_building_id
		GameState._next_building_id += 1

		var cells: Array[Vector2i] = []
		if ds.footprint_cells.is_empty():
			cells = _get_footprint_cells(ds.position, ds.structure, _orientation_to_steps(ds.orientation))
		else:
			for c in ds.footprint_cells:
				cells.append(c)

		gridmap.set_cell_item(Vector3i(ds.position.x, 0, ds.position.y), ds.structure, ds.orientation)

		for cell in cells:
			GameState.cell_to_building[cell] = bid
			ground_gridmap.set_cell_item(Vector3i(cell.x, 0, cell.y), -1, 0)

		GameState.building_registry[bid] = {
			"anchor":      ds.position,
			"structure":   ds.structure,
			"orientation": ds.orientation,
			"cells":       cells
		}

	update_cash()
