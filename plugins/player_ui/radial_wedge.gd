extends Control
class_name RadialWedge

const INK := Color("171713")
const PARCHMENT := Color("e7d3ad")
const ACTIVE := Color("d3a526")
const DANGER := Color("a9473f")

var action: Dictionary = {}
var centre := Vector2.ZERO
var inner_radius := 58.0
var outer_radius := 154.0
var start_angle := 0.0
var end_angle := 0.0
var focused := false
var hovered := false
var icon_rect: TextureRect
var _arc_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(76, 76)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_rect)
	_arc_label = Label.new()
	_arc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_arc_label.add_theme_font_override("font", load("res://fonts/lilita_one_regular.ttf"))
	_arc_label.add_theme_font_size_override("font_size", 16)
	_arc_label.add_theme_color_override("font_color", INK)
	_arc_label.add_theme_color_override("font_outline_color", Color(PARCHMENT, 0.9))
	_arc_label.add_theme_constant_override("outline_size", 2)
	_arc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_arc_label.clip_text = true
	_arc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arc_label)

func configure(value: Dictionary, wheel_centre: Vector2, start: float, finish: float,
		inner: float, outer: float) -> void:
	action = value.duplicate(true)
	centre = wheel_centre
	start_angle = start
	end_angle = finish
	inner_radius = inner
	outer_radius = outer
	visible = not action.is_empty()
	if not visible:
		return
	icon_rect.tooltip_text = String(action.get("accessible_description", action.get("label", "")))
	var path := String(action.get("icon_path", ""))
	icon_rect.texture = load(path) if not path.is_empty() and ResourceLoader.exists(path) else load("res://sprites/ui/build-menu/controls/missing-artwork.png")
	_layout_content()
	queue_redraw()

func set_states(is_focused: bool, is_hovered: bool) -> void:
	focused = is_focused
	hovered = is_hovered
	queue_redraw()

func _layout_content() -> void:
	var middle := (start_angle + end_angle) * 0.5
	var position_on_ring := centre + Vector2.from_angle(middle) * ((inner_radius + outer_radius) * 0.5)
	var icon_size := 82.0 if String(action.get("kind", "")) == "group" else 76.0
	icon_rect.position = position_on_ring - Vector2(icon_size * 0.5, icon_size * 0.5)
	icon_rect.size = Vector2.ONE * icon_size
	_layout_curved_label()

func _layout_curved_label() -> void:
	_arc_label.visible = String(action.get("kind", "")) != "group"
	if String(action.get("kind", "")) == "group":
		return
	var text := String(action.get("label", "")).strip_edges()
	_arc_label.text = text
	var middle := (start_angle + end_angle) * 0.5
	var top_half := sin(middle) < 0.0
	var radius := outer_radius - 21.0
	var chord_width := 2.0 * radius * sin((end_angle - start_angle) * 0.5) * 0.84
	_arc_label.size = Vector2(clampf(chord_width, 82.0, 154.0), 28.0)
	_arc_label.pivot_offset = _arc_label.size * 0.5
	var point := centre + Vector2.from_angle(middle) * radius
	_arc_label.position = point - _arc_label.pivot_offset
	# The word follows the wedge tangent. Top-half letters point outward at the
	# top; bottom-half letters are flipped so their bottoms point outward.
	_arc_label.rotation = middle + PI * 0.5 if top_half else middle - PI * 0.5

func _draw() -> void:
	if action.is_empty():
		return
	var points := PackedVector2Array()
	var steps := 18
	for i in range(steps + 1):
		points.append(centre + Vector2.from_angle(lerpf(start_angle, end_angle, float(i) / steps)) * outer_radius)
	for i in range(steps, -1, -1):
		points.append(centre + Vector2.from_angle(lerpf(start_angle, end_angle, float(i) / steps)) * inner_radius)
	var enabled := bool(action.get("enabled", true))
	var fill := PARCHMENT
	if hovered: fill = fill.lightened(0.08)
	if focused: fill = ACTIVE.lightened(0.25)
	if not enabled: fill = Color("b8ad8c")
	draw_colored_polygon(points, fill)
	draw_polyline(points + PackedVector2Array([points[0]]), INK, 2.5, true)
	if not enabled:
		# Draw short diagonal strokes only when both endpoints remain in this
		# annular sector. CanvasItem has no arbitrary polygon clip, so drawing
		# full lines here would leak the disabled pattern outside the wheel.
		for y in range(int(centre.y - outer_radius), int(centre.y + outer_radius), 9):
			for x in range(int(centre.x - outer_radius), int(centre.x + outer_radius), 9):
				var from := Vector2(x, y)
				var to := from + Vector2(6, 6)
				if _contains_point(from) and _contains_point(to):
					draw_line(from, to, Color(INK, 0.24), 1.5, true)
	if focused:
		draw_arc(centre, outer_radius + 5.0, start_angle, end_angle, 20, ACTIVE, 6.0, true)
	if String(action.get("kind", "")) == "destructive":
		draw_arc(centre, outer_radius - 4.0, start_angle, end_angle, 20, DANGER, 5.0, true)

func _contains_point(point: Vector2) -> bool:
	var offset := point - centre
	var distance := offset.length()
	if distance < inner_radius or distance > outer_radius: return false
	var span := fposmod(end_angle - start_angle, TAU)
	var relative := fposmod(offset.angle() - start_angle, TAU)
	return relative <= span
