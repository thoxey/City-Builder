extends SceneTree

## Catalogue-wide ground-contact audit renderer.
##
## This script deliberately consumes BuildingCatalog and reproduces Builder's
## first-mesh, footprint-centering, authored-transform, and GroundMap policies.
## It writes one four-rotation contact sheet per catalogue entry together with
## the machine-readable model inventory used by feature 020.

const FEATURE_ROOT := "res://specs/020-building-ground-contact"
const VALIDATION_ROOT := FEATURE_ROOT + "/validation"
const AUDIT_PATH := VALIDATION_ROOT + "/model-audit.json"
const BASELINE_PATH := VALIDATION_ROOT + "/catalogue-baseline.json"
const DECISIONS_PATH := VALIDATION_ROOT + "/audit-decisions.json"
const RESULTS_PATH := "res://artifacts/building-concepts/meshy-production/runtime-v1/results.json"

const DEFAULT_SHOT_SIZE := Vector2i(640, 360)
const ROTATIONS := [0, 1, 2, 3]
const ROTATION_DEGREES := [0, 90, 180, 270]
# The live GroundMap node is already 0.005 units below the structure GridMap.
# The underlay MeshLibrary item adds a further 0.003-unit bias.
const GROUND_MAP_Y := -0.005
const UNDERLAY_BIAS_Y := -0.003

var _phase := "before"
var _shot_size := DEFAULT_SHOT_SIZE
var _zoom_mode := "normal"
var _evidence_only := false
var _target_ids: Array[String] = []
var _catalogue
var _stage: Node3D
var _subject_root: Node3D
var _camera: Camera3D
var _label: Label
var _grass_mesh: Mesh
var _upstream_records: Dictionary = {}
var _existing_rows: Dictionary = {}
var _decisions: Dictionary = {}
var _after_review: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_read_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VALIDATION_ROOT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
		VALIDATION_ROOT + "/contact-sheets/" + _phase))
	_load_upstream_records()
	_load_existing_audit()
	_load_decisions()
	var manager := root.get_node_or_null("PluginManager")
	_catalogue = manager.get_plugin("BuildingCatalog") if manager else null
	if _catalogue == null:
		push_error("ground_contact_catalogue_unavailable")
		quit(2)
		return
	_catalogue.ensure_loaded()
	_grass_mesh = _first_mesh(_catalogue.get_by_id("grass").model) if _catalogue.get_by_id("grass") else null
	_setup_renderer()
	await _frames(4)

	var rows: Array = []
	var baseline_rows: Array = []
	var selected_count := 0
	for summary_any in _catalogue.get_summary():
		var summary: Dictionary = summary_any
		var building_id := String(summary.get("building_id", ""))
		var structure: Structure = _catalogue.get_by_id(building_id)
		baseline_rows.append(_baseline_row(summary, structure))
		if not _target_ids.is_empty() and building_id not in _target_ids:
			rows.append(_existing_rows.get(building_id, _inventory_row(summary, structure)))
			continue
		selected_count += 1
		var row := _inventory_row(summary, structure)
		var images: Array[Image] = []
		var rotation_results: Array = []
		for index in ROTATIONS.size():
			var steps: int = ROTATIONS[index]
			_build_subject(building_id, structure, steps)
			_label.text = "%s  |  %d°  |  %s  |  %s" % [
				building_id, ROTATION_DEGREES[index], _phase, _zoom_mode]
			await _frames(3)
			var image := root.get_texture().get_image()
			if image == null or image.get_size() != _shot_size:
				push_error("ground_contact_capture_failed:%s:%d:%s" % [building_id, steps, image.get_size() if image else "null"])
				quit(2)
				return
			image.convert(Image.FORMAT_RGBA8)
			images.append(image)
			rotation_results.append({
				"degrees": ROTATION_DEGREES[index],
				"evidence": _sheet_resource_path(building_id),
				"quadrant": index,
				"verdict": _prior_rotation_verdict(building_id, index),
			})
		var sheet := Image.create_empty(_shot_size.x * 2, _shot_size.y * 2, false, Image.FORMAT_RGBA8)
		for index in images.size():
			var destination := Vector2i((index % 2) * _shot_size.x, (index / 2) * _shot_size.y)
			sheet.blit_rect(images[index], Rect2i(Vector2i.ZERO, _shot_size), destination)
		var sheet_path := ProjectSettings.globalize_path(_sheet_resource_path(building_id))
		var save_error := sheet.save_png(sheet_path)
		if save_error != OK:
			push_error("ground_contact_sheet_write_failed:%s:%s" % [building_id, save_error])
			quit(2)
			return
		row["rotation_results"] = rotation_results
		_merge_review_fields(row, building_id)
		_record_phase_evidence(row, building_id)
		rows.append(row)
		print("GROUND_CONTACT_CAPTURE building_id=%s phase=%s sheet=%s" % [building_id, _phase, sheet_path])

	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("building_id", "")) < String(b.get("building_id", "")))
	baseline_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("building_id", "")) < String(b.get("building_id", "")))
	if _evidence_only:
		print("GROUND_CONTACT_EVIDENCE success=true phase=%s captured=%d renderer=%s" % [
			_phase, selected_count, RenderingServer.get_current_rendering_method()])
		quit()
		return
	var prior_audit := _read_json(AUDIT_PATH)
	var audit := {
		"schema_version": 1,
		"feature": "020-building-ground-contact",
		"catalogue_source": "BuildingCatalog.get_summary()",
		"phase": _phase,
		"renderer": RenderingServer.get_current_rendering_method(),
		"display_server": DisplayServer.get_name(),
		"engine_version": Engine.get_version_info().get("string", ""),
		"shot_viewport": {"width": _shot_size.x, "height": _shot_size.y},
		"sheet_size": {"width": _shot_size.x * 2, "height": _shot_size.y * 2},
		"zoom_mode": _zoom_mode,
		"ground_map_y": GROUND_MAP_Y,
		"underlay_bias_y": UNDERLAY_BIAS_Y,
		"effective_underlay_y": GROUND_MAP_Y + UNDERLAY_BIAS_Y,
		"catalogue_count": rows.size(),
		"captured_count": selected_count,
		"rows": rows,
	}
	if prior_audit.has("baseline"):
		audit["baseline"] = prior_audit["baseline"]
	elif _phase == "before":
		audit["baseline"] = {
			"renderer": audit["renderer"],
			"display_server": audit["display_server"],
			"engine_version": audit["engine_version"],
			"shot_viewport": audit["shot_viewport"],
		}
	_write_json(AUDIT_PATH, audit)
	if _phase == "before" or not FileAccess.file_exists(BASELINE_PATH):
		_write_json(BASELINE_PATH, {
			"schema_version": 1,
			"catalogue_source": "BuildingCatalog.get_summary()",
			"catalogue_count": baseline_rows.size(),
			"rows": baseline_rows,
		})
	print("GROUND_CONTACT_AUDIT success=true phase=%s catalogue=%d captured=%d renderer=%s" % [
		_phase, rows.size(), selected_count, audit["renderer"]])
	quit()

