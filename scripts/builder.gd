extends Node3D

## Populated from BuildingCatalog at _ready(). Was @export before M0; now sourced
## from res://data/buildings/**/*.json via the plugin so new buildings are added
## by dropping a JSON file, no scene edits required.
var structures: Array[Structure] = []
var _catalog: PluginBase  # BuildingCatalog plugin reference (dynamic typing avoids circular preload)
var _demand:   PluginBase  # Demand plugin reference — may be null if plugin disabled
var _economy:  PluginBase  # Economy plugin reference — gates decorative placement on cash
var _palette:  PluginBase  # Palette plugin — owns the cyclable build menu
var _land:     PluginBase  # BuildableArea — gates placement to allowed cells
var _dialogue: PluginBase  # Dialogue plugin — suppresses input while a modal is open
var _uniques:  PluginBase  # UniqueRegistry — authoritative one-of-a-kind rules
var _community_inspect_mode: bool = false
var _radial_input_active: bool = false
var _placement_active: bool = false
var _demolition_active: bool = false
var _placement_block_frame: int = -1
var _input_mode: String = "world"

const INPUT_MODES := ["world", "radial", "placement", "demolition", "inspection", "modal"]

var map: DataMap

var _preview_idx: int = -1       # Structure index the cursor currently previews
var _rotation_steps: int = 0     # 0–3, incremented by action_rotate()
var _preview_indicators: Array[Sprite3D] = []

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

	# UI contracts and accessibility are authored against the actual desktop
	# viewport. A forced 2× scale reduced 1280×720 to a 640×360 logical canvas
	# and caused the HUD/sidebar to overlap.
	get_window().content_scale_factor = 1.0

	map = DataMap.new()
	plane = Plane(Vector3.UP, Vector3.ZERO)

	# Pull the building catalogue from JSON before anything else — the MeshLibrary
	# is built from `structures` below, so this has to happen first.
	_catalog = PluginManager.get_plugin("BuildingCatalog")
	if _catalog:
		_catalog.ensure_loaded()
		structures = _catalog.get_all()
	else:
		push_error("[Builder] BuildingCatalog plugin missing — no structures will load")

	_demand   = PluginManager.get_plugin("Demand")
	_economy  = PluginManager.get_plugin("Economy")
	_palette  = PluginManager.get_plugin("Palette")
	_land     = PluginManager.get_plugin("BuildableArea")
	_dialogue = PluginManager.get_plugin("Dialogue")
	_uniques  = PluginManager.get_plugin("UniqueRegistry")

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

	GameState.gridmap = gridmap
	GameState.structures = structures

	GameEvents.palette_changed.connect(_on_palette_changed)
	GameEvents.community_inspect_mode_changed.connect(func(active): _community_inspect_mode = active)

	# Set up overbuild confirmation dialog
	_overbuild_dialog = ConfirmationDialog.new()
	_overbuild_dialog.title = "Replace Building?"
	_overbuild_dialog.dialog_text = "Demolish the existing building(s) here and build?"
	_overbuild_dialog.ok_button_text = "Replace"
	add_child(_overbuild_dialog)
	_overbuild_dialog.confirmed.connect(_on_overbuild_confirmed)
	_overbuild_dialog.canceled.connect(func(): _overbuild_pending = false)

	if ResourceLoader.exists(SAVE_SLOT_1):
		var slot1 = ResourceLoader.load(SAVE_SLOT_1)
		if slot1:
			_apply_map(slot1)

	_fill_grass_background()

	GameState.map = map
	print("[Builder] ready: structures=%d" % structures.size())
	GameState._notify_ready()

