extends PluginBase

## BuildableArea — authority for which grid cells the player may build on.
##
## The mask is kept separate from the GridMap: the engine grid is infinite
## but this plugin narrows what Builder is allowed to touch. Starts seeded
## with a small starter plot and grows when PatronSystem emits
## `patron_landmark_completed`. The live mask persists in DataMap so
## expansions carry across save/load.

## Default starter plot (8×8 centred on origin). Tuneable for early-game
## ergonomics — extend if the player should have more room to breathe before
## the first donation.
const STARTER_RECT := Rect2i(-4, -4, 8, 8)
const ROOTED_STARTER_RECT := Rect2i(-8, -8, 16, 16)

## Presentation is deliberately derived from `_allowed`; it never participates
## in placement evaluation. The authored opacity is converted to a lower linear
## framebuffer alpha so that it reads like a subtle white veil without washing the
## dark grass texture out in Forward+.
const PRESENTATION_RECT := Rect2i(-256, -256, 512, 512)
const NORMAL_PERCEPTUAL_OPACITY := 0.05
const EMPHASIZED_PERCEPTUAL_OPACITY := 0.08
const NORMAL_LINEAR_ALPHA := 0.0125
const EMPHASIZED_LINEAR_ALPHA := 0.02
const OVERLAY_HEIGHT := 0.018
const OVERLAY_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D buildable_mask : filter_nearest, repeat_disable;
uniform vec4 overlay_colour : source_color = vec4(1.0, 1.0, 1.0, 0.0125);