func _read_environment() -> void:
	_phase = OS.get_environment("CITY_BUILDER_GROUND_CONTACT_PHASE").strip_edges()
	if _phase.is_empty():
		_phase = "before"
	_zoom_mode = OS.get_environment("CITY_BUILDER_GROUND_CONTACT_ZOOM").strip_edges()
	if _zoom_mode not in ["close", "normal", "wide"]:
		_zoom_mode = "normal"
	var width := int(OS.get_environment("CITY_BUILDER_GROUND_CONTACT_WIDTH"))
	var height := int(OS.get_environment("CITY_BUILDER_GROUND_CONTACT_HEIGHT"))
	if width >= 320 and height >= 180:
		_shot_size = Vector2i(width, height)
	_evidence_only = OS.get_environment("CITY_BUILDER_GROUND_CONTACT_EVIDENCE_ONLY") == "1"
	var targets := OS.get_environment("CITY_BUILDER_GROUND_CONTACT_TARGETS")
	for value in targets.split(",", false):
		var building_id := value.strip_edges()
		if not building_id.is_empty():
			_target_ids.append(building_id)

func _setup_renderer() -> void:
	root.size = _shot_size
	_stage = Node3D.new()
	_stage.name = "GroundContactAuditStage"
	root.add_child(_stage)
	var environment := WorldEnvironment.new()
	environment.environment = load("res://scenes/main-environment.tres")
	_stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -135.0, 0.0)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.75
	_stage.add_child(sun)
	_subject_root = Node3D.new()
	_stage.add_child(_subject_root)
	_camera = Camera3D.new()
	_camera.fov = 20.0
	_camera.current = true
	_camera.environment = environment.environment
	_stage.add_child(_camera)

	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var strip := ColorRect.new()
	strip.position = Vector2(12, 12)
	strip.size = Vector2(maxi(260, _shot_size.x - 24), 34)
	strip.color = Color(0.04, 0.055, 0.07, 0.88)
	canvas.add_child(strip)
	_label = Label.new()
	_label.position = Vector2(22, 18)
	_label.size = Vector2(maxi(240, _shot_size.x - 44), 24)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(_label)

