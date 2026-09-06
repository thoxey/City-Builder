class_name DialogueThreadView
extends Control

## Append-only, programmatic conversation surface. Traversal and effects remain in
## DialoguePlugin; this view owns only transient controls and row presentation.

signal surface_activated(event: InputEvent)
signal choice_selected(option: Dictionary)
signal return_to_latest_requested

const FONT_PATH := "res://fonts/lilita_one_regular.ttf"
const THEME_PATH := "res://themes/dialogue_theme.tres"
const PORTRAIT_GRAIN_PATH := "res://sprites/ui/build-menu/components/parchment-print-grain.png"
const PORTRAIT_PAPER_COLOR := Color("#e7d3ad")
const PORTRAIT_SQUARE_TOP := 0.076271
const PORTRAIT_SQUARE_BOTTOM := 0.923729
const FRAME_MIN_SIZE := Vector2(760.0, 500.0)
const FRAME_REFERENCE_SIZE := Vector2(1120.0, 680.0)
const FRAME_VIEWPORT_MARGIN := Vector2(120.0, 72.0)

var _built := false
var _dim: ColorRect
var _frame: PanelContainer
var _header: Label
var _status: Label
var _scroll: ScrollContainer
var _content: VBoxContainer
var _choices: VBoxContainer
var _content_tail_spacer: Control
var _return_latest: Button
var _hint: Label
var _rows: Array[Control] = []
var _row_models: Array[Dictionary] = []
var _player_portrait_host: Control
var _player_medallion: ColorRect
var _player_portrait_texture: TextureRect
var _player_portrait_name: Label
var _player_emphasis: Panel
var _counterpart_portrait_host: Control
var _counterpart_medallion: ColorRect
var _counterpart_portrait_texture: TextureRect
var _counterpart_portrait_name: Label
var _counterpart_emphasis: Panel
var _player_state := {
	"semantic_id": "player", "character_id": "", "display_name": "", "expression": "",
	"active": false, "side": "left", "opacity": 0.52, "emphasis_visible": false,
}
var _counterpart_state := {
	"semantic_id": "", "character_id": "", "display_name": "", "expression": "",
	"active": false, "side": "right", "opacity": 0.52, "emphasis_visible": false,
}
var _follow_latest := true
var _logical_scroll_value := 0.0
var _logical_scroll_maximum := 0.0
var _ignore_scroll_signal := false
var _manual_scroll_pending := false
var _scrollbar_dragging := false