void fragment() {
	float non_buildable = texture(buildable_mask, UV).r;
	ALBEDO = overlay_colour.rgb;
	ALPHA = overlay_colour.a * non_buildable;
}
"""

## Vector2i -> true. Source of truth during gameplay; mirrored to
## GameState.map.allowed_cells on every mutation so saves round-trip.
var _allowed: Dictionary = {}
var _presentation: MeshInstance3D
var _overlay_material: ShaderMaterial
var _buildable_mask_texture: ImageTexture
var _presentation_emphasized := false
var _presentation_revision := 0
var _presentation_buildable_clear_cell_count := 0
var _presentation_non_buildable_cell_count := 0

func get_plugin_name() -> String:
	return "BuildableArea"

func get_dependencies() -> Array[String]:
	return []

func inject(deps: Dictionary) -> void:
	pass

func _plugin_ready() -> void:
	_load_or_seed()
	_setup_presentation()
	if not GameEvents.map_loaded.is_connected(_on_map_loaded):
		GameEvents.map_loaded.connect(_on_map_loaded)
	if not GameEvents.player_input_mode_changed.is_connected(_on_player_input_mode_changed):
		GameEvents.player_input_mode_changed.connect(_on_player_input_mode_changed)
	var starter := _starter_rect()
	print("[BuildableArea] seeded: cells=%d shape=rect rect=(%d,%d,%d,%d)" % [
		_allowed.size(),
		starter.position.x, starter.position.y,
		starter.size.x, starter.size.y
	])

## Pull the allowed set from DataMap if present, else seed from STARTER_RECT.
## Called on boot + every map_loaded so expansions in prior sessions survive.
func _load_or_seed() -> void:
	_allowed.clear()
	if GameState != null and GameState.map != null:
		var saved: Array = GameState.map.allowed_cells
		if not saved.is_empty():
			for c in saved:
				_allowed[c] = true
			_refresh_presentation()
			return
	# The rooted loop needs room for sixty structures plus their road frontage;
	# legacy fixtures retain the historical 8x8 baseline.
	var starter := _starter_rect()
	for x in range(starter.position.x, starter.position.x + starter.size.x):
		for y in range(starter.position.y, starter.position.y + starter.size.y):
			_allowed[Vector2i(x, y)] = true
	_sync_to_map()
	_refresh_presentation()

func _starter_rect() -> Rect2i:
	return ROOTED_STARTER_RECT if GameState != null and GameState.map != null and GameState.map.rooted_town_rules else STARTER_RECT

## Copy _allowed (Dictionary) into GameState.map.allowed_cells (Array) so the
## save path sees the current set.
func _sync_to_map() -> void:
	if GameState == null or GameState.map == null:
		return
	var arr: Array[Vector2i] = []
	for c in _allowed.keys():
		arr.append(c)
	GameState.map.allowed_cells = arr

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_map_loaded(_m: DataMap) -> void:
	_load_or_seed()

func _on_player_input_mode_changed(mode: String) -> void:
	var emphasized := mode in ["radial", "placement"]
	if emphasized == _presentation_emphasized:
		return
	_presentation_emphasized = emphasized
	_refresh_presentation()

# ── Mutation ──────────────────────────────────────────────────────────────────

func _expand(cells: Array[Vector2i], trigger: String) -> Array[Vector2i]:
	var added: Array[Vector2i] = []
	for c in cells:
		if not _allowed.has(c):
			_allowed[c] = true
			added.append(c)
	if added.is_empty():
		return added
	_sync_to_map()
	_refresh_presentation()
	print("[BuildableArea] expand: trigger=%s new_cells=%d total_cells=%d" % [
		trigger, added.size(), _allowed.size()
	])
	GameEvents.buildable_area_expanded.emit(added)
	return added

## Apply one patron's authored donation exactly once. The receipt is the
## authority for idempotency; overlapping cells still produce a receipt.
func apply_donation(patron_id: String, area: Dictionary) -> Dictionary:
	if GameState == null or GameState.map == null:
		return {"applied": false, "already_applied": false, "added_cells": [], "reason": "map_unavailable"}
	if GameState.map.patron_donations_applied.get(patron_id, false):
		return {"applied": false, "already_applied": true, "added_cells": [], "total_cells": _allowed.size()}
	if area.is_empty():
		return {"applied": false, "already_applied": false, "added_cells": [], "reason": "donation_area_missing"}
	var cells: Array[Vector2i] = LandDonationPayload.cells_from_dict(area)
	var added := _expand(cells, patron_id)
	GameState.map.patron_donations_applied[patron_id] = true
	return {
		"applied": true,
		"already_applied": false,
		"added_cells": added,
		"total_cells": _allowed.size(),
	}

func has_donation(patron_id: String) -> bool:
	return GameState != null and GameState.map != null and bool(GameState.map.patron_donations_applied.get(patron_id, false))

## Direct-expand entry point for tests and external callers (e.g. a debug
## tool that wants to grant a specific rect). Wraps _expand so the signal
## still fires.
func expand_rect(rect: Rect2i, trigger: String = "external") -> void:
	var cells: Array[Vector2i] = []
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			cells.append(Vector2i(x, y))
	_expand(cells, trigger)

# ── Queries ───────────────────────────────────────────────────────────────────

func is_allowed(cell: Vector2i) -> bool:
	return _allowed.has(cell)

func allowed_count() -> int:
	return _allowed.size()

func allowed_cells() -> Array:
	return _allowed.keys()

# ── Derived presentation ─────────────────────────────────────────────────────

func _setup_presentation() -> void:
	if _presentation != null and is_instance_valid(_presentation):
		return
	_presentation = MeshInstance3D.new()
	_presentation.name = "BuildableAreaPresentation"
	_presentation.position = Vector3(-0.5, OVERLAY_HEIGHT, -0.5)
	_presentation.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_presentation)

	var plane := PlaneMesh.new()
	plane.size = Vector2(PRESENTATION_RECT.size)
	var shader := Shader.new()
	shader.code = OVERLAY_SHADER
	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = shader
	plane.material = _overlay_material
	_presentation.mesh = plane
	_refresh_presentation()

func _refresh_presentation() -> void:
	if _presentation == null or not is_instance_valid(_presentation):
		return
	_presentation_revision += 1
	if _allowed.is_empty():
		_presentation.visible = false
		_presentation_buildable_clear_cell_count = 0
		_presentation_non_buildable_cell_count = 0
		return

	_presentation_buildable_clear_cell_count = 0
	for cell: Vector2i in _allowed:
		if PRESENTATION_RECT.has_point(cell):
			_presentation_buildable_clear_cell_count += 1
	_presentation_non_buildable_cell_count = PRESENTATION_RECT.get_area() - _presentation_buildable_clear_cell_count
	_update_overlay_material()
	_presentation.visible = true

func _update_overlay_material() -> void:
	if _overlay_material == null:
		return
	var mask := Image.create(PRESENTATION_RECT.size.x, PRESENTATION_RECT.size.y, false, Image.FORMAT_R8)
	mask.fill(Color.WHITE)
	for cell: Vector2i in _allowed:
		if PRESENTATION_RECT.has_point(cell):
			var pixel := cell - PRESENTATION_RECT.position
			mask.set_pixel(pixel.x, pixel.y, Color.BLACK)
	_buildable_mask_texture = ImageTexture.create_from_image(mask)
	var alpha := EMPHASIZED_LINEAR_ALPHA if _presentation_emphasized else NORMAL_LINEAR_ALPHA
	_overlay_material.set_shader_parameter("buildable_mask", _buildable_mask_texture)
	_overlay_material.set_shader_parameter("overlay_colour", Color(1.0, 1.0, 1.0, alpha))

func get_presentation_snapshot() -> Dictionary:
	var perceptual_opacity := EMPHASIZED_PERCEPTUAL_OPACITY if _presentation_emphasized else NORMAL_PERCEPTUAL_OPACITY
	var linear_alpha := EMPHASIZED_LINEAR_ALPHA if _presentation_emphasized else NORMAL_LINEAR_ALPHA
	return {
		"revision": _presentation_revision,
		"emphasized": _presentation_emphasized,
		"visible": _presentation != null and is_instance_valid(_presentation) and _presentation.visible,
		"buildable_clear_cell_count": _presentation_buildable_clear_cell_count,
		"non_buildable_cell_count": _presentation_non_buildable_cell_count,
		"overlay_alpha": linear_alpha,
		"perceptual_opacity": perceptual_opacity,
		"overlay_rgb": {"r": 1.0, "g": 1.0, "b": 1.0},
		"presentation_rect": [PRESENTATION_RECT.position.x, PRESENTATION_RECT.position.y,
			PRESENTATION_RECT.size.x, PRESENTATION_RECT.size.y],
	}
