extends PluginBase

## Inbox — queued-dialogue panel.
##
## Stands between EventSystem and DialoguePlugin so that dialogue events don't
## auto-open a modal. When EventSystem resolves a `dialogue` event, the record
## lands in this plugin's pending list instead. A small top-right button shows
## the count and, when clicked, expands a list of who's waiting. Clicking an
## entry hands the record to DialoguePlugin.open_event() which opens the modal.
##
## Newspaper / notification events bypass the inbox — they're handled by their
## own renderer plugins (NewspaperPlugin / NotificationPlugin) directly.

const FONT_PATH := "res://fonts/lilita_one_regular.ttf"

var _event_system: PluginBase
var _dialogue:     PluginBase
var _characters:   PluginBase
var _patrons:      PluginBase

# Pending records, oldest-first. Each is a duplicate of the resolved event dict.
var _pending: Array[Dictionary] = []

# UI ──────────────────────────────────────────────────────────────────────────
var _canvas: CanvasLayer
var _button: Button         # collapsed entry-point (envelope + count)
var _badge: Label           # red dot with count, overlaid on the button
var _list_panel: PanelContainer
var _list_box: VBoxContainer
var _expanded: bool = false
var _presentation_enabled: bool = true

func set_presentation_enabled(enabled: bool) -> void:
	_presentation_enabled = enabled
	if _canvas:
		_canvas.visible = enabled

func get_plugin_name() -> String:
	return "Inbox"

func get_dependencies() -> Array[String]:
	return ["EventSystem", "Dialogue"]

func inject(deps: Dictionary) -> void:
	_event_system = deps.get("EventSystem")
	_dialogue     = deps.get("Dialogue")

func _plugin_ready() -> void:
	_characters = PluginManager.get_plugin("CharacterSystem")
	_patrons    = PluginManager.get_plugin("PatronSystem")
	_build_ui()
	if _event_system:
		_event_system.event_resolved.connect(_on_event_resolved)
	print("[Inbox] ready: pending=0")

# ── UI ────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	# Below Dialogue (20) so an open modal sits over the inbox. Above HUD (5)
	# so the button is reachable when the player has the build palette open.
	_canvas.layer = 10
	add_child(_canvas)

	# Anchor host stays at the top-right corner. Button + expanded list both
	# live inside it so they move together if the viewport resizes.
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	anchor.offset_left   = -260
	anchor.offset_right  = -10
	anchor.offset_top    = 10
	anchor.offset_bottom = 500
	anchor.mouse_filter = Control.MOUSE_FILTER_PASS
	_canvas.add_child(anchor)

	# Collapsed button — sits at the top-right of the anchor.
	_button = Button.new()
	_button.text = "Inbox"
	_button.custom_minimum_size = Vector2(110, 36)
	_button.add_theme_font_override("font", load(FONT_PATH))
	_button.add_theme_font_size_override("font_size", 16)
	_button.focus_mode = Control.FOCUS_NONE
	_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_button.offset_left   = -110
	_button.offset_right  = 0
	_button.offset_top    = 0
	_button.offset_bottom = 36
	_button.pressed.connect(_toggle_expanded)
	anchor.add_child(_button)

	# Badge overlaid on the button's top-right corner.
	_badge = Label.new()
	_badge.text = "0"
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_badge.add_theme_font_override("font", load(FONT_PATH))
	_badge.add_theme_font_size_override("font_size", 14)
	_badge.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	var badge_bg := StyleBoxFlat.new()
	badge_bg.bg_color = Color(0.85, 0.15, 0.15, 1)
	badge_bg.corner_radius_top_left = 10
	badge_bg.corner_radius_top_right = 10
	badge_bg.corner_radius_bottom_left = 10
	badge_bg.corner_radius_bottom_right = 10
	_badge.add_theme_stylebox_override("normal", badge_bg)
	_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_badge.offset_left   = -22
	_badge.offset_right  = 2
	_badge.offset_top    = -8
	_badge.offset_bottom = 14
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.visible = false
	_button.add_child(_badge)

	# Expanded list panel — sits below the button.
	_list_panel = PanelContainer.new()
	_list_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_list_panel.offset_left   = -260
	_list_panel.offset_right  = 0
	_list_panel.offset_top    = 42
	_list_panel.offset_bottom = 460
	_list_panel.visible = false
	_list_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	anchor.add_child(_list_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	_list_panel.add_child(margin)

	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 6)
	margin.add_child(_list_box)

