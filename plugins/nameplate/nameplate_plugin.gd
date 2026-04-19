extends PluginBase

## Nameplate — floating Label3D above each placed building, showing its
## display_name. Purpose: disambiguate buildings that share a reused mesh
## while real art is still being authored. Tab toggles visibility.
##
## Roads and nature are excluded — 50 "Grass" labels would be visual noise.

const LABEL_HEIGHT: float = 2.5
const FONT_SIZE: int = 48
const PIXEL_SIZE: float = 0.004
const OUTLINE_SIZE: int = 12
const SKIP_CATEGORIES: PackedStringArray = ["road", "nature"]

var _catalog: PluginBase
var _container: Node3D
var _labels: Dictionary = {}  # Vector2i anchor -> Label3D
var _visible: bool = true

func get_plugin_name() -> String:
	return "Nameplate"

func get_dependencies() -> Array[String]:
	return ["BuildingCatalog"]

func inject(deps: Dictionary) -> void:
	_catalog = deps.get("BuildingCatalog")

func _plugin_ready() -> void:
	_container = Node3D.new()
	_container.name = "NameplateContainer"
	add_child(_container)

	GameEvents.structure_placed.connect(_on_structure_placed)
	GameEvents.structure_demolished.connect(_on_structure_demolished)
	GameEvents.map_loaded.connect(_on_map_loaded)

	# Pick up any buildings already present (e.g. if the map was loaded
	# before this plugin finished wiring up).
	_rebuild_from_registry()

	print("[Nameplate] ready: visible=%s" % _visible)

## Intentional `_input` (not `_unhandled_input`): Godot binds Tab to the built-in
## `ui_focus_next` UI navigation action. Once any Control has keyboard focus
## (e.g. after clicking a HUD element), Tab is consumed as a focus-cycle event
## before `_unhandled_input` ever fires — so the first press would toggle off,
## focus would land on a button, and subsequent presses would never toggle back.
## Catching in `_input` and marking the event handled runs ahead of focus traversal.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_nameplates"):
		_set_visible(not _visible)
		get_viewport().set_input_as_handled()

func _set_visible(v: bool) -> void:
	_visible = v
	if _container:
		_container.visible = v
	print("[Nameplate] toggle: visible=%s count=%d" % [v, _labels.size()])

# ── Placement / demolition ────────────────────────────────────────────────────

func _on_structure_placed(pos: Vector3i, struct_idx: int, _orient: int) -> void:
	var summary: Dictionary = _catalog.get_summary_by_index(struct_idx)
	if summary.is_empty():
		return
	var category: String = summary.get("category", "")
	if category in SKIP_CATEGORIES:
		return
	var display_name: String = summary.get("display_name", summary.get("building_id", ""))
	if display_name.is_empty():
		return

	var anchor := Vector2i(pos.x, pos.z)
	if _labels.has(anchor):
		# Overbuild — replace the old label.
		var old: Label3D = _labels[anchor]
		old.queue_free()
		_labels.erase(anchor)

	var label := _make_label(display_name)
	label.position = Vector3(float(pos.x), LABEL_HEIGHT, float(pos.z))
	_container.add_child(label)
	_labels[anchor] = label

	print("[Nameplate] placed: building_id=%s pos=(%d,%d) name=\"%s\"" % [
		summary.get("building_id", "?"), pos.x, pos.z, display_name
	])

func _on_structure_demolished(pos: Vector3i) -> void:
	var anchor := Vector2i(pos.x, pos.z)
	if not _labels.has(anchor):
		return
	var label: Label3D = _labels[anchor]
	label.queue_free()
	_labels.erase(anchor)
	print("[Nameplate] demolished: pos=(%d,%d)" % [pos.x, pos.z])

func _on_map_loaded(_map: DataMap) -> void:
	_rebuild_from_registry()

# ── Rebuild ───────────────────────────────────────────────────────────────────

## Drop every existing label and rebuild the set from GameState.building_registry.
## Idempotent — safe to call on boot or after map_loaded.
func _rebuild_from_registry() -> void:
	for anchor in _labels.keys():
		(_labels[anchor] as Label3D).queue_free()
	_labels.clear()

	if GameState == null or GameState.building_registry == null:
		return

	for bid in GameState.building_registry:
		var entry: Dictionary = GameState.building_registry[bid]
		var anchor: Vector2i = entry.get("anchor", Vector2i.ZERO)
		var struct_idx: int = entry.get("structure", -1)
		if struct_idx < 0:
			continue
		_on_structure_placed(Vector3i(anchor.x, 0, anchor.y), struct_idx, 0)

	print("[Nameplate] rebuilt: count=%d" % _labels.size())

# ── Label construction ────────────────────────────────────────────────────────

func _make_label(text: String) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.shaded = false
	label.no_depth_test = true
	label.fixed_size = false
	label.pixel_size = PIXEL_SIZE
	label.font_size = FONT_SIZE
	label.outline_size = OUTLINE_SIZE
	label.modulate = Color(1, 1, 1, 1)
	label.outline_modulate = Color(0, 0, 0, 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

# ── Public accessors (used by tests) ──────────────────────────────────────────

func label_count() -> int:
	return _labels.size()

func has_label_at(anchor: Vector2i) -> bool:
	return _labels.has(anchor)

func label_text_at(anchor: Vector2i) -> String:
	if not _labels.has(anchor):
		return ""
	return (_labels[anchor] as Label3D).text

func is_visible() -> bool:
	return _visible