func _process(delta):
	var dialogue_open: bool = bool(_dialogue and _dialogue.is_input_suppressed())
	var requested := resolve_input_mode(dialogue_open or _overbuild_pending,
		_radial_input_active, _community_inspect_mode, _demolition_active or Input.is_action_pressed("demolish"), _placement_active)
	_set_input_mode(requested)
	if _input_mode == "modal" or _input_mode == "radial":
		return
	if _input_mode == "placement" and Input.is_action_just_pressed("ui_cancel"):
		cancel_placement()
		return
	if _input_mode == "demolition" and Input.is_action_just_pressed("ui_cancel"):
		set_demolition_active(false)
		return

	if _input_mode == "placement":
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
	if _input_mode == "placement":
		_update_preview_color(anchor)
	elif _input_mode == "demolition":
		_set_selector_feedback("demolition-cursor")
	elif _input_mode == "inspection":
		_set_selector_feedback("inspect-select-cursor")

	# Explicit Community inspect mode consumes the click before placement or
	# demolition, then publishes only the canonical building anchor.
	if _input_mode == "inspection":
		if Input.is_action_just_pressed("build"):
			var building_instance_id := int(GameState.cell_to_building.get(anchor, -1))
			var selected_anchor := anchor
			if building_instance_id >= 0:
				selected_anchor = GameState.building_registry.get(building_instance_id, {}).get("anchor", anchor)
			GameEvents.community_place_selected.emit(selected_anchor)
		return

	if _input_mode == "placement":
		action_build(gridmap_position)
	elif _input_mode == "demolition":
		action_demolish(gridmap_position)

static func resolve_input_mode(modal: bool, radial: bool, inspection: bool,
		demolition: bool, placement: bool) -> String:
	if modal: return "modal"
	if radial: return "radial"
	if inspection: return "inspection"
	if demolition: return "demolition"
	if placement: return "placement"
	return "world"

func set_radial_input_active(active: bool) -> void:
	_radial_input_active = active
	if active and selector:
		selector.visible = false

func begin_placement_from_palette() -> bool:
	if _palette == null:
		return false
	_preview_idx = _palette.current_structure_index()
	if _preview_idx < 0:
		return false
	_placement_active = true
	_demolition_active = false
	_placement_block_frame = Engine.get_process_frames()
	if selector:
		selector.visible = true
	update_structure()
	_emit_placement_context()
	return true

func cancel_placement() -> void:
	_placement_active = false
	_preview_idx = -1
	if selector:
		selector.visible = false
	update_structure()
	_emit_placement_context()

func set_demolition_active(active: bool) -> void:
	_demolition_active = active
	if active:
		cancel_placement()
		if selector: selector.visible = true
	else:
		if selector: selector.visible = false
	_emit_placement_context()

func get_input_mode() -> String:
	return _input_mode

func is_placement_active() -> bool:
	return _placement_active

func _set_input_mode(mode: String) -> void:
	if mode == _input_mode:
		return
	_input_mode = mode
	GameEvents.player_input_mode_changed.emit(mode)
	_emit_placement_context()

func _emit_placement_context(reason: String = "") -> void:
	GameEvents.placement_context_changed.emit({
		"mode": _input_mode,
		"active": _placement_active,
		"structure_index": _preview_idx,
		"rotation": _rotation_steps,
		"reason": reason,
	})

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

static func _steps_to_orientation(steps: int) -> int:
	return [0, 16, 10, 22][steps]

func _reject_evaluation(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"ok": false, "reason": reason, "details": details}

func _resolve_structure(requested_id: String, variant_id: String = "", rng: RandomNumberGenerator = null) -> Dictionary:
	if _catalog == null:
		return _reject_evaluation(PlaytestActionResult.UNKNOWN_BUILDING, {"requested_id": requested_id})
	var exact_idx: int = _catalog.get_item_index(requested_id)
	if exact_idx >= 0:
		return {"ok": true, "index": exact_idx, "building_id": requested_id, "choice_id": requested_id}
	var pool_indices: Array[int] = _catalog.get_pool_indices(requested_id)
	if pool_indices.is_empty():
		return _reject_evaluation(PlaytestActionResult.UNKNOWN_BUILDING, {"requested_id": requested_id})
	var chosen_idx: int = -1
	if not variant_id.is_empty():
		chosen_idx = _catalog.get_item_index(variant_id)
		if chosen_idx not in pool_indices:
			return _reject_evaluation(PlaytestActionResult.UNKNOWN_BUILDING, {
				"requested_id": requested_id, "variant_id": variant_id,
			})
	else:
		var pick := rng.randi_range(0, pool_indices.size() - 1) if rng else randi_range(0, pool_indices.size() - 1)
		chosen_idx = pool_indices[pick]
	return {
		"ok": true,
		"index": chosen_idx,
		"building_id": _catalog.get_id_by_index(chosen_idx),
		"choice_id": requested_id,
	}

