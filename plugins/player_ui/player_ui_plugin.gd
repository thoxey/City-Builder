extends PluginBase

const RadialCls := preload("res://plugins/player_ui/radial_build_menu.gd")
const StatusCls := preload("res://plugins/player_ui/status_bar.gd")
const DockCls := preload("res://plugins/player_ui/tool_dock.gd")

var _deps: Dictionary = {}
var _builder: Node
var _palette: PluginBase
var _canvas: CanvasLayer
var _root: Control
var _radial: RadialBuildMenu
var _status: PlayerStatusBar
var _dock: PlayerToolDock
var _selected_entry_id := ""
var _last_safe_inset := -1.0

func get_plugin_name() -> String: return "PlayerUI"
func get_dependencies() -> Array[String]:
	return ["Palette", "Economy", "Demand", "UniqueRegistry", "Satisfaction", "Workplace",
		"Attractiveness", "Community", "Inbox", "Dashboard", "DayNight"]

func inject(deps: Dictionary) -> void:
	_deps = deps
	_palette = deps.get("Palette")

func _plugin_ready() -> void:
	_builder = get_tree().current_scene.find_child("Builder", true, false) if get_tree().current_scene else null
	_build_shell()
	_refresh_model()
	call_deferred("_ensure_forced_town_hall")
	GameEvents.build_menu_model_changed.connect(func(_revision): _refresh_model())
	GameEvents.placement_context_changed.connect(_on_placement_context)
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _build_shell() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 8
	add_child(_canvas)
	_root = Control.new()
	_root.name = "PlayerUIRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme_resource := load("res://themes/player_ui_theme.tres")
	if theme_resource: _root.theme = theme_resource
	_canvas.add_child(_root)
	_status = StatusCls.new()
	_root.add_child(_status)
	_status.setup(_deps)
	_status.insights_requested.connect(_open_insights)
	_status.inbox_requested.connect(_open_inbox)
	var inbox = _deps.get("Inbox")
	if inbox and inbox.has_method("set_shell_entry_point_external"): inbox.set_shell_entry_point_external(true)
	_dock = DockCls.new()
	_root.add_child(_dock)
	_dock.setup()
	_dock.build_requested.connect(open_build_menu)
	_dock.demolition_requested.connect(_toggle_demolition)
	_dock.cancel_requested.connect(_cancel_tool)
	_radial = RadialCls.new()
	_root.add_child(_radial)
	_radial.entry_requested.connect(_request_entry)
	_radial.menu_closed.connect(_on_radial_closed)
	_on_viewport_size_changed()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_menu"):
		if _radial.visible:
			_radial.back_or_close()
		elif _town_hall_required():
			_ensure_forced_town_hall()
		elif _builder and _builder.is_placement_active():
			_builder.cancel_placement()
			_dock.show_idle()
			open_build_menu(true)
		else:
			open_build_menu()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _dock == null or _radial == null:
		return
	var dashboard = _deps.get("Dashboard")
	var drawer_open: bool = bool(dashboard and dashboard._panel and dashboard._panel.visible)
	var inset: float = 380.0 if drawer_open else 0.0
	if inset != _last_safe_inset:
		_last_safe_inset = inset
		_dock.set_right_safe_inset(inset)
		_radial.set_right_safe_inset(inset)
	if _radial and _radial.visible and _builder and _builder.get_input_mode() == "modal":
		_radial.close_menu()

func open_build_menu(restore_context: bool = false) -> void:
	if _builder and _builder.get_input_mode() == "modal": return
	if _town_hall_required():
		_ensure_forced_town_hall()
		return
	_refresh_model()
	var pointer := get_viewport().get_mouse_position()
	_radial.open_menu(pointer, restore_context)
	if _builder: _builder.set_radial_input_active(true)

func _on_radial_closed() -> void:
	if _builder: _builder.set_radial_input_active(false)
	_dock._build_button.grab_focus()

func _request_entry(entry_id: String) -> void:
	var result: Dictionary = _palette.request_select_entry(entry_id)
	if not result.get("accepted", false):
		_refresh_model()
		return
	_selected_entry_id = entry_id
	_radial.close_menu()
	if _builder and _builder.begin_placement_from_palette():
		_dock.show_placement(entry_id)

func _refresh_model() -> void:
	if _palette == null: return
	var model: Dictionary = _palette.get_build_menu_model()
	if _radial: _radial.set_model(model)
	if _dock: _dock.set_model(model)
	if _builder and _builder.is_placement_active() and not _selected_entry_id.is_empty():
		var current: Dictionary = model.get("entries_by_id", {}).get(_selected_entry_id, {})
		if not current.get("can_select", false):
			_builder.cancel_placement()
			_dock.show_placement(_selected_entry_id, String(current.get("availability_label", "Unavailable")))

func _toggle_demolition(active: bool) -> void:
	if _builder: _builder.set_demolition_active(active)
	if active: _dock.show_demolition()
	else: _dock.show_idle()

func _cancel_tool() -> void:
	if _builder:
		if _builder.get_input_mode() == "demolition": _builder.set_demolition_active(false)
		else: _builder.cancel_placement()
	_dock.show_idle()
	if _town_hall_required():
		call_deferred("_ensure_forced_town_hall")

func _on_placement_context(context: Dictionary) -> void:
	var mode := String(context.get("mode", "world"))
	if mode == "demolition": _dock.show_demolition()
	elif bool(context.get("active", false)): _dock.show_placement(_selected_entry_id, String(context.get("reason", "")), int(context.get("rotation", 0)), context.get("community_preview", {}))
	elif mode != "radial": _dock.show_idle()

func _town_hall_required() -> bool:
	if GameState.map == null or not bool(GameState.map.rooted_town_rules):
		return false
	var road_network = PluginManager.get_plugin("RoadNetwork")
	return road_network != null and int(road_network.get_town_hall_internal_id()) < 0

func _ensure_forced_town_hall() -> void:
	if not _town_hall_required() or _builder == null or _palette == null:
		return
	if _builder.is_placement_active() and _selected_entry_id == "building_town_hall":
		return
	if _radial and _radial.visible:
		_radial.close_menu()
	var result: Dictionary = _palette.request_select_entry("building_town_hall")
	if not bool(result.get("accepted", false)):
		return
	_selected_entry_id = "building_town_hall"
	if _builder.begin_placement_from_palette():
		_dock.show_placement(_selected_entry_id, "Place this first to found your town")

func _open_insights() -> void:
	if _radial and _radial.visible: _radial.close_menu()
	var dashboard = _deps.get("Dashboard")
	if dashboard and dashboard.has_method("open_community"): dashboard.open_community()

func _open_inbox() -> void:
	var inbox = _deps.get("Inbox")
	if inbox and inbox.has_method("toggle_from_shell"): inbox.toggle_from_shell()

func _on_viewport_size_changed() -> void:
	if _status: _status.apply_compact_layout(get_viewport().get_visible_rect().size.x)
