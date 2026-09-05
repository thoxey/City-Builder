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
var label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(56, 56)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_rect)
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", load("res://fonts/lilita_one_regular.ttf"))
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

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
	label.text = String(action.get("label", ""))
	label.tooltip_text = String(action.get("accessible_description", label.text))
	icon_rect.tooltip_text = label.tooltip_text
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
	icon_rect.position = position_on_ring - Vector2(28, 38)
	icon_rect.size = Vector2(56, 56)
	label.position = position_on_ring + Vector2(-62, 17)
	label.size = Vector2(124, 34)

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