## Evaluates every placement gate without changing cash, demand, registries, or
## GridMaps. Pool selection uses the supplied session RNG when present.
func evaluate_placement(requested_id: String, anchor: Vector2i, rotation_steps: int = 0,
		replace: bool = false, variant_id: String = "", rng: RandomNumberGenerator = null) -> Dictionary:
	if rotation_steps < 0 or rotation_steps > 3:
		return _reject_evaluation(PlaytestActionResult.INVALID_ROTATION, {"rotation": rotation_steps})
	var resolved := _resolve_structure(requested_id, variant_id, rng)
	if not resolved["ok"]:
		return resolved
	var struct_idx: int = resolved["index"]
	var structure: Structure = structures[struct_idx]
	var fp_cells := _get_footprint_cells(anchor, struct_idx, rotation_steps)
	var details := {
		"choice_id": resolved["choice_id"],
		"building_id": resolved["building_id"],
		"structure_index": struct_idx,
		"anchor": anchor,
		"rotation": rotation_steps,
		"orientation": _steps_to_orientation(rotation_steps),
		"footprint": fp_cells,
		"occupied_building_ids": [],
	}

	if _land:
		for cell: Vector2i in fp_cells:
			if not _land.is_allowed(cell):
				details["blocked_cell"] = cell
				return _reject_evaluation(PlaytestActionResult.OUTSIDE_BUILDABLE_AREA, details)

	var occupied_bids: Array[int] = []
	for cell: Vector2i in fp_cells:
		var bid: int = GameState.cell_to_building.get(cell, -1)
		if bid >= 0 and bid not in occupied_bids:
			occupied_bids.append(bid)
	details["occupied_building_ids"] = occupied_bids
	if not occupied_bids.is_empty() and not replace:
		var has_proper_building := occupied_bids.any(func(bid: int):
			var sid: int = GameState.building_registry.get(bid, {}).get("structure", -1)
			return _is_building_structure(sid))
		var reason := PlaytestActionResult.REPLACEMENT_REQUIRED if has_proper_building else PlaytestActionResult.OCCUPIED_FOOTPRINT
		return _reject_evaluation(reason, details)

	if _uniques and _uniques.is_unique(resolved["building_id"]):
		if _uniques.is_placed(resolved["building_id"]):
			return _reject_evaluation(PlaytestActionResult.UNIQUE_ALREADY_PLACED, details)
		if not _uniques.is_unlocked(resolved["building_id"]):
			var profile: UniqueProfile = _uniques.get_profile(resolved["building_id"])
			if profile:
				var missing: Array[String] = []
				for prereq in profile.prerequisite_ids:
					if not _uniques.is_placed(String(prereq)):
						missing.append(String(prereq))
				if not missing.is_empty():
					details["missing_prerequisites"] = missing
					return _reject_evaluation(PlaytestActionResult.UNMET_PREREQUISITE, details)
				details["threshold"] = profile.prerequisite_threshold
			return _reject_evaluation(PlaytestActionResult.BELOW_DEMAND_THRESHOLD, details)

	var cash_quote: Dictionary = _economy.quote_cash(structure) if _economy else {"ok": true, "cost": 0, "have": 0, "reason": ""}
	details["cash"] = cash_quote
	if not cash_quote["ok"]:
		return _reject_evaluation(PlaytestActionResult.INSUFFICIENT_CASH, details)
	var demand_quote: Dictionary = _demand.quote_placement(structure) if _demand else {
		"ok": true, "bucket_id": "", "cost": 0.0, "have": 0.0, "threshold": 0.0, "reason": "",
	}
	details["demand"] = demand_quote
	if not demand_quote["ok"]:
		var demand_reason := PlaytestActionResult.BELOW_DEMAND_THRESHOLD if demand_quote["reason"] == "below_threshold" else PlaytestActionResult.INSUFFICIENT_DEMAND
		return _reject_evaluation(demand_reason, details)
	return {"ok": true, "reason": "", "details": details}

## Authoritative atomic placement command shared by UI and playtest automation.
func try_place_building(requested_id: String, anchor: Vector2i, rotation_steps: int = 0,
		replace: bool = false, variant_id: String = "", rng: RandomNumberGenerator = null) -> Dictionary:
	var evaluation := evaluate_placement(requested_id, anchor, rotation_steps, replace, variant_id, rng)
	if not evaluation["ok"]:
		return PlaytestActionResult.rejected(evaluation["reason"], evaluation["details"])
	var details: Dictionary = evaluation["details"]
	for bid: int in details["occupied_building_ids"]:
		_demolish_by_bid(bid)
	var struct_idx: int = details["structure_index"]
	# Both quotes were validated synchronously above; no mutation occurs before
	# this commit section, so neither spend can reject here.
	if _economy:
		_economy.try_spend_cash(structures[struct_idx])
	if _demand:
		_demand.try_spend(structures[struct_idx])
	_commit_build(anchor, struct_idx, details["orientation"], details["footprint"])
	return PlaytestActionResult.applied(details)