func _build_subject(building_id: String, structure: Structure, rotation_steps: int) -> void:
	for child in _subject_root.get_children():
		_subject_root.remove_child(child)
		child.queue_free()
	var rotated_cells: Array[Vector2i] = []
	var footprint := structure.footprint if not structure.footprint.is_empty() else [Vector2i.ZERO]
	for offset: Vector2i in footprint:
		rotated_cells.append(_rotate_offset(offset, rotation_steps))
	_add_ground_stage(rotated_cells)
	var mesh := _first_mesh(structure.model)
	if mesh:
		var instance := MeshInstance3D.new()
		instance.name = building_id
		instance.mesh = mesh
		instance.transform = _model_transform(structure, rotation_steps, mesh)
		_subject_root.add_child(instance)
	# Evidence-only before-* runs reconstruct the original default-replace
	# presentation from the frozen model/transform hashes without mutating data.
	var treatment := "replace" if _is_before_phase() else \
		String(_catalogue.get_summary_by_id(building_id).get("ground_treatment", "replace"))
	if treatment == "grass_underlay" and _grass_mesh:
		for cell in rotated_cells:
			var underlay := MeshInstance3D.new()
			underlay.name = "GrassUnderlay_%d_%d" % [cell.x, cell.y]
			underlay.mesh = _grass_mesh
			var gy := -_grass_mesh.get_aabb().position.y
			underlay.position = Vector3(cell.x, gy + GROUND_MAP_Y + UNDERLAY_BIAS_Y, cell.y)
			_subject_root.add_child(underlay)
	var overall := _transformed_mesh_bounds(mesh, _model_transform(structure, rotation_steps, mesh)) if mesh else AABB()
	var centre := Vector3.ZERO
	for cell in rotated_cells:
		centre += Vector3(cell.x, 0.0, cell.y)
	centre /= maxf(1.0, rotated_cells.size())
	var horizontal_span := maxf(1.0, maxf(overall.size.x, overall.size.z))
	var distance := maxf(10.5, horizontal_span * 5.25)
	distance = maxf(distance, minf(overall.size.y, 5.0) * 2.5 + 5.0)
	match _zoom_mode:
		# Match the production View limits exactly for extreme-zoom evidence.
		"close": distance = 15.0
		"wide": distance = 80.0
	var target_height := minf(0.55, maxf(0.15, overall.size.y * 0.16))
	var view_direction := Vector3(0.579228, 0.573576, 0.579228).normalized()
	_camera.position = centre + Vector3(0.0, target_height, 0.0) + view_direction * distance
	_camera.look_at(centre + Vector3(0.0, target_height, 0.0), Vector3.UP)

func _add_ground_stage(cells: Array[Vector2i]) -> void:
	var centre := Vector3.ZERO
	for cell in cells:
		centre += Vector3(cell.x, 0.0, cell.y)
	centre /= maxf(1.0, cells.size())
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(8.0, 8.0)
	floor_mesh.material = _flat_material(Color("26333a"))
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	floor_instance.position = centre + Vector3(0.0, -0.035, 0.0)
	_subject_root.add_child(floor_instance)
	for index in cells.size():
		var cell := cells[index]
		var tile := PlaneMesh.new()
		tile.size = Vector2(0.96, 0.96)
		tile.material = _flat_material(Color("d45b7a") if index % 2 == 0 else Color("4fc3d7"))
		var tile_instance := MeshInstance3D.new()
		tile_instance.mesh = tile
		tile_instance.position = Vector3(cell.x, -0.018, cell.y)
		_subject_root.add_child(tile_instance)
		_add_cell_outline(cell)

