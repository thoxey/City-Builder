extends Control
class_name CommunityMapOverlay

var model: Dictionary = {}
var mode := "off"
var marker_radius := 15.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_projection(value: Dictionary, overlay_mode: String) -> void:
	model = value.duplicate(true)
	mode = overlay_mode
	visible = mode != "off"
	queue_redraw()

func _process(_delta: float) -> void:
	if visible: queue_redraw()

func _draw() -> void:
	if mode == "off" or model.is_empty(): return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	for key in model.get("neighbourhoods", {}):
		var neighbourhood: Dictionary = model["neighbourhoods"][key]
		var anchor: Variant = CommunityConstants.coordinate(neighbourhood.get("home_anchor"))
		if anchor == null: continue
		var position := camera.unproject_position(Vector3(anchor.x, 0.7, anchor.y))
		var value := _value(neighbourhood)
		var colour := CommunityUIFactory.RED.lerp(CommunityUIFactory.MUSTARD, clampf(value / 100.0, 0.0, 1.0))
		draw_circle(position, marker_radius, Color(colour, 0.82))
		draw_circle(position, marker_radius, CommunityUIFactory.INK, false, 2.0)
		draw_string(ThemeDB.fallback_font, position + Vector2(-11, 5), "%d" % int(round(value)), HORIZONTAL_ALIGNMENT_CENTER, 22, 12, Color.WHITE)
	_draw_legend()

func _value(neighbourhood: Dictionary) -> float:
	if mode in CommunityConstants.QUALITIES:
		return float(neighbourhood.get("average_qualities", {}).get(mode, 0.0))
	var count := int(neighbourhood.get("resident_count", 0))
	return 0.0 if count <= 0 else float(neighbourhood.get("dominant_lenses", {}).get(mode, 0)) * 100.0 / float(count)

func _draw_legend() -> void:
	var rect := Rect2(18, 68, 210, 58)
	draw_rect(rect, Color(CommunityUIFactory.INK, 0.86), true)
	draw_rect(rect, CommunityUIFactory.PARCHMENT, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(30, 90), "MAP OVERLAY · " + mode.capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(30, 112), "Numbers show score / share %", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CommunityUIFactory.PARCHMENT)
