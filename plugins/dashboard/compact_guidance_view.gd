class_name CompactGuidanceView
extends Control

## Dismissible in-game quest direction. Progression remains owned by Dashboard's
## canonical next-step projection; this class only presents one speaker and one
## compact speech bubble. Its sole interaction is consuming a click to hide the
## current direction.

const THEME_PATH := "res://themes/dialogue_theme.tres"
const PORTRAIT_GRAIN_PATH := "res://sprites/ui/build-menu/components/parchment-print-grain.png"
const PORTRAIT_PAPER_COLOR := Color("#e7d3ad")
const INK_COLOR := Color("#171713")
const BUBBLE_COLOR := Color(0.13, 0.18, 0.22, 0.97)
const SPEAKER_COLOR := Color(0.94, 0.76, 0.38, 1.0)
const TEXT_COLOR := Color(0.96, 0.93, 0.84, 1.0)
const LARGE_SIZE := Vector2(540.0, 176.0)
const COMPACT_SIZE := Vector2(480.0, 160.0)

var _built := false
var _has_guidance := false
var _suppressed := false
var _bubble: Panel
var _copy: VBoxContainer
var _tail: Polygon2D
var _speaker_name: Label
var _text: Label
var _portrait_host: Control
var _medallion: ColorRect
var _portrait: TextureRect
var _close_button: Button
var _model: Dictionary = {}
var _current_direction_key := ""
var _dismissed_direction_key := ""


func build() -> void:
	if _built:
		return
	_built = true
	name = "CompactGuidanceView"
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists(THEME_PATH):
		theme = load(THEME_PATH)

	_bubble = Panel.new()
	_bubble.name = "GuidanceBubble"
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_theme_stylebox_override("panel", _bubble_style())
	add_child(_bubble)

	_copy = VBoxContainer.new()
	_copy.name = "GuidanceCopy"
	_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_copy.add_theme_constant_override("separation", 3)
	_bubble.add_child(_copy)
	_speaker_name = Label.new()
	_speaker_name.name = "SpeakerName"
	_speaker_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker_name.add_theme_font_size_override("font_size", 14)
	_speaker_name.add_theme_color_override("font_color", SPEAKER_COLOR)
	_copy.add_child(_speaker_name)
	_text = Label.new()
	_text.name = "DirectionText"
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 18)
	_text.add_theme_color_override("font_color", TEXT_COLOR)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_copy.add_child(_text)

	_tail = Polygon2D.new()
	_tail.name = "BubbleTail"
	_tail.color = BUBBLE_COLOR
	add_child(_tail)

	_portrait_host = Control.new()
	_portrait_host.name = "GuidancePortraitHost"
	_portrait_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_host)
	_medallion = ColorRect.new()
	_medallion.name = "PortraitMedallion"
	_medallion.color = PORTRAIT_PAPER_COLOR
	_medallion.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medallion.material = _portrait_medallion_material()
	_portrait_host.add_child(_medallion)
	_portrait = TextureRect.new()
	_portrait.name = "PortraitTexture"
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.material = _portrait_material()
	_portrait_host.add_child(_portrait)
	_close_button = Button.new()
	_close_button.name = "CloseGuidance"
	_close_button.text = "×"
	_close_button.tooltip_text = "Close guidance"
	_close_button.flat = true
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_button.add_theme_font_size_override("font_size", 20)
	_close_button.add_theme_color_override("font_color", TEXT_COLOR)
	_close_button.add_theme_color_override("font_hover_color", SPEAKER_COLOR)
	_close_button.add_theme_color_override("font_pressed_color", SPEAKER_COLOR)
	_close_button.pressed.connect(_dismiss_current_direction)
	add_child(_close_button)

	set_guidance({})
	layout_for_viewport(get_viewport_rect().size)
	get_viewport().size_changed.connect(func(): layout_for_viewport(get_viewport_rect().size))


func set_guidance(model: Dictionary) -> void:
	if not _built:
		build()
	var direction_key := _guidance_key(model)
	if direction_key != _current_direction_key:
		_current_direction_key = direction_key
		_dismissed_direction_key = ""
	if model == _model:
		_update_visibility()
		return
	_model = model.duplicate(true)
	_speaker_name.text = String(_model.get("speaker_name", ""))
	_text.text = String(_model.get("text", ""))
	var path := String(_model.get("portrait_path", ""))
	_portrait.texture = load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
	_has_guidance = not _text.text.is_empty() and _portrait.texture != null
	_update_visibility()