func build() -> void:
	if _built:
		return
	_built = true
	name = "DialogueThreadView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(THEME_PATH):
		theme = load(THEME_PATH)

	_dim = ColorRect.new()
	_dim.name = "DimLayer"
	_dim.color = Color(0.025, 0.03, 0.045, 0.72)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_frame = PanelContainer.new()
	_frame.name = "DialogueFrame"
	_frame.theme_type_variation = &"DialogueFrame"
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.gui_input.connect(_on_surface_gui_input)
	_dim.add_child(_frame)

	_build_portrait_hosts()

	var margin := MarginContainer.new()
	margin.name = "FrameInsets"
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 96)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 36)
	_frame.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "FrameColumn"
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	_header = _make_label("Conversation", 28)
	_header.name = "Header"
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_theme_color_override("font_color", Color(0.09, 0.09, 0.075, 1.0))
	column.add_child(_header)

	_status = _make_label("", 14)
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(0.30, 0.26, 0.20, 1.0))
	column.add_child(_status)

	var divider := HSeparator.new()
	divider.name = "HeaderDivider"
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(divider)

	_scroll = ScrollContainer.new()
	_scroll.name = "TranscriptScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.gui_input.connect(_on_scroll_gui_input)
	column.add_child(_scroll)
	var vertical_scrollbar := _scroll.get_v_scroll_bar()
	vertical_scrollbar.mouse_filter = Control.MOUSE_FILTER_STOP
	vertical_scrollbar.gui_input.connect(_on_scrollbar_gui_input)
	vertical_scrollbar.value_changed.connect(_on_actual_scroll_changed)
	vertical_scrollbar.changed.connect(_on_scroll_metrics_changed)

	_content = VBoxContainer.new()
	_content.name = "TranscriptContent"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_content)

	_choices = VBoxContainer.new()
	_choices.name = "Choices"
	_choices.add_theme_constant_override("separation", 6)
	_choices.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_child(_choices)
	_content_tail_spacer = Control.new()
	_content_tail_spacer.name = "TranscriptBottomPadding"
	_content_tail_spacer.custom_minimum_size = Vector2(0.0, 30.0)
	_content_tail_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_content_tail_spacer)

	_return_latest = Button.new()
	_return_latest.name = "ReturnToLatest"
	_return_latest.text = "Return to latest"
	_return_latest.visible = false
	_return_latest.focus_mode = Control.FOCUS_ALL
	_return_latest.mouse_filter = Control.MOUSE_FILTER_STOP
	_return_latest.gui_input.connect(_consume_control_input)
	_return_latest.pressed.connect(_return_to_latest)
	column.add_child(_return_latest)

	_hint = _make_label("Click the conversation, press Space or Enter, or use confirm.", 13)
	_hint.name = "InteractionHint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color(0.34, 0.29, 0.22, 1.0))
	column.add_child(_hint)

	resized.connect(_layout_for_viewport)
	call_deferred("_layout_for_viewport")


func set_header(title: String, status: String = "") -> void:
	_header.text = title
	_status.text = status


func clear_transcript() -> void:
	for row in _rows:
		if is_instance_valid(row):
			row.queue_free()
	_rows.clear()
	_row_models.clear()
	_logical_scroll_value = 0.0
	_logical_scroll_maximum = 0.0
	_follow_latest = true
	set_return_to_latest_visible(false)
	clear_choices()