# ── Build (place) a structure ──────────────────────────────────────────────────

func action_build(gridmap_position):
	if _preview_idx < 0:
		return
	if Engine.get_process_frames() <= _placement_block_frame:
		return
	var anchor := Vector2i(int(gridmap_position.x), int(gridmap_position.z))
	var is_road := _is_road_structure(_preview_idx)

	var trigger := false
	if Input.is_action_just_pressed("build"):
		_paint_last_cell = Vector2i(-99999, -99999)
		trigger = true
	elif is_road and Input.is_action_pressed("build") and anchor != _paint_last_cell:
		trigger = true

	if not trigger:
		return
	_paint_last_cell = anchor

	# Palette pool-pick: the preview shows a stable representative, but each
	# LMB rolls a fresh random from the pool so repeat placements vary.
	var build_idx := _preview_idx
	if _palette and _palette.has_method("pick_structure_index_for_build"):
		var picked: int = _palette.pick_structure_index_for_build()
		if picked >= 0:
			build_idx = picked

	var fp_cells := _get_footprint_cells(anchor, build_idx, _rotation_steps)
	var building_id: String = _catalog.get_id_by_index(build_idx) if _catalog else ""

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
			_overbuild_orient   = _steps_to_orientation(_rotation_steps)
			_overbuild_index    = build_idx
			_overbuild_fp_cells = fp_cells
			_overbuild_dialog.popup_centered()
			return

	var outcome := try_place_building(building_id, anchor, _rotation_steps, not occupied_bids.is_empty())
	_show_placement_outcome(outcome)
	if outcome["status"] == PlaytestActionResult.STATUS_APPLIED:
		Audio.play("sounds/placement-a.ogg, sounds/placement-b.ogg, sounds/placement-c.ogg, sounds/placement-d.ogg", -20)

func _on_overbuild_confirmed() -> void:
	_overbuild_pending = false
	var building_id: String = _catalog.get_id_by_index(_overbuild_index) if _catalog else ""
	var outcome := try_place_building(building_id, _overbuild_anchor,
		_orientation_to_steps(_overbuild_orient), true)
	_show_placement_outcome(outcome)
	if outcome["status"] == PlaytestActionResult.STATUS_APPLIED:
		Audio.play("sounds/placement-a.ogg, sounds/placement-b.ogg, sounds/placement-c.ogg, sounds/placement-d.ogg", -20)

func _commit_build(anchor: Vector2i, struct_idx: int, orient: int, fp_cells: Array[Vector2i]) -> void:
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

	var placed_pos := Vector3i(anchor.x, 0, anchor.y)
	GameEvents.structure_placed.emit(placed_pos, struct_idx, orient)

func _show_placement_outcome(outcome: Dictionary) -> void:
	if outcome.get("status", "") != PlaytestActionResult.STATUS_REJECTED:
		return
	var details: Dictionary = outcome.get("details", {})
	match outcome.get("reason", ""):
		PlaytestActionResult.OUTSIDE_BUILDABLE_AREA:
			show_toast("Outside buildable area")
		PlaytestActionResult.INSUFFICIENT_CASH:
			var q: Dictionary = details.get("cash", {})
			show_toast("Need $%d more (have $%d / $%d)" % [int(q.get("cost", 0)) - int(q.get("have", 0)), int(q.get("have", 0)), int(q.get("cost", 0))])
		PlaytestActionResult.BELOW_DEMAND_THRESHOLD:
			var q: Dictionary = details.get("demand", {})
			var short_name: String = _demand.bucket_display_name(q.get("bucket_id", "")) if _demand else ""
			show_toast("%s tier locked — need %d %s demand" % [short_name.capitalize(), int(q.get("threshold", details.get("threshold", 0))), short_name])
		PlaytestActionResult.INSUFFICIENT_DEMAND:
			var q: Dictionary = details.get("demand", {})
			var short_name: String = _demand.bucket_display_name(q.get("bucket_id", "")) if _demand else ""
			show_toast("Need %d more %s demand (have %d / %d)" % [int(ceil(float(q.get("cost", 0)) - float(q.get("have", 0)))), short_name, int(q.get("have", 0)), int(q.get("cost", 0))])
		PlaytestActionResult.UNIQUE_ALREADY_PLACED:
			show_toast("Unique building already placed")
		PlaytestActionResult.UNMET_PREREQUISITE:
			show_toast("Building prerequisite not met")
		_:
			show_toast("Cannot place here")

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

	var outcome := try_demolish_cell(clicked_cell)
	if outcome["status"] == PlaytestActionResult.STATUS_APPLIED:
		Audio.play("sounds/removal-a.ogg, sounds/removal-b.ogg, sounds/removal-c.ogg, sounds/removal-d.ogg", -20)
	elif outcome["reason"] == PlaytestActionResult.DEMOLITION_NOT_ALLOWED:
		show_toast("Outside buildable area")