func set_suppressed(value: bool) -> void:
	_suppressed = value
	_update_visibility()


func layout_for_viewport(viewport_size: Vector2) -> void:
	if not _built:
		return
	var compact := viewport_size.x < 1500.0 or viewport_size.y < 850.0
	var ui_scale := clampf(minf(viewport_size.x / 1920.0, viewport_size.y / 1080.0), 1.0, 2.0)
	scale = Vector2(ui_scale, ui_scale)
	size = COMPACT_SIZE if compact else LARGE_SIZE
	position = Vector2(24.0 * ui_scale, maxf(96.0 * ui_scale, viewport_size.y - (size.y + 154.0) * ui_scale))
	var portrait_size := size.y - 8.0
	_portrait_host.position = Vector2(size.x - portrait_size, 4.0)
	_portrait_host.size = Vector2(portrait_size, portrait_size)
	var bubble_right := _portrait_host.position.x + 24.0
	_bubble.position = Vector2(0.0, 18.0)
	_bubble.size = Vector2(bubble_right, size.y - 48.0)
	_copy.position = Vector2(18.0, 10.0)
	_copy.size = Vector2(bubble_right - 86.0, size.y - 70.0)
	_close_button.position = Vector2(bubble_right - 58.0, 24.0)
	_close_button.size = Vector2(28.0, 28.0)
	_tail.polygon = PackedVector2Array([
		Vector2(bubble_right - 8.0, size.y * 0.46),
		Vector2(bubble_right + 22.0, size.y * 0.54),
		Vector2(bubble_right - 8.0, size.y * 0.65),
	])


func control_for_test(locator: String) -> Control:
	match locator:
		"bubble": return _bubble
		"speaker_name": return _speaker_name
		"text": return _text
		"portrait_host": return _portrait_host
		"portrait": return _portrait
		"medallion": return _medallion
		"close_button": return _close_button
	return null


func model_for_test() -> Dictionary:
	return _model.duplicate(true)


func _update_visibility() -> void:
	visible = (_has_guidance and not _suppressed
		and _dismissed_direction_key != _current_direction_key)


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	var dismiss: bool = (event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	dismiss = dismiss or (event is InputEventScreenTouch and event.pressed)
	if dismiss:
		accept_event()
		_dismiss_current_direction()


func _dismiss_current_direction() -> void:
	if not _has_guidance:
		return
	_dismissed_direction_key = _current_direction_key
	_update_visibility()


static func _guidance_key(model: Dictionary) -> String:
	if model.is_empty():
		return ""
	var target := String(model.get("target_id", model.get("target_label", "")))
	if target.is_empty() and String(model.get("kind", "")).is_empty():
		target = String(model.get("text", ""))
	return "%s|%s|%s" % [String(model.get("kind", "")), target, String(model.get("speaker_id", ""))]


static func _bubble_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BUBBLE_COLOR
	style.border_color = INK_COLOR
	style.set_border_width_all(3)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 18.0
	style.content_margin_top = 10.0
	style.content_margin_right = 30.0
	style.content_margin_bottom = 12.0
	return style


static func _portrait_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; render_mode unshaded; void fragment(){ vec4 c = texture(TEXTURE, UV) * COLOR; COLOR = c; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


static func _portrait_medallion_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
render_mode unshaded;
uniform sampler2D grain_texture : repeat_enable, filter_linear;
uniform vec4 paper_color : source_color = vec4(0.906, 0.827, 0.678, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float angle = atan(p.y, p.x);
	float wobble = 0.025 * sin(angle * 7.0 + 0.4) + 0.012 * sin(angle * 13.0 - 0.7);
	float radius = length(p);
	float alpha = 1.0 - smoothstep(0.965 + wobble, 0.995 + wobble, radius);
	float grain = texture(grain_texture, fract(UV * 1.5)).r;
	float paper = mix(0.93, 1.03, grain);
	COLOR = vec4(paper_color.rgb * paper, paper_color.a * alpha);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("paper_color", PORTRAIT_PAPER_COLOR)
	if ResourceLoader.exists(PORTRAIT_GRAIN_PATH):
		material.set_shader_parameter("grain_texture", load(PORTRAIT_GRAIN_PATH))
	return material
