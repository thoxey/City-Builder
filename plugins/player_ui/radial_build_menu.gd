extends Control
class_name RadialBuildMenu

signal entry_requested(entry_id: String)
signal menu_closed

const MAX_WEDGES := 8
const INNER_RADIUS := 58.0
const OUTER_RADIUS := 154.0
const SAFE_MARGIN := 18.0
const STICK_DEAD_ZONE := 0.55
const WedgeCls := preload("res://plugins/player_ui/radial_wedge.gd")

var _model: Dictionary = {}
var _level := "categories"
var _group_id := ""
var _page_index := 0
var _focused_index := 0
var _hovered_index := -1
var _origin := Vector2.ZERO
var _safe_right_inset := 0.0
var _actions: Array[Dictionary] = []
var _wedges: Array[RadialWedge] = []
var _last_group := ""
var _last_entry_by_group: Dictionary = {}
var _detail_panel: PanelContainer
var _detail_label: Label
var _centre_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	visible = false
	for i in MAX_WEDGES:
		var wedge := WedgeCls.new()
		wedge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(wedge)
		_wedges.append(wedge)
	_centre_button = Button.new()
	_centre_button.custom_minimum_size = Vector2(92, 92)
	_centre_button.flat = true
	_centre_button.icon = load("res://sprites/ui/build-menu/controls/close.png")
	_centre_button.expand_icon = true
	_centre_button.tooltip_text = "Close build menu"
	_centre_button.pressed.connect(back_or_close)
	add_child(_centre_button)
	_detail_panel = PanelContainer.new()
	_detail_panel.theme_type_variation = "DetailCard"
	_detail_panel.custom_minimum_size = Vector2(260, 116)
	add_child(_detail_panel)
	_detail_label = Label.new()
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_font_override("font", load("res://fonts/lilita_one_regular.ttf"))
	_detail_label.add_theme_font_size_override("font_size", 16)
	_detail_panel.add_child(_detail_label)
	resized.connect(_relayout)

func set_model(model: Dictionary) -> void:
	_model = model.duplicate(true)
	if visible:
		_rebuild_actions()

func open_menu(preferred_origin: Vector2 = Vector2.INF) -> void:
	_level = "categories"
	_group_id = ""
	_page_index = 0
	_origin = size * 0.5 if not preferred_origin.is_finite() else preferred_origin
	_origin = clamp_origin(_origin, _safe_rect(), OUTER_RADIUS + 86.0, SAFE_MARGIN)
	visible = true
	grab_focus()
	_rebuild_actions()

func close_menu() -> void:
	if not visible: return
	visible = false
	menu_closed.emit()

func back_or_close() -> void:
	if _level == "items":
		_level = "categories"
		_group_id = ""
		_page_index = 0
		_rebuild_actions()
	else:
		close_menu()

func _rebuild_actions() -> void:
	_actions.clear()
	if _level == "categories":
		for group in _model.get("groups", []):
			var short_names := {"roads":"Roads", "homes":"Homes", "commerce":"Commerce", "industry":"Industry", "nature":"Nature", "civic":"Civic", "landmarks":"Landmarks"}
			_actions.append({"kind":"group", "target_id":group.id, "label":short_names.get(group.id, group.label),
				"icon_path":"res://sprites/ui/build-menu/categories/%s.png" % group.icon_key,
				"enabled":true, "accessible_description":"%s, %d choices" % [group.label, group.total_count]})
	else:
		var ids: Array = []
		for group in _model.get("groups", []):
			if group.id == _group_id: ids = group.entry_ids; break
		var pages := build_pages(ids)
		_page_index = clampi(_page_index, 0, maxi(0, pages.size() - 1))
		for page_action in (pages[_page_index] if not pages.is_empty() else []):
			if page_action.kind == "entry":
				var entry: Dictionary = _model.get("entries_by_id", {}).get(page_action.target_id, {})
				_actions.append({"kind":"entry", "target_id":entry.get("id", ""), "label":entry.get("short_label", ""),
					"icon_path":"res://sprites/ui/build-menu/entries/%s.png" % entry.get("icon_key", "missing-artwork"),
					"enabled":entry.get("can_select", false), "accessible_description":"%s. %s" % [entry.get("display_name", ""), entry.get("availability_label", "")]})
			else:
				var nav_icon := "next-page" if page_action.kind == "next_page" else "previous-page"
				_actions.append({"kind":page_action.kind, "target_id":"", "label":page_action.label,
					"icon_path":"res://sprites/ui/build-menu/controls/%s.png" % nav_icon, "enabled":true,
					"accessible_description":page_action.label})
	_focused_index = clampi(_focused_index, 0, maxi(0, _actions.size() - 1))
	_layout_wedges()
	_update_detail()