func try_demolish_cell(cell: Vector2i) -> Dictionary:
	if not GameState.cell_to_building.has(cell):
		return PlaytestActionResult.rejected(PlaytestActionResult.NOTHING_TO_DEMOLISH, {"cell": cell})
	if _land and not _land.is_allowed(cell):
		return PlaytestActionResult.rejected(PlaytestActionResult.DEMOLITION_NOT_ALLOWED, {"cell": cell})
	var bid: int = GameState.cell_to_building[cell]
	return PlaytestActionResult.applied(_demolish_by_bid(bid))

func _demolish_by_bid(bid: int) -> Dictionary:
	var entry: Dictionary = GameState.building_registry.get(bid, {})
	if entry.is_empty():
		return {}
	var anchor: Vector2i  = entry.get("anchor", Vector2i.ZERO)
	var cells: Array      = entry.get("cells", [])
	var struct_idx: int = entry.get("structure", -1)
	var building_id: String = _catalog.get_id_by_index(struct_idx) if _catalog and struct_idx >= 0 else ""

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
	return {"building_id": building_id, "anchor": anchor, "footprint": cells}

# ── Rotate the 'cursor' ───────────────────────────────────────────────────────

func action_rotate():
	if Input.is_action_just_pressed("rotate"):
		selector.rotate_y(deg_to_rad(90))
		_rotation_steps = (_rotation_steps + 1) % 4
		_emit_placement_context()
		Audio.play("sounds/rotate.ogg", -30)

# ── Toggle between structures ─────────────────────────────────────────────────

func action_structure_toggle():
	if _palette == null:
		return
	# Preview refresh happens via _on_palette_changed() — no direct call here.
	if Input.is_action_just_pressed("structure_next"):
		_palette.select_next()
		Audio.play("sounds/toggle.ogg", -30)
	if Input.is_action_just_pressed("structure_previous"):
		_palette.select_previous()
		Audio.play("sounds/toggle.ogg", -30)

# ── Update the structure visual in the 'cursor' ───────────────────────────────

func _on_palette_changed(_ids: Array, selected_id: String) -> void:
	if _palette == null:
		return
	if not _placement_active:
		return
	var new_idx: int = _palette.current_structure_index()
	if selected_id.is_empty():
		cancel_placement()
		return
	if new_idx == _preview_idx:
		return
	_preview_idx = new_idx
	update_structure()
	_emit_placement_context()

func update_structure():
	for n in selector_container.get_children():
		selector_container.remove_child(n)
		n.queue_free()
	_preview_indicators.clear()

	if _preview_idx < 0 or _preview_idx >= structures.size():
		return

	var struct: Structure = structures[_preview_idx]
	var _model = struct.model.instantiate()
	selector_container.add_child(_model)
	var s := struct.model_scale
	_model.scale = Vector3.ONE * s
	_model.rotation_degrees.y = struct.model_rotation_y
	var mesh: Mesh = get_mesh(struct.model)
	var ground_offset := -mesh.get_aabb().position.y * s if mesh else 0.0

	# Same auto-centring as the MeshLibrary so the preview matches what gets placed.
	var fp: Array[Vector2i] = struct.footprint
	if fp.is_empty():
		fp = [Vector2i(0, 0)]
	var fp_cx := 0.0
	var fp_cz := 0.0
	for off: Vector2i in fp:
		fp_cx += off.x
		fp_cz += off.y
	fp_cx /= fp.size()
	fp_cz /= fp.size()

	_model.position = struct.model_offset + Vector3(fp_cx, ground_offset + 0.25, fp_cz)

	for offset: Vector2i in fp:
		var indicator := _make_cell_indicator()
		indicator.position = Vector3(offset.x, 0.05, offset.y)
		selector_container.add_child(indicator)
		_preview_indicators.append(indicator)

