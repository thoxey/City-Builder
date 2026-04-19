extends PluginBase

## DialoguePlugin — CK3-style modal renderer for `dialogue` events.
##
## Listens to EventSystem.event_resolved; records with `event_type == "dialogue"`
## get queued and rendered in the central 60% of the viewport with a dimmed
## backdrop. Other event types are ignored (newspaper / notification stubs
## render themselves from the same signal).
##
## Arrival-tree quirk: the modal is what advances a character from ARRIVED to
## WANT_REVEALED. On tree close, if the originating trigger was
## `character_arrived`, we call CharacterSystem.mark_want_revealed(cid).
## This lets CharacterSystem.AUTO_REVEAL_WANT stay `false` now that the modal
## is in place.

const FONT_PATH := "res://fonts/lilita_one_regular.ttf"

var _event_system: PluginBase
var _characters:   PluginBase
var _catalog:      PluginBase

# FIFO of pending event records (dicts). Head is the active modal when open.
var _queue: Array[Dictionary] = []

# Active modal UI state ───────────────────────────────────────────────────────
var _canvas: CanvasLayer
var _dim: ColorRect
var _modal: PanelContainer
var _portrait: TextureRect
var _name_label: Label
var _sub_label: Label
var _body: RichTextLabel
var _options_box: HBoxContainer
var _chip_label: Label

var _current: Dictionary = {}
var _current_node_id: String = ""
var _visited: int = 0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func get_plugin_name() -> String:
	return "Dialogue"

func get_dependencies() -> Array[String]:
	return ["EventSystem", "CharacterSystem"]

func inject(deps: Dictionary) -> void:
	_event_system = deps.get("EventSystem")
	_characters   = deps.get("CharacterSystem")

func _plugin_ready() -> void:
	_catalog = PluginManager.get_plugin("BuildingCatalog")
	_build_ui()
	if _event_system:
		_event_system.event_resolved.connect(_on_event_resolved)

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 20   # above HUD (layer 5) and nameplate (layer 1 default)
	_canvas.visible = false
	add_child(_canvas)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_dim)

	_modal = PanelContainer.new()
	_modal.set_anchors_preset(Control.PRESET_CENTER)
	_modal.custom_minimum_size = Vector2(900, 520)
	_modal.size = Vector2(900, 520)
	# Centre: offsets relative to the anchor (anchor = 0.5/0.5 for PRESET_CENTER)
	_modal.offset_left   = -450
	_modal.offset_right  =  450
	_modal.offset_top    = -260
	_modal.offset_bottom =  260
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_modal)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	_modal.add_child(margin)

	var root_hbox := HBoxContainer.new()
	root_hbox.add_theme_constant_override("separation", 18)
	margin.add_child(root_hbox)

	# Left column: portrait
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(300, 484)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.size_flags_vertical = Control.SIZE_FILL
	root_hbox.add_child(_portrait)

	# Right column: name, sub, body, options
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_hbox.add_child(right_vbox)

	_name_label = _mk_label("", 32)
	_sub_label  = _mk_label("", 14)
	_sub_label.modulate = Color(0.8, 0.8, 0.8, 1)
	right_vbox.add_child(_name_label)
	right_vbox.add_child(_sub_label)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = false
	_body.scroll_active = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_override("normal_font", load(FONT_PATH))
	_body.add_theme_font_size_override("normal_font_size", 18)
	right_vbox.add_child(_body)

	_options_box = HBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 10)
	_options_box.alignment = BoxContainer.ALIGNMENT_END
	right_vbox.add_child(_options_box)

	# Queue chip (top-right)
	_chip_label = Label.new()
	_chip_label.text = ""
	_chip_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_chip_label.offset_left = -140
	_chip_label.offset_right = -20
	_chip_label.offset_top = 20
	_chip_label.offset_bottom = 56
	_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chip_label.add_theme_font_override("font", load(FONT_PATH))
	_chip_label.add_theme_font_size_override("font_size", 20)
	_chip_label.modulate = Color(1, 1, 1, 0.9)
	_chip_label.visible = false
	_canvas.add_child(_chip_label)

func _mk_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load(FONT_PATH))
	l.add_theme_font_size_override("font_size", size)
	return l

# ── Queue + signal handling ───────────────────────────────────────────────────

func _on_event_resolved(record: Dictionary) -> void:
	if String(record.get("event_type", "")) != "dialogue":
		return
	_queue.append(record.duplicate(true))
	print("[Dialogue] queue_push: event_id=%s queue_size=%d" % [
		String(record.get("event_id", "")), _queue.size()
	])
	if not is_modal_open():
		_open_next()
	else:
		_refresh_chip()

func _refresh_chip() -> void:
	var pending: int = max(_queue.size() - 1, 0)
	if pending > 0:
		_chip_label.text = "×%d" % pending
		_chip_label.visible = true
	else:
		_chip_label.visible = false

# ── Opening / closing ─────────────────────────────────────────────────────────

func _open_next() -> void:
	if _queue.is_empty():
		_canvas.visible = false
		return
	_current = _queue[0]
	_visited = 0
	var payload: Dictionary = _current.get("payload", {})
	var entry_id := String(payload.get("entry_node_id", ""))
	if entry_id.is_empty():
		push_warning("[Dialogue] no_entry_node: event_id=%s" % _current.get("event_id", ""))
		_close_current()
		return
	_canvas.visible = true
	_populate_speaker_header()
	_enter_node(entry_id)
	print("[Dialogue] modal_opened: event_id=%s node=%s" % [
		String(_current.get("event_id", "")), entry_id
	])
	_refresh_chip()

