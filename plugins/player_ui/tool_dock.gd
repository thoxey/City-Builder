extends PanelContainer
class_name PlayerToolDock

signal build_requested
signal demolition_requested(active: bool)
signal cancel_requested

const FONT := preload("res://fonts/lilita_one_regular.ttf")
var _build_button: Button
var _demolish_button: Button
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
	offset_top = -82
	offset_bottom = -12
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	_build_button = _button("Build  B", "open-build", "Open the build menu")
	_build_button.pressed.connect(func(): build_requested.emit())
	row.add_child(_build_button)
	_context_icon = TextureRect.new()
	_context_icon.custom_minimum_size = Vector2(38, 38)
	_context_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_context_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_context_icon)
	_context_label = Label.new()
	_context_label.custom_minimum_size = Vector2(220, 44)
	_context_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_context_label.add_theme_font_override("font", FONT)
	_context_label.add_theme_font_size_override("font_size", 14)
	row.add_child(_context_label)
	_demolish_button = _button("Demolish", "bulldoze", "Toggle demolition mode")
	_demolish_button.toggle_mode = true
	_demolish_button.pressed.connect(func(): demolition_requested.emit(_demolish_button.button_pressed))
	row.add_child(_demolish_button)
	_cancel_button = _button("Cancel  Esc", "cancel", "Cancel the current tool")
	_cancel_button.pressed.connect(func(): cancel_requested.emit())
	row.add_child(_cancel_button)
	show_idle()

func set_right_safe_inset(inset: float) -> void:
	offset_left = -360.0 - inset * 0.5
	offset_right = 360.0 - inset * 0.5

func _button(text_value: String, icon_key: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.icon = load("res://sprites/ui/build-menu/controls/%s.png" % icon_key)
	button.expand_icon = true
	button.custom_minimum_size = Vector2(96, 48)
	button.tooltip_text = tooltip
	button.add_theme_font_override("font", FONT)
	return button

func set_model(model: Dictionary) -> void:
	_model = model.duplicate(true)

func show_idle() -> void:
	_context_icon.texture = null
	_context_label.text = "Choose a tool"
	_cancel_button.visible = false
	_demolish_button.button_pressed = false

func show_placement(entry_id: String, blocked_reason: String = "", rotation: int = 0) -> void:
	var entry: Dictionary = _model.get("entries_by_id", {}).get(entry_id, {})
	var icon_key := String(entry.get("icon_key", "missing-artwork"))
	var path := "res://sprites/ui/build-menu/entries/%s.png" % icon_key
	_context_icon.texture = load(path) if ResourceLoader.exists(path) else load("res://sprites/ui/build-menu/controls/missing-artwork.png")
	var cost: Variant = entry.get("cash_cost", 0)
	var cost_text := "£%d" % int(cost) if cost is int or cost is float else "£%d–£%d" % [int(cost.get("min", 0)), int(cost.get("max", 0))]
	_context_label.text = "%s  •  %s\n%s" % [entry.get("display_name", "Placement"), cost_text,
		("Blocked: %s" % blocked_reason) if not blocked_reason.is_empty() else "Place: click/A  •  Rotate: RMB  •  %d°" % (rotation * 90)]
	_cancel_button.visible = true
	_demolish_button.button_pressed = false

func show_demolition() -> void:
	_context_icon.texture = load("res://sprites/ui/build-menu/controls/bulldoze.png")
	_context_label.text = "DEMOLITION\nSelect a building to remove"
	_cancel_button.visible = true
	_demolish_button.button_pressed = true