func _layout_wedges() -> void:
	var count := _actions.size()
	for i in MAX_WEDGES:
		if i >= count:
			_wedges[i].configure({}, _origin, 0, 0, INNER_RADIUS, OUTER_RADIUS)
			continue
		var span := TAU / float(count)
		var start := -PI * 0.5 - span * 0.5 + span * i
		_wedges[i].configure(_actions[i], _origin, start, start + span, INNER_RADIUS, OUTER_RADIUS)
		_wedges[i].set_states(i == _focused_index, i == _hovered_index)
	_centre_button.position = _origin - Vector2(46, 46)
	_centre_button.size = Vector2(92, 92)
	_centre_button.icon = load("res://sprites/ui/build-menu/controls/%s.png" % ("back" if _level == "items" else "close"))
	_centre_button.tooltip_text = "Back to categories" if _level == "items" else "Close build menu"
	var card_size := _detail_panel.custom_minimum_size
	var safe_right := size.x - SAFE_MARGIN - _safe_right_inset
	var desired_x := _origin.x + OUTER_RADIUS + 24.0
	if desired_x + card_size.x > safe_right:
		desired_x = _origin.x - OUTER_RADIUS - 24.0 - card_size.x
	var desired := Vector2(desired_x, _origin.y - 58.0)
	var max_position := size - _detail_panel.custom_minimum_size - Vector2(SAFE_MARGIN + _safe_right_inset, SAFE_MARGIN)
	_detail_panel.position = Vector2(clampf(desired.x, SAFE_MARGIN, max_position.x), clampf(desired.y, SAFE_MARGIN, max_position.y))
	_detail_panel.size = _detail_panel.custom_minimum_size

func _relayout() -> void:
	if not visible: return
	_origin = clamp_origin(_origin, _safe_rect(), OUTER_RADIUS + 86.0, SAFE_MARGIN)
	_layout_wedges()

func set_right_safe_inset(inset: float) -> void:
	_safe_right_inset = maxf(0.0, inset)
	_relayout()

func _safe_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(maxf(1.0, size.x - _safe_right_inset), size.y))

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseMotion:
		_hovered_index = wedge_index_for_point(event.position, _origin, INNER_RADIUS, OUTER_RADIUS, _actions.size())
		if _hovered_index >= 0: _set_focus(_hovered_index)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var idx := wedge_index_for_point(event.position, _origin, INNER_RADIUS, OUTER_RADIUS, _actions.size())
		if idx >= 0: _set_focus(idx); confirm_focused()
		else: back_or_close()
		accept_event()
	elif event.is_action_pressed("ui_cancel"):
		back_or_close(); accept_event()
	elif event.is_action_pressed("ui_accept"):
		confirm_focused(); accept_event()
	elif event.is_action_pressed("radial_next") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		move_focus(1); accept_event()
	elif event.is_action_pressed("radial_previous") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		move_focus(-1); accept_event()

func _process(_delta: float) -> void:
	if not visible: return
	var stick := Input.get_vector("radial_left", "radial_right", "radial_up", "radial_down")
	if stick.length() >= STICK_DEAD_ZONE:
		var idx := wedge_index_for_angle(stick.angle(), _actions.size())
		if idx >= 0: _set_focus(idx)

func move_focus(delta: int) -> void:
	if _actions.is_empty(): return
	_hovered_index = -1
	_set_focus(wrapi(_focused_index + delta, 0, _actions.size()))