func _add_cell_outline(cell: Vector2i) -> void:
	var colour := Color("ffd34e")
	for segment in [
		[Vector3(0.0, 0.006, -0.495), Vector3(1.01, 0.012, 0.025)],
		[Vector3(0.0, 0.006, 0.495), Vector3(1.01, 0.012, 0.025)],
		[Vector3(-0.495, 0.006, 0.0), Vector3(0.025, 0.012, 1.01)],
		[Vector3(0.495, 0.006, 0.0), Vector3(0.025, 0.012, 1.01)],
	]:
		var box := BoxMesh.new()
		box.size = segment[1]
		box.material = _flat_material(colour)
		var edge := MeshInstance3D.new()
		edge.mesh = box
		edge.position = Vector3(cell.x, 0.0, cell.y) + segment[0]
		_subject_root.add_child(edge)

func _flat_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	return material

func _model_transform(structure: Structure, rotation_steps: int, mesh: Mesh) -> Transform3D:
	var footprint := structure.footprint if not structure.footprint.is_empty() else [Vector2i.ZERO]
	var centre := Vector3.ZERO
	for offset: Vector2i in footprint:
		centre += Vector3(offset.x, 0.0, offset.y)
	centre /= maxf(1.0, footprint.size())
	var scale := structure.model_scale
	var ground_offset := -mesh.get_aabb().position.y * scale
	var item_transform := Transform3D(
		Basis(Vector3.UP, deg_to_rad(structure.model_rotation_y)).scaled(Vector3.ONE * scale),
		centre + Vector3(0.0, ground_offset, 0.0) + structure.model_offset)
	var placement := Transform3D(Basis(Vector3.UP, deg_to_rad(rotation_steps * 90.0)), Vector3.ZERO)
	return placement * item_transform

func _inventory_row(summary: Dictionary, structure: Structure) -> Dictionary:
	var building_id := String(summary.get("building_id", ""))
	var model_path := String(summary.get("model_path", ""))
	var mesh := _first_mesh(structure.model)
	var transform := _model_transform(structure, 0, mesh) if mesh else Transform3D.IDENTITY
	var overall := _transformed_mesh_bounds(mesh, transform) if mesh else AABB()
	var near_ground := _near_ground_bounds(mesh, transform, overall) if mesh else {}
	var upstream: Dictionary = _upstream_records.get(building_id, {})
	var source_model_path := String(upstream.get("model_path", model_path))
	var source_resource_path := source_model_path if source_model_path.begins_with("res://") else "res://" + source_model_path
	var source_hash := FileAccess.get_sha256(source_resource_path) if FileAccess.file_exists(source_resource_path) else ""
	var integrity := _mesh_integrity(mesh)
	return {
		"building_id": building_id,
		"definition_path": summary.get("source_path", ""),
		"model_path": model_path,
		"source_model_path": source_model_path,
		"transform_source": RESULTS_PATH if upstream.has("game_transform") else summary.get("source_path", ""),
		"model_hash_before": FileAccess.get_sha256(model_path) if FileAccess.file_exists(model_path) else "",
		"model_hash_after": null,
		"source_hash_before": source_hash,
		"source_hash_after": null,
		"footprint_cells": _cell_records(structure.footprint),
		"model_scale": structure.model_scale,
		"model_offset": _vec3_array(structure.model_offset),
		"model_rotation_y": structure.model_rotation_y,
		"overall_bounds": _aabb_record(overall),
		"near_ground_bounds": near_ground,
		"first_mesh_readable": integrity.get("readable", false),
		"first_mesh": integrity,
		"materials": integrity.get("materials", []),
		"texture_bindings": integrity.get("texture_bindings", []),
		"rotation_results": [],
		"status": "review_pending",
		"rationale": "Pending four-rotation normal-renderer review.",
		"before_evidence": [],
		"after_evidence": [],
		"approved": false,
	}