func _close_current() -> void:
	var eid := String(_current.get("event_id", ""))
	print("[Dialogue] modal_closed: event_id=%s nodes_visited=%d" % [eid, _visited])
	# Arrival-tree → promote to WANT_REVEALED.
	var trig: Dictionary = _current.get("trigger", {})
	if String(trig.get("event", "")) == "character_arrived":
		var cid := String(trig.get("character_id", ""))
		if not cid.is_empty() and _characters and _characters.has_method("mark_want_revealed"):
			_characters.mark_want_revealed(cid)
	_current = {}
	_current_node_id = ""
	if not _queue.is_empty():
		_queue.pop_front()
	if _queue.is_empty():
		_canvas.visible = false
		_refresh_chip()
	else:
		# Give the UI a tick to repaint before the next open.
		call_deferred("_open_next")

func is_modal_open() -> bool:
	return _canvas and _canvas.visible

# ── Node rendering ────────────────────────────────────────────────────────────

func _populate_speaker_header() -> void:
	var trig: Dictionary = _current.get("trigger", {})
	var cid := String(trig.get("character_id", ""))
	var pid := String(trig.get("patron_id", ""))
	var name := ""
	var sub := ""
	var portrait_path := ""
	if not cid.is_empty() and _characters:
		var def: Dictionary = _characters.get_def(cid)
		name = String(def.get("display_name", cid))
		sub = String(def.get("bio", ""))
		portrait_path = String(def.get("portrait", ""))
	elif not pid.is_empty():
		var ps: PluginBase = PluginManager.get_plugin("PatronSystem")
		if ps:
			var pdef: Dictionary = ps.get_def(pid)
			name = String(pdef.get("display_name", pid))
			sub = String(pdef.get("bio", ""))
			portrait_path = String(pdef.get("portrait", ""))
	else:
		name = String(_current.get("event_id", ""))
	_name_label.text = name
	_sub_label.text = sub
	_portrait.texture = _load_portrait_or_placeholder(portrait_path)

func _load_portrait_or_placeholder(path: String) -> Texture2D:
	if not path.is_empty() and ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		if t != null:
			return t
	# Placeholder: 1×1 mid-grey so the TextureRect doesn't render empty.
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(0.3, 0.3, 0.35, 1.0))
	return ImageTexture.create_from_image(img)

func _enter_node(node_id: String) -> void:
	_current_node_id = node_id
	_visited += 1
	var payload: Dictionary = _current.get("payload", {})
	var node: Dictionary = _find_node(payload, node_id)
	if node.is_empty():
		push_warning("[Dialogue] node_not_found: event_id=%s node=%s" % [
			_current.get("event_id", ""), node_id
		])
		_close_current()
		return
	if _event_system:
		_event_system.apply_effects(node.get("on_enter", []))
	_body.text = String(node.get("body", ""))
	_rebuild_options(node.get("options", []))
	print("[Dialogue] node_entered: node=%s" % node_id)

func _find_node(payload: Dictionary, node_id: String) -> Dictionary:
	for n in payload.get("nodes", []):
		if typeof(n) == TYPE_DICTIONARY and String(n.get("node_id", "")) == node_id:
			return n
	return {}

func _rebuild_options(options: Array) -> void:
	for child in _options_box.get_children():
		child.queue_free()
	if options.is_empty():
		# Terminal node — render a default "Continue" that closes.
		_add_option({"label": "Continue", "next": "", "effects": []})
		return
	for opt in options:
		if typeof(opt) == TYPE_DICTIONARY:
			_add_option(opt)

func _add_option(opt: Dictionary) -> void:
	var btn := Button.new()
	btn.text = String(opt.get("label", "(unlabelled)"))
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_override("font", load(FONT_PATH))
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(_on_option_pressed.bind(opt))
	_options_box.add_child(btn)

func _on_option_pressed(opt: Dictionary) -> void:
	var label := String(opt.get("label", ""))
	var next_id := String(opt.get("next", ""))
	print("[Dialogue] option_selected: event_id=%s label=\"%s\" next=%s" % [
		String(_current.get("event_id", "")), label, next_id
	])
	if _event_system:
		_event_system.apply_effects(opt.get("effects", []))
	if next_id.is_empty():
		_close_current()
	else:
		_enter_node(next_id)

# ── Input ─────────────────────────────────────────────────────────────────────

## Builder reads this to suppress placement while a modal is open.
func is_input_suppressed() -> bool:
	return is_modal_open()

func _input(event: InputEvent) -> void:
	if not is_modal_open():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# Close on Esc only if the current node has a "Continue"/terminal default
		# — i.e. zero options. Otherwise the player must pick.
		var node: Dictionary = _find_node(_current.get("payload", {}), _current_node_id)
		if node.get("options", []).is_empty():
			_close_current()
			get_viewport().set_input_as_handled()

# ── Test hooks ────────────────────────────────────────────────────────────────

func queue_dialogue_for_test(record: Dictionary) -> void:
	_on_event_resolved(record)

func queue_size() -> int:
	return _queue.size()

func current_node_id() -> String:
	return _current_node_id