func _set_focus(index: int) -> void:
	if index < 0 or index >= _actions.size(): return
	_focused_index = index
	for i in _wedges.size(): _wedges[i].set_states(i == _focused_index, i == _hovered_index)
	_update_detail()

func confirm_focused() -> void:
	if _actions.is_empty() or _focused_index >= _actions.size(): return
	var action := _actions[_focused_index]
	if action.kind == "entry" and not bool(action.get("enabled", false)):
		_update_detail()
		return
	match String(action.kind):
		"group":
			_group_id = action.target_id; _last_group = _group_id; _level = "items"; _page_index = 0; _focused_index = 0; _rebuild_actions()
		"entry":
			_last_entry_by_group[_group_id] = action.target_id
			entry_requested.emit(action.target_id)
		"next_page":
			_page_index += 1; _focused_index = 0; _rebuild_actions()
		"previous_page":
			_page_index -= 1; _focused_index = 0; _rebuild_actions()

func _update_detail() -> void:
	if _actions.is_empty():
		_detail_label.text = "No build choices"
		return
	var action := _actions[_focused_index]
	if action.kind != "entry":
		_detail_label.text = "%s\n%s" % [action.label, action.accessible_description]
		return
	var entry: Dictionary = _model.get("entries_by_id", {}).get(action.target_id, {})
	var cost_value: Variant = entry.get("cash_cost", 0)
	var cost_text := "£%d" % int(cost_value) if cost_value is int or cost_value is float else "£%d–£%d" % [int(cost_value.get("min", 0)), int(cost_value.get("max", 0))]
	var demand: Dictionary = entry.get("demand_cost", {})
	var demand_text := ""
	if not String(demand.get("bucket_id", "")).is_empty(): demand_text = "  •  %d %s demand" % [int(demand.get("cost", 0)), String(demand.get("bucket_id", ""))]
	_detail_label.text = "%s\n%s%s\n%s%s" % [entry.get("display_name", ""), cost_text, demand_text,
		"✓ " if entry.get("can_select", false) else "🔒 ", entry.get("availability_label", "")]

static func clamp_origin(origin: Vector2, safe_rect: Rect2, radius: float, margin: float = 0.0) -> Vector2:
	var inset := radius + margin
	return Vector2(clampf(origin.x, safe_rect.position.x + inset, safe_rect.end.x - inset),
		clampf(origin.y, safe_rect.position.y + inset, safe_rect.end.y - inset))

static func wedge_index_for_angle(angle: float, count: int) -> int:
	if count <= 0: return -1
	var span := TAU / float(count)
	var normalized := fposmod(angle + PI * 0.5 + span * 0.5, TAU)
	return mini(count - 1, int(floor(normalized / span)))

static func wedge_index_for_point(point: Vector2, origin: Vector2, inner: float, outer: float, count: int) -> int:
	var offset := point - origin
	if offset.length() < inner or offset.length() > outer: return -1
	return wedge_index_for_angle(offset.angle(), count)

static func build_pages(entry_ids: Array) -> Array:
	if entry_ids.is_empty(): return [[]]
	if entry_ids.size() <= MAX_WEDGES:
		return [entry_ids.map(func(id): return {"kind":"entry", "target_id":id, "label":""})]
	var pages: Array = []
	var cursor := 0
	while cursor < entry_ids.size():
		var has_previous := not pages.is_empty()
		var remaining := entry_ids.size() - cursor
		var capacity := MAX_WEDGES - (1 if has_previous else 0)
		var has_next := remaining > capacity
		if has_next: capacity -= 1
		var actions: Array = []
		if has_previous: actions.append({"kind":"previous_page", "target_id":"", "label":"Previous"})
		for id in entry_ids.slice(cursor, cursor + capacity): actions.append({"kind":"entry", "target_id":id, "label":""})
		cursor += capacity
		if cursor < entry_ids.size(): actions.append({"kind":"next_page", "target_id":"", "label":"Next"})
		pages.append(actions)
	return pages
