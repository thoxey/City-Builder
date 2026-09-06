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
var _effect_grid: GridContainer
var _effect_row_projections: Array = []
var _effect_rows_fingerprint := ""
var _cancel_button: Button
var _model: Dictionary = {}
var _ui_scale := 1.0
var _right_safe_inset := 0.0

func setup() -> void:
	name = "PlayerToolDock"
	theme_type_variation = "ToolDock"
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -360
	offset_right = 360
	offset_top = -204
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
	_context_group.offset_left = -166.0
	_context_group.offset_right = 166.0
	_context_group.offset_top = -92.0
	_context_group.offset_bottom = 92.0
	_context_group.add_theme_constant_override("separation", 0)
	layout.add_child(_context_group)
	_context_icon = TextureRect.new()
	_context_icon.custom_minimum_size = Vector2(46, 46)
	_context_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_context_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_context_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_context_group.add_child(_context_icon)
	_context_label = Label.new()
	_context_label.custom_minimum_size = Vector2(324, 42)
	_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_context_label.add_theme_font_override("font", FONT)
	_context_label.add_theme_font_size_override("font_size", 18)
	_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_context_group.add_child(_context_label)
	_effect_grid = GridContainer.new()
	_effect_grid.name = "AuthoredEffects"
	_effect_grid.columns = 2
	_effect_grid.add_theme_constant_override("h_separation", 8)
	_effect_grid.add_theme_constant_override("v_separation", 2)
	_effect_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_context_group.add_child(_effect_grid)
	_demolish_button = _button("bulldoze", "Demolish — toggle demolition mode")
	_demolish_button.toggle_mode = true
	_demolish_button.pressed.connect(func(): demolition_requested.emit(_demolish_button.button_pressed))
	_place_button(_demolish_button, layout, 184.0)
	_cancel_button = _button("cancel", "Cancel the current tool (Esc)")
	_cancel_button.pressed.connect(func(): cancel_requested.emit())
	_place_button(_cancel_button, layout, 264.0)
	show_idle()

func set_right_safe_inset(inset: float) -> void:
	_right_safe_inset = inset
	_apply_scaled_placement()


func apply_viewport_layout(viewport_width: float) -> void:
	_ui_scale = ui_scale_for_width(viewport_width)
	scale = Vector2(_ui_scale, _ui_scale)
	pivot_offset = Vector2(360.0, 192.0)
	_apply_scaled_placement()


static func ui_scale_for_width(viewport_width: float) -> float:
	return clampf(viewport_width / 1920.0, 1.0, 2.0)


func _apply_scaled_placement() -> void:
	# Scaling is applied around the dock's centre-bottom pivot, so its anchored
	# centre stays in physical viewport coordinates and uses the physical inset.
	offset_left = -360.0 - _right_safe_inset * 0.5
	offset_right = 360.0 - _right_safe_inset * 0.5

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
	_clear_effect_rows()
	_cancel_button.visible = false
	_demolish_button.button_pressed = false

func show_placement(entry_id: String, blocked_reason: String = "", rotation: int = 0, _preview: Dictionary = {}) -> void:
	var entry: Dictionary = _model.get("entries_by_id", {}).get(entry_id, {})
	var icon_key := String(entry.get("icon_key", "missing-artwork"))
	var path := "res://sprites/ui/build-menu/entries/%s.png" % icon_key
	_context_icon.texture = load(path) if ResourceLoader.exists(path) else load("res://sprites/ui/build-menu/controls/missing-artwork.png")
	_context_group.visible = true
	_context_label.text = "%s\n%s" % [entry.get("display_name", "Placement"),
		("Blocked: %s" % blocked_reason) if not blocked_reason.is_empty() else "Rotate  Z"]
	_render_authored_rows(entry)
	_cancel_button.visible = true
	_demolish_button.button_pressed = false

func show_demolition() -> void:
	_context_icon.texture = load("res://sprites/ui/build-menu/controls/bulldoze.png")
	_context_group.visible = true
	_context_label.text = "Demolition\nSelect a building"
	_clear_effect_rows()
	_cancel_button.visible = true
	_demolish_button.button_pressed = true


