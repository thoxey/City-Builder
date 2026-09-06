extends PanelContainer
class_name PlayerToolDock

signal build_requested
signal demolition_requested(active: bool)
signal cancel_requested

const FONT := preload("res://fonts/lilita_one_regular.ttf")
var _build_button: Button
var _demolish_button: Button
var _context_group: VBoxContainer
var _context_icon: TextureRect
var _context_label: Label
var _cancel_button: Button
var _model: Dictionary = {}

func setup() -> void:
	name = "PlayerToolDock"
	theme_type_variation = "ToolDock"
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -360
	offset_right = 360
	offset_top = -142
	offset_bottom = -12
	var layout := Control.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	_build_button = _button("open-build", "Build — open the build menu (B)")
	_build_button.pressed.connect(func(): build_requested.emit())
	_place_button(_build_button, layout, -184.0)
	_context_group = VBoxContainer.new()
	_context_group.alignment = BoxContainer.ALIGNMENT_CENTER
	_context_group.set_anchors_preset(Control.PRESET_CENTER)
	_context_group.offset_left = -140.0
	_context_group.offset_right = 140.0
	_context_group.offset_top = -57.0
	_context_group.offset_bottom = 57.0
	_context_group.add_theme_constant_override("separation", 0)
	layout.add_child(_context_group)
	_context_icon = TextureRect.new()
	_context_icon.custom_minimum_size = Vector2(62, 62)
	_context_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_context_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_context_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_context_group.add_child(_context_icon)
	_context_label = Label.new()
	_context_label.custom_minimum_size = Vector2(270, 48)
	_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_context_label.add_theme_font_override("font", FONT)
	_context_label.add_theme_font_size_override("font_size", 20)
	_context_label.clip_text = true
	_context_group.add_child(_context_label)
	_demolish_button = _button("bulldoze", "Demolish — toggle demolition mode")
	_demolish_button.toggle_mode = true
	_demolish_button.pressed.connect(func(): demolition_requested.emit(_demolish_button.button_pressed))
	_place_button(_demolish_button, layout, 184.0)
	_cancel_button = _button("cancel", "Cancel the current tool (Esc)")
	_cancel_button.pressed.connect(func(): cancel_requested.emit())
	_place_button(_cancel_button, layout, 264.0)
	show_idle()

func set_right_safe_inset(inset: float) -> void:
	offset_left = -360.0 - inset * 0.5
	offset_right = 360.0 - inset * 0.5

func _button(icon_key: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.icon = load("res://sprites/ui/build-menu/controls/%s.png" % icon_key)
	button.expand_icon = true
	button.custom_minimum_size = Vector2(72, 72)
	button.tooltip_text = tooltip
	button.add_theme_constant_override("icon_max_width", 54)
	button.add_theme_stylebox_override("normal", _button_style(Color(0, 0, 0, 0), 0, Color.TRANSPARENT))
	button.add_theme_stylebox_override("hover", _button_style(Color("ecd36e"), 3, Color("171713")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("d3a526"), 3, Color("171713")))
	button.add_theme_stylebox_override("hover_pressed", _button_style(Color("dfb93e"), 4, Color("171713")))
	button.add_theme_stylebox_override("focus", _button_style(Color(0, 0, 0, 0), 4, Color("d3a526")))
	return button

func _place_button(button: Button, parent: Control, centre_x: float) -> void:
	button.anchor_left = 0.5
	button.anchor_top = 0.5
	button.anchor_right = 0.5
	button.anchor_bottom = 0.5
	button.offset_left = centre_x - 36.0
	button.offset_right = centre_x + 36.0
	button.offset_top = -36.0
	button.offset_bottom = 36.0
	parent.add_child(button)

func _button_style(fill: Color, border_width: int, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(12)
	style.content_margin_left = 7.0
	style.content_margin_top = 7.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 7.0
	return style

func set_model(model: Dictionary) -> void:
	_model = model.duplicate(true)

func show_idle() -> void:
	_context_icon.texture = null
	_context_label.text = ""
	_context_group.visible = false
	_cancel_button.visible = false
	_demolish_button.button_pressed = false

func show_placement(entry_id: String, blocked_reason: String = "", rotation: int = 0, preview: Dictionary = {}) -> void:
	var entry: Dictionary = _model.get("entries_by_id", {}).get(entry_id, {})
	var icon_key := String(entry.get("icon_key", "missing-artwork"))
	var path := "res://sprites/ui/build-menu/entries/%s.png" % icon_key
	_context_icon.texture = load(path) if ResourceLoader.exists(path) else load("res://sprites/ui/build-menu/controls/missing-artwork.png")
	_context_group.visible = true
	_context_label.text = "%s\n%s" % [entry.get("display_name", "Placement"),
		("Blocked: %s" % blocked_reason) if not blocked_reason.is_empty() else "Rotate  Z"]
	_cancel_button.visible = true
	_demolish_button.button_pressed = false

func show_demolition() -> void:
	_context_icon.texture = load("res://sprites/ui/build-menu/controls/bulldoze.png")
	_context_group.visible = true
	_context_label.text = "Demolition\nSelect a building"
	_cancel_button.visible = true
	_demolish_button.button_pressed = true