# ── Signal handling ───────────────────────────────────────────────────────────

func _on_event_resolved(record: Dictionary) -> void:
	if not _presentation_enabled:
		return
	if String(record.get("event_type", "")) != "dialogue":
		return
	_pending.append(record.duplicate(true))
	print("[Inbox] queued: event_id=%s pending=%d" % [
		String(record.get("event_id", "")), _pending.size()
	])
	_refresh_badge()
	if _expanded:
		_rebuild_list()

# ── Expansion / click handling ────────────────────────────────────────────────

func _toggle_expanded() -> void:
	_expanded = not _expanded
	_list_panel.visible = _expanded
	if _expanded:
		_rebuild_list()

func _collapse() -> void:
	_expanded = false
	_list_panel.visible = false

func _rebuild_list() -> void:
	for child in _list_box.get_children():
		child.queue_free()
	if _pending.is_empty():
		var empty := Label.new()
		empty.text = "No messages."
		empty.add_theme_font_override("font", load(FONT_PATH))
		empty.add_theme_font_size_override("font_size", 14)
		empty.modulate = Color(0.7, 0.7, 0.7, 1)
		_list_box.add_child(empty)
		return
	for i in range(_pending.size()):
		_list_box.add_child(_build_item(i, _pending[i]))

func _build_item(idx: int, record: Dictionary) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 56)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_open_item.bind(idx))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(44, 44)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture = _portrait_for(record)
	row.add_child(portrait)

	var labels := VBoxContainer.new()
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)

	var name_lbl := Label.new()
	name_lbl.text = _display_name_for(record)
	name_lbl.add_theme_font_override("font", load(FONT_PATH))
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = String(record.get("event_id", ""))
	sub_lbl.add_theme_font_override("font", load(FONT_PATH))
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.modulate = Color(0.7, 0.7, 0.75, 1)
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(sub_lbl)

	return btn

func _open_item(idx: int) -> void:
	if idx < 0 or idx >= _pending.size():
		return
	var record: Dictionary = _pending[idx]
	_pending.remove_at(idx)
	print("[Inbox] opened: event_id=%s remaining=%d" % [
		String(record.get("event_id", "")), _pending.size()
	])
	_refresh_badge()
	_collapse()
	if _dialogue and _dialogue.has_method("open_event"):
		_dialogue.open_event(record)

# ── Display helpers ───────────────────────────────────────────────────────────

func _display_name_for(record: Dictionary) -> String:
	var trig: Dictionary = record.get("trigger", {})
	var cid := String(trig.get("character_id", ""))
	if not cid.is_empty() and _characters:
		var d: Dictionary = _characters.get_def(cid)
		var n := String(d.get("display_name", ""))
		if not n.is_empty(): return n
	var pid := String(trig.get("patron_id", ""))
	if not pid.is_empty() and _patrons:
		var d: Dictionary = _patrons.get_def(pid)
		var n := String(d.get("display_name", ""))
		if not n.is_empty(): return n
	return String(record.get("event_id", "?"))

func _portrait_for(record: Dictionary) -> Texture2D:
	var trig: Dictionary = record.get("trigger", {})
	var path := ""
	var cid := String(trig.get("character_id", ""))
	if not cid.is_empty() and _characters:
		path = String(_characters.get_def(cid).get("portrait", ""))
	if path.is_empty():
		var pid := String(trig.get("patron_id", ""))
		if not pid.is_empty() and _patrons:
			path = String(_patrons.get_def(pid).get("portrait", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		if t != null:
			return t
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(0.3, 0.3, 0.35, 1.0))
	return ImageTexture.create_from_image(img)

func _refresh_badge() -> void:
	var n: int = _pending.size()
	if n <= 0:
		_badge.visible = false
		return
	_badge.text = str(n)
	_badge.visible = true

# ── Test hooks ────────────────────────────────────────────────────────────────

func pending_size() -> int:
	return _pending.size()

func pending_event_ids() -> Array:
	var out: Array = []
	for r in _pending:
		out.append(String(r.get("event_id", "")))
	return out

func push_for_test(record: Dictionary) -> void:
	_on_event_resolved(record)

func open_for_test(idx: int) -> void:
	_open_item(idx)