func _make_cell_indicator() -> Sprite3D:
	var marker := Sprite3D.new()
	marker.texture = load("res://sprites/ui/build-menu/map-feedback/affordable-placement-marker.png")
	marker.pixel_size = 0.007
	marker.rotation_degrees.x = -90.0
	marker.no_depth_test = true
	marker.render_priority = 2
	return marker

func _update_preview_color(anchor: Vector2i) -> void:
	if _preview_indicators.is_empty() or _preview_idx < 0:
		return
	var fp_cells := _get_footprint_cells(anchor, _preview_idx, _rotation_steps)
	var is_valid := true
	var replacement := false
	for cell in fp_cells:
		if GameState.cell_to_building.has(cell):
			is_valid = false
			replacement = true
			break
		# Outside the buildable-area mask → preview turns red so the player
		# sees they can't place there before clicking.
		if _land and not _land.is_allowed(cell):
			is_valid = false
			break
	for ind in _preview_indicators:
		ind.texture = load("res://sprites/ui/build-menu/map-feedback/%s.png" % (
			"affordable-placement-marker" if is_valid else ("replacement-overbuild-marker" if replacement else "blocked-footprint-marker")))
	_set_selector_feedback("valid-placement-cursor" if is_valid else "invalid-placement-cursor")

func _set_selector_feedback(asset_id: String) -> void:
	if selector == null:
		return
	var sprite := selector.get_node_or_null("Sprite") as Sprite3D
	var path := "res://sprites/ui/build-menu/map-feedback/%s.png" % asset_id
	if sprite and ResourceLoader.exists(path):
		sprite.texture = load(path)
		sprite.pixel_size = 0.007

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
## being demolished.  Roads and decorative tiles (no BuildingProfile metadata)
## return false and are overwritten silently.
func _is_building_structure(struct_idx: int) -> bool:
	if struct_idx < 0 or struct_idx >= structures.size():
		return false
	var s := structures[struct_idx]
	return s.find_metadata(BuildingProfile) != null

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

func show_toast(message: String) -> void:
	if toast_label == null:
		return
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
		ds.building_id = _catalog.get_id_by_index(entry["structure"]) if _catalog else ""
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
		reset_to_fresh_map()
		show_toast("Map cleared")

## Applies a canonical empty map through the same reconciliation signal used by
## save loading. DataMap supplies starting cash; BuildableArea seeds starter land.
func reset_to_fresh_map(fresh_map: DataMap = null) -> Dictionary:
	var next_map := fresh_map if fresh_map else DataMap.new()
	_apply_map(next_map)
	GameState.map = map
	GameEvents.map_loaded.emit(map)
	return PlaytestActionResult.applied({
		"cash": map.cash,
		"structures": map.structures.size(),
		"next_building_id": GameState._next_building_id,
	})

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

	print("[DataMap] load: structures=%d" % loaded_map.structures.size())

	for ds in loaded_map.structures:
		if _catalog == null or ds.building_id.is_empty():
			continue
		var struct_idx: int = _catalog.get_item_index(ds.building_id)
		if struct_idx < 0:
			push_warning("[Builder] skip_unknown_building: building_id=%s" % ds.building_id)
			continue

		var bid := GameState._next_building_id
		GameState._next_building_id += 1

		var cells: Array[Vector2i] = []
		if ds.footprint_cells.is_empty():
			cells = _get_footprint_cells(ds.position, struct_idx, _orientation_to_steps(ds.orientation))
		else:
			for c in ds.footprint_cells:
				cells.append(c)

		gridmap.set_cell_item(Vector3i(ds.position.x, 0, ds.position.y), struct_idx, ds.orientation)

		for cell in cells:
			GameState.cell_to_building[cell] = bid
			ground_gridmap.set_cell_item(Vector3i(cell.x, 0, cell.y), -1, 0)

		GameState.building_registry[bid] = {
			"anchor":      ds.position,
			"structure":   struct_idx,
			"orientation": ds.orientation,
			"cells":       cells
		}