func _baseline_row(summary: Dictionary, structure: Structure) -> Dictionary:
	var raw := _read_json(String(summary.get("source_path", "")))
	return {
		"building_id": summary.get("building_id", ""),
		"model_path": summary.get("model_path", ""),
		"footprint_cells": _cell_records(structure.footprint),
		"model_scale": structure.model_scale,
		"model_offset": _vec3_array(structure.model_offset),
		"model_rotation_y": structure.model_rotation_y,
		"category": summary.get("category", ""),
		"pool_id": summary.get("pool_id", ""),
		"cash_cost": summary.get("cash_cost", 0),
		"community_role": summary.get("community_role", ""),
		"palette_excluded": summary.get("palette_excluded", false),
		"tags": summary.get("tags", []).duplicate(true),
		"profiles": raw.get("profiles", []).duplicate(true),
		"ui_group": summary.get("ui_group", ""),
		"ui_order": summary.get("ui_order", 1000),
		"ui_icon": summary.get("ui_icon", ""),
	}

func _merge_review_fields(row: Dictionary, building_id: String) -> void:
	var existing: Dictionary = _existing_rows.get(building_id, {})
	for key in ["status", "rationale", "approved", "model_hash_before", "source_hash_before"]:
		if existing.has(key):
			row[key] = existing[key]
	# Migrate the original audit's unambiguous source hash into the explicit
	# before/after pair without weakening its frozen provenance.
	if not existing.has("source_hash_before") and existing.has("source_hash"):
		row["source_hash_before"] = existing["source_hash"]
	if existing.has("before_evidence"):
		row["before_evidence"] = existing["before_evidence"].duplicate(true)
	if existing.has("after_evidence"):
		row["after_evidence"] = existing["after_evidence"].duplicate(true)
	var decision: Dictionary = _decisions.get(building_id, {})
	if not decision.is_empty():
		row["status"] = decision.get("status", "review_pending")
		row["rationale"] = decision.get("rationale", "")
		row["approved"] = true
	if not _is_before_phase():
		row["model_hash_after"] = FileAccess.get_sha256(String(row["model_path"]))
		var source_path := String(row.get("source_model_path", ""))
		var source_resource_path := source_path if source_path.begins_with("res://") else "res://" + source_path
		row["source_hash_after"] = FileAccess.get_sha256(source_resource_path) \
			if FileAccess.file_exists(source_resource_path) else ""

func _record_phase_evidence(row: Dictionary, building_id: String) -> void:
	var key := "before_evidence" if _is_before_phase() else "after_evidence"
	var evidence: Array = row.get(key, [])
	var path := _sheet_resource_path(building_id)
	if path not in evidence:
		evidence.append(path)
	row[key] = evidence

func _prior_rotation_verdict(building_id: String, index: int) -> String:
	var decision: Dictionary = _decisions.get(building_id, {})
	if not _is_before_phase():
		var reviewed_ids: Array = _after_review.get("building_ids", [])
		var reviewed_degrees: Array = _after_review.get("reviewed_rotation_degrees", [])
		var verdict := String(_after_review.get("verdict", "review_pending"))
		var id_reviewed := reviewed_ids.any(func(value: Variant) -> bool:
			return String(value) == building_id)
		var degree_reviewed := index >= 0 and index < ROTATION_DEGREES.size() \
			and reviewed_degrees.any(func(value: Variant) -> bool:
				return int(value) == int(ROTATION_DEGREES[index]))
		if id_reviewed and degree_reviewed and verdict in ["pass", "fail"]:
			return verdict
		return "review_pending"
	if String(decision.get("status", "")) == "pass":
		return "pass"
	if not decision.is_empty():
		return "fail"
	var existing: Dictionary = _existing_rows.get(building_id, {})
	var rotations: Array = existing.get("rotation_results", [])
	if index >= 0 and index < rotations.size():
		return String(rotations[index].get("verdict", "review_pending"))
	return "review_pending"

func _is_before_phase() -> bool:
	return _phase == "before" or _phase.begins_with("before-")

func _load_upstream_records() -> void:
	var payload := _read_json(RESULTS_PATH)
	for row_any in payload.get("records", []):
		if row_any is Dictionary and String(row_any.get("status", "")) == "SUCCEEDED":
			_upstream_records[String(row_any.get("asset_id", ""))] = row_any

func _load_existing_audit() -> void:
	var payload := _read_json(AUDIT_PATH)
	for row_any in payload.get("rows", []):
		if row_any is Dictionary:
			_existing_rows[String(row_any.get("building_id", ""))] = row_any