func append_speech_row(
	speaker: String,
	display_name: String,
	side: String,
	full_text: String,
	show_full_text: bool = false
) -> Control:
	var row := MarginContainer.new()
	row.name = "SpeechRow_%d" % _rows.size()
	row.custom_minimum_size = Vector2(0.0, _estimated_row_height(full_text, true))
	row.mouse_filter = Control.MOUSE_FILTER_PASS

	var horizontal := HBoxContainer.new()
	horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(horizontal)

	var bubble := PanelContainer.new()
	bubble.name = "Bubble"
	bubble.custom_minimum_size = Vector2(260.0, 0.0)
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.20, 0.17, 0.13, 0.96) if side == "left" else Color(0.13, 0.18, 0.22, 0.96)
	bubble_style.corner_radius_top_left = 10
	bubble_style.corner_radius_top_right = 10
	bubble_style.corner_radius_bottom_left = 10
	bubble_style.corner_radius_bottom_right = 10
	bubble_style.content_margin_left = 16
	bubble_style.content_margin_right = 16
	bubble_style.content_margin_top = 10
	bubble_style.content_margin_bottom = 10
	bubble.add_theme_stylebox_override("panel", bubble_style)

	var text_column := VBoxContainer.new()
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(text_column)
	var name_label := _make_label(display_name, 14)
	name_label.name = "SpeakerName"
	name_label.modulate = Color(0.94, 0.76, 0.38, 1.0)
	text_column.add_child(name_label)
	var text_label := _make_label(full_text, 18)
	text_label.name = "BeatText"
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84, 1.0))
	text_label.visible_characters = -1 if show_full_text else 0
	text_label.set_meta("full_text", full_text)
	text_column.add_child(text_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(96.0, 0.0)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if side == "right":
		horizontal.add_child(spacer)
		horizontal.add_child(bubble)
	else:
		horizontal.add_child(bubble)
		horizontal.add_child(spacer)

	_content.add_child(row)
	_content.move_child(row, _choices.get_index())
	_register_row(row, {
		"kind": "speech",
		"speaker": speaker,
		"display_name": display_name,
		"side": side,
		"full_text": full_text,
		"visible_characters": full_text.length() if show_full_text else 0,
		"text_label": text_label,
	})
	return row


func append_narration_row(full_text: String, show_full_text: bool = false) -> Control:
	var row := MarginContainer.new()
	row.name = "NarrationRow_%d" % _rows.size()
	row.custom_minimum_size = Vector2(0.0, _estimated_row_height(full_text, false))
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("margin_left", 72)
	row.add_theme_constant_override("margin_right", 72)

	var text_label := _make_label(full_text, 17)
	text_label.name = "BeatText"
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.visible_characters = -1 if show_full_text else 0
	text_label.add_theme_color_override("font_color", Color(0.18, 0.15, 0.11, 1.0))
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.set_meta("full_text", full_text)
	row.add_child(text_label)

	_content.add_child(row)
	_content.move_child(row, _choices.get_index())
	_register_row(row, {
		"kind": "narration",
		"speaker": "",
		"display_name": "",
		"side": "none",
		"full_text": full_text,
		"visible_characters": full_text.length() if show_full_text else 0,
		"text_label": text_label,
	})
	return row


func set_current_row_visible_characters(count: int) -> void:
	if _row_models.is_empty():
		return
	var index := _row_models.size() - 1
	var model: Dictionary = _row_models[index]
	var full_text := String(model.get("full_text", ""))
	var visible := clampi(count, 0, full_text.length())
	model["visible_characters"] = visible
	var label: Label = model.get("text_label")
	if label:
		label.visible_characters = -1 if visible >= full_text.length() else visible
	_row_models[index] = model


func show_choices(options: Array) -> void:
	clear_choices()
	for option_variant in options:
		if not option_variant is Dictionary:
			continue
		var option: Dictionary = (option_variant as Dictionary).duplicate(true)
		var button := Button.new()
		button.name = "Choice_%d" % _choices.get_child_count()
		button.text = String(option.get("label", ""))
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.gui_input.connect(_consume_control_input)
		button.pressed.connect(func(): choice_selected.emit(option))
		_choices.add_child(button)
	_on_content_appended(float(options.size()) * 52.0)


func clear_choices() -> void:
	if _choices == null:
		return
	for child in _choices.get_children():
		child.queue_free()


func set_return_to_latest_visible(value: bool) -> void:
	_return_latest.visible = value


func set_player_portrait(
	semantic_id: String,
	display_name: String,
	texture: Texture2D,
	expression: String,
	active: bool
) -> void:
	_player_state["semantic_id"] = semantic_id
	_player_state["character_id"] = semantic_id
	_player_state["display_name"] = display_name
	_player_state["expression"] = expression
	_player_portrait_texture.texture = texture
	_player_portrait_name.text = display_name
	set_player_active(active)


func set_counterpart_portrait(
	character_id: String,
	display_name: String,
	texture: Texture2D,
	expression: String,
	active: bool
) -> void:
	_counterpart_state["semantic_id"] = character_id
	_counterpart_state["character_id"] = character_id
	_counterpart_state["display_name"] = display_name
	_counterpart_state["expression"] = expression
	_counterpart_portrait_texture.texture = texture
	_counterpart_portrait_name.text = display_name
	set_counterpart_active(active)


func set_player_active(active: bool) -> void:
	_apply_portrait_activity(_player_portrait_host, _player_portrait_texture, _player_emphasis, _player_state, active)


func set_counterpart_active(active: bool) -> void:
	_apply_portrait_activity(
		_counterpart_portrait_host,
		_counterpart_portrait_texture,
		_counterpart_emphasis,
		_counterpart_state,
		active
	)


func deactivate_portraits() -> void:
	set_player_active(false)
	set_counterpart_active(false)


func portrait_projection() -> Dictionary:
	return {
		"player": _player_state.duplicate(true),
		"counterpart": _counterpart_state.duplicate(true),
	}


func set_scroll_state_for_test(value: float, maximum: float) -> void:
	_logical_scroll_maximum = maxf(0.0, maximum)
	_logical_scroll_value = clampf(value, 0.0, _logical_scroll_maximum)
	_follow_latest = _logical_scroll_maximum - _logical_scroll_value <= 2.0
	set_return_to_latest_visible(not _follow_latest)


func return_to_latest_for_test() -> void:
	_return_to_latest()


func scroll_projection() -> Dictionary:
	return {
		"follow_latest": _follow_latest,
		"value": _logical_scroll_value,
		"maximum": _logical_scroll_maximum,
		"return_to_latest_visible": _return_latest.visible,
	}


func layout_for_viewport_for_test(viewport_size: Vector2) -> void:
	_layout_with_size(viewport_size)


func geometry_projection() -> Dictionary:
	var frame_rect := Rect2(_frame.position, _frame.size)
	var player_rect := Rect2(_player_portrait_host.position, _player_portrait_host.size)
	var counterpart_rect := Rect2(_counterpart_portrait_host.position, _counterpart_portrait_host.size)
	var transcript_rect := Rect2(
		frame_rect.position + Vector2(96.0, 82.0),
		Vector2(maxf(0.0, frame_rect.size.x - 192.0), maxf(0.0, frame_rect.size.y - 164.0))
	)
	var player_overlap := maxf(0.0, player_rect.end.x - frame_rect.position.x)
	var counterpart_overlap := maxf(0.0, frame_rect.end.x - counterpart_rect.position.x)
	return {
		"frame_rect": frame_rect,
		"player_rect": player_rect,
		"counterpart_rect": counterpart_rect,
		"transcript_rect": transcript_rect,
		"player_overlap_ratio": player_overlap / maxf(1.0, player_rect.size.x),
		"counterpart_overlap_ratio": counterpart_overlap / maxf(1.0, counterpart_rect.size.x),
	}


func transcript_row_count() -> int:
	return _rows.size()


func transcript_row_at(index: int) -> Control:
	return _rows[index] if index >= 0 and index < _rows.size() else null


func row_projection(index: int) -> Dictionary:
	if index < 0 or index >= _row_models.size():
		return {}
	var model: Dictionary = _row_models[index]
	return {
		"kind": model.get("kind", ""),
		"speaker": model.get("speaker", ""),
		"display_name": model.get("display_name", ""),
		"side": model.get("side", ""),
		"full_text": model.get("full_text", ""),
		"label_text": String((model.get("text_label") as Label).text),
		"visible_characters": model.get("visible_characters", 0),
		"minimum_height": _rows[index].custom_minimum_size.y,
	}


func transcript_projection() -> Array:
	var projection: Array = []
	for index in range(_row_models.size()):
		projection.append(row_projection(index))
	return projection


func button_texts() -> Array:
	var texts: Array = []
	_collect_button_texts(self, texts)
	return texts


func control_for_test(locator: String) -> Control:
	match locator:
		"frame": return _frame
		"scroll": return _scroll
		"content": return _content
		"choices": return _choices
		"return_latest": return _return_latest
		"hint": return _hint
		"player_texture": return _player_portrait_texture
		"player_medallion": return _player_medallion
		"counterpart_texture": return _counterpart_portrait_texture
		"counterpart_medallion": return _counterpart_medallion
		_: return null


func _register_row(row: Control, model: Dictionary) -> void:
	_rows.append(row)
	_row_models.append(model)
	_on_content_appended(row.custom_minimum_size.y + 12.0)


func _build_portrait_hosts() -> void:
	var player := _create_portrait_host("PlayerPortrait")
	_player_portrait_host = player["host"]
	_player_medallion = player["medallion"]
	_player_portrait_texture = player["texture"]
	_player_portrait_name = player["name"]
	_player_emphasis = player["emphasis"]
	_dim.add_child(_player_portrait_host)

	var counterpart := _create_portrait_host("CounterpartPortrait")
	_counterpart_portrait_host = counterpart["host"]
	_counterpart_medallion = counterpart["medallion"]
	_counterpart_portrait_texture = counterpart["texture"]
	_counterpart_portrait_name = counterpart["name"]
	_counterpart_emphasis = counterpart["emphasis"]
	_dim.add_child(_counterpart_portrait_host)
	deactivate_portraits()


func _create_portrait_host(host_name: String) -> Dictionary:
	var host := Control.new()
	host.name = host_name
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	host.gui_input.connect(_on_surface_gui_input)

	var medallion := ColorRect.new()
	medallion.name = "PortraitMedallion"
	medallion.color = PORTRAIT_PAPER_COLOR
	medallion.anchor_left = 0.0
	medallion.anchor_top = PORTRAIT_SQUARE_TOP
	medallion.anchor_right = 1.0
	medallion.anchor_bottom = PORTRAIT_SQUARE_BOTTOM
	medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medallion.material = _portrait_medallion_material()
	host.add_child(medallion)

	var emphasis := Panel.new()
	emphasis.name = "ActiveEmphasis"
	emphasis.theme_type_variation = &"DialogueActiveEmphasis"
	emphasis.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	emphasis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(emphasis)

	var texture := TextureRect.new()
	texture.name = "PortraitTexture"
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.anchor_left = 0.0
	texture.anchor_top = PORTRAIT_SQUARE_TOP
	texture.anchor_right = 1.0
	texture.anchor_bottom = PORTRAIT_SQUARE_BOTTOM
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.material = _portrait_material()
	host.add_child(texture)

	var display_name := _make_label("", 15)
	display_name.name = "PortraitName"
	display_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	display_name.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	display_name.add_theme_color_override("font_color", Color("#17140f"))
	display_name.add_theme_color_override("font_outline_color", PORTRAIT_PAPER_COLOR)
	display_name.add_theme_constant_override("outline_size", 4)
	display_name.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display_name.offset_top = -42.0
	display_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(display_name)
	return {
		"host": host,
		"medallion": medallion,
		"texture": texture,
		"name": display_name,
		"emphasis": emphasis,
	}


func _portrait_medallion_material() -> ShaderMaterial:
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


func _portrait_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float saturation = 0.25; void fragment(){ vec4 c = texture(TEXTURE, UV) * COLOR; float g = dot(c.rgb, vec3(0.299, 0.587, 0.114)); c.rgb = mix(vec3(g), c.rgb, saturation); COLOR = c; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _apply_portrait_activity(
	host: Control,
	texture: TextureRect,
	emphasis: Panel,
	state: Dictionary,
	active: bool
) -> void:
	state["active"] = active
	state["opacity"] = 1.0 if active else 0.52
	state["emphasis_visible"] = active
	host.modulate.a = float(state["opacity"])
	emphasis.visible = active
	emphasis.modulate.a = 0.42
	if texture.material is ShaderMaterial:
		(texture.material as ShaderMaterial).set_shader_parameter("saturation", 1.0 if active else 0.25)


func _on_content_appended(height: float) -> void:
	var previous_value := _logical_scroll_value
	_logical_scroll_maximum += maxf(0.0, height)
	if _follow_latest:
		_logical_scroll_value = _logical_scroll_maximum
		set_return_to_latest_visible(false)
		call_deferred("_sync_actual_scroll_to_latest")
	else:
		_logical_scroll_value = previous_value
		set_return_to_latest_visible(true)


func _return_to_latest() -> void:
	_follow_latest = true
	_logical_scroll_value = _logical_scroll_maximum
	set_return_to_latest_visible(false)
	_sync_actual_scroll_to_latest()
	return_to_latest_requested.emit()


func _sync_actual_scroll_to_latest() -> void:
	if _scroll == null:
		return
	_ignore_scroll_signal = true
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
	_ignore_scroll_signal = false


func _on_actual_scroll_changed(value: float) -> void:
	if _ignore_scroll_signal or _scroll == null:
		return
	if not _manual_scroll_pending and not _scrollbar_dragging:
		if _follow_latest:
			call_deferred("_sync_actual_scroll_to_latest")
		return
	var maximum := float(_scroll.get_v_scroll_bar().max_value)
	_logical_scroll_maximum = maximum
	_logical_scroll_value = clampf(value, 0.0, maximum)
	_follow_latest = maximum - _logical_scroll_value <= 2.0
	set_return_to_latest_visible(not _follow_latest)
	if not _scrollbar_dragging:
		_manual_scroll_pending = false


func _on_scroll_metrics_changed() -> void:
	if _ignore_scroll_signal:
		return
	if _follow_latest:
		call_deferred("_sync_actual_scroll_to_latest")


func _on_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_manual_scroll_pending = true
			accept_event()
	elif event is InputEventScreenDrag:
		_manual_scroll_pending = true
		accept_event()


func _on_scrollbar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_scrollbar_dragging = event.pressed
			_manual_scroll_pending = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_manual_scroll_pending = true
	elif event is InputEventMouseMotion and _scrollbar_dragging:
		_manual_scroll_pending = true
	elif event is InputEventScreenTouch:
		_scrollbar_dragging = event.pressed
		_manual_scroll_pending = event.pressed
	elif event is InputEventScreenDrag:
		_manual_scroll_pending = true
	elif event is InputEventKey or event is InputEventAction:
		_manual_scroll_pending = true
	_consume_control_input(event)


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(FONT_PATH):
		label.add_theme_font_override("font", load(FONT_PATH))
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _estimated_row_height(text: String, speech: bool) -> float:
	var estimated_lines := maxi(1, ceili(float(maxi(1, text.length())) / 64.0))
	return float(estimated_lines * 24 + (38 if speech else 18))


func _on_surface_gui_input(event: InputEvent) -> void:
	if _is_surface_pointer_press(event):
		accept_event()
		surface_activated.emit(event)


func _consume_control_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey or event is InputEventAction:
		accept_event()


func _layout_for_viewport() -> void:
	if _frame == null:
		return
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	_layout_with_size(viewport_size)


func _layout_with_size(viewport_size: Vector2) -> void:
	var target := Vector2(
		clampf(viewport_size.x - FRAME_VIEWPORT_MARGIN.x * 2.0, FRAME_MIN_SIZE.x, FRAME_REFERENCE_SIZE.x),
		clampf(viewport_size.y - FRAME_VIEWPORT_MARGIN.y * 2.0, FRAME_MIN_SIZE.y, FRAME_REFERENCE_SIZE.y)
	)
	_frame.position = (viewport_size - target) * 0.5
	_frame.size = target
	_frame.custom_minimum_size = Vector2.ZERO
	var portrait_width := clampf(target.y * 0.38, 180.0, 260.0)
	var portrait_size := Vector2(portrait_width, portrait_width * 1.18)
	var frame_rect := Rect2(_frame.position, target)
	_player_portrait_host.size = portrait_size
	_player_portrait_host.position = Vector2(
		frame_rect.position.x - portrait_width * 0.95,
		frame_rect.end.y - portrait_size.y * 0.86
	)
	_counterpart_portrait_host.size = portrait_size
	_counterpart_portrait_host.position = Vector2(
		frame_rect.end.x - portrait_width * 0.05,
		frame_rect.end.y - portrait_size.y * 0.86
	)


static func _is_surface_pointer_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return event.pressed
	return false


static func _collect_button_texts(node: Node, output: Array) -> void:
	if node is Button and (node as Button).visible:
		output.append((node as Button).text)
	for child in node.get_children():
		_collect_button_texts(child, output)