func effect_row_projection() -> Array:
	return _effect_row_projections.duplicate(true)


func _render_authored_rows(entry: Dictionary) -> void:
	var fingerprint := JSON.stringify({
		"cash": entry.get("representative_cash_cost", entry.get("cash_cost", 0)),
		"demand": entry.get("representative_demand_cost", entry.get("demand_cost", {})),
		"effects": entry.get("authored_effects", []),
	})
	if fingerprint == _effect_rows_fingerprint:
		return
	_clear_effect_rows()
	_effect_rows_fingerprint = fingerprint
	var cash_value: Variant = entry.get("representative_cash_cost", entry.get("cash_cost", 0))
	var cash_cost := int(cash_value.get("min", 0)) if cash_value is Dictionary else int(cash_value)
	if cash_cost != 0:
		_add_effect_row("cash", "res://sprites/ui/status/cash-purse.png", "Cash", "-£%d" % absi(cash_cost), "Authored cash cost")
	var demand: Dictionary = entry.get("representative_demand_cost", entry.get("demand_cost", {}))
	var bucket_id := String(demand.get("bucket_id", ""))
	var demand_cost := float(demand.get("cost", 0.0))
	if not bucket_id.is_empty() and not is_zero_approx(demand_cost):
		var demand_info: Dictionary = {
			"residential":{"label":"Homes", "icon":"res://sprites/community_icons/game/housing-capacity.png"},
			"industrial":{"label":"Work", "icon":"res://sprites/ui/build-menu/categories/industry.png"},
			"commercial":{"label":"Shops", "icon":"res://sprites/ui/build-menu/categories/commerce.png"},
		}.get(bucket_id, {"label":bucket_id.capitalize(), "icon":""})
		_add_effect_row("demand", String(demand_info["icon"]), String(demand_info["label"]), _signed_number(-absf(demand_cost)), "%s demand cost" % demand_info["label"])
	for effect_variant in entry.get("authored_effects", []):
		var effect: Dictionary = effect_variant
		var quality := String(effect.get("quality", ""))
		var amount := float(effect.get("amount", 0.0))
		if quality not in CommunityConstants.QUALITIES or is_zero_approx(amount):
			continue
		var label := "Liveability" if quality == "liveability" else quality.capitalize()
		var tooltip := String(effect.get("reason", ""))
		var scope := String(effect.get("scope", ""))
		if not scope.is_empty():
			tooltip = "%s%s%s" % [tooltip, " — " if not tooltip.is_empty() else "", scope.capitalize()]
		_add_effect_row("community", CommunityUIFactory.ICON_ROOT + quality + ".png", label, _signed_number(amount), tooltip)


func _add_effect_row(kind: String, icon_path: String, label: String, signed_value: String, tooltip: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(158, 22)
	row.add_theme_constant_override("separation", 3)
	row.tooltip_text = tooltip
	var icon_available := not icon_path.is_empty() and ResourceLoader.exists(icon_path)
	if icon_available:
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	var text := Label.new()
	text.text = "%s %s" % [label, signed_value]
	text.add_theme_font_override("font", FONT)
	text.add_theme_font_size_override("font_size", 14)
	text.add_theme_color_override("font_color", Color("58705a") if signed_value.begins_with("+") else Color("a9473f"))
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	_effect_grid.add_child(row)
	_effect_row_projections.append({
		"kind": kind, "icon_path": icon_path, "icon_available": icon_available,
		"label": label, "signed_value": signed_value, "tooltip": tooltip,
	})


func _clear_effect_rows() -> void:
	_effect_row_projections.clear()
	_effect_rows_fingerprint = ""
	if _effect_grid == null:
		return
	for child in _effect_grid.get_children():
		_effect_grid.remove_child(child)
		child.queue_free()


static func _signed_number(value: float) -> String:
	return "%+.0f" % value if is_equal_approx(value, roundf(value)) else "%+.1f" % value