func _load_decisions() -> void:
	var payload := _read_json(DECISIONS_PATH)
	_decisions = payload.get("rows", {})
	_after_review = payload.get("after_review", {})

func _first_mesh(packed_scene: PackedScene) -> Mesh:
	if packed_scene == null:
		return null
	var state := packed_scene.get_state()
	for node_index in state.get_node_count():
		if state.get_node_type(node_index) != "MeshInstance3D":
			continue
		for property_index in state.get_node_property_count(node_index):
			if state.get_node_property_name(node_index, property_index) == "mesh":
				return state.get_node_property_value(node_index, property_index) as Mesh
	return null

func _mesh_integrity(mesh: Mesh) -> Dictionary:
	if mesh == null:
		return {"readable": false, "surface_count": 0, "vertex_count": 0,
			"materials": [], "texture_bindings": []}
	var vertex_count := 0
	var materials: Array = []
	var texture_bindings: Array = []
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		if arrays.size() > Mesh.ARRAY_VERTEX:
			vertex_count += arrays[Mesh.ARRAY_VERTEX].size()
		var material := mesh.surface_get_material(surface)
		if material == null:
			continue
		materials.append({
			"surface": surface,
			"name": material.resource_name,
			"class": material.get_class(),
			"resource_path": material.resource_path,
		})
		for property_name in ["albedo_texture", "normal_texture", "metallic_texture", "roughness_texture", "orm_texture"]:
			var texture = material.get(property_name)
			if texture is Texture2D:
				texture_bindings.append({
					"surface": surface,
					"slot": property_name,
					"resource_path": texture.resource_path,
					"width": texture.get_width(),
					"height": texture.get_height(),
				})
	return {
		"readable": mesh.get_surface_count() > 0 and vertex_count > 0,
		"resource_name": mesh.resource_name,
		"resource_path": mesh.resource_path,
		"surface_count": mesh.get_surface_count(),
		"vertex_count": vertex_count,
		"materials": materials,
		"texture_bindings": texture_bindings,
	}

func _transformed_mesh_bounds(mesh: Mesh, transform: Transform3D) -> AABB:
	if mesh == null:
		return AABB()
	var source := mesh.get_aabb()
	var first := true
	var result := AABB()
	for x in [source.position.x, source.end.x]:
		for y in [source.position.y, source.end.y]:
			for z in [source.position.z, source.end.z]:
				var point := transform * Vector3(x, y, z)
				if first:
					result = AABB(point, Vector3.ZERO)
					first = false
				else:
					result = result.expand(point)
	return result

func _near_ground_bounds(mesh: Mesh, transform: Transform3D, overall: AABB) -> Dictionary:
	var band_max := overall.position.y + clampf(overall.size.y * 0.08, 0.04, 0.15)
	var points: Array[Vector3] = []
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
		for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			var point := transform * vertex
			if point.y <= band_max:
				points.append(point)
	if points.is_empty():
		return {"point_count": 0, "band_max_y": band_max, "min": [], "max": [], "extent": []}
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return {
		"point_count": points.size(),
		"band_max_y": band_max,
		"min": _vec3_array(minimum),
		"max": _vec3_array(maximum),
		"extent": _vec3_array(maximum - minimum),
	}

static func _rotate_offset(offset: Vector2i, steps: int) -> Vector2i:
	var result := offset
	for _index in (steps % 4):
		result = Vector2i(result.y, -result.x)
	return result

func _sheet_resource_path(building_id: String) -> String:
	return "%s/contact-sheets/%s/%s.png" % [VALIDATION_ROOT, _phase, building_id]

static func _cell_records(cells: Array[Vector2i]) -> Array:
	var result: Array = []
	for cell in cells:
		result.append([cell.x, cell.y])
	return result

static func _vec3_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func _aabb_record(value: AABB) -> Dictionary:
	return {
		"min": _vec3_array(value.position),
		"max": _vec3_array(value.end),
		"extent": _vec3_array(value.size),
	}

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("ground_contact_json_write_failed:%s" % path)
		return
	file.store_string(JSON.stringify(payload, "  ", true) + "\n")
	file.close()

func _frames(count: int) -> void:
	for _index in count:
		await process_frame
