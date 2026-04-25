extends PluginBase

## Quest-tracker sidebar (M6 / Phase 9).
##
## Right-anchored collapsible panel. One card per patron showing portrait,
## the three characters with state icons and per-character hints, landmark
## progress, and a single "next step" line at the bottom of the panel.
##
## Data-driven: the plugin pulls fresh state from CharacterSystem,
## PatronSystem, and Demand on every refresh. Subscribed signals:
## - character_state_changed, character_arrived/want_revealed/satisfied,
## - patron_state_changed, patron_landmark_ready, patron_landmark_completed,
## - demand_changed, map_loaded.
##
## Collapse state is saved per DataMap so the player's preferred layout sticks.

func get_plugin_name() -> String: return "Dashboard"
func get_dependencies() -> Array[String]: return ["CharacterSystem", "PatronSystem", "Demand"]

const PANEL_WIDTH := 320
const TAB_WIDTH := 28

const STATE_ICON := {
	0: "·",  # NOT_ARRIVED
	1: "!",  # ARRIVED
	2: "⚒",  # WANT_REVEALED
	3: "✓",  # SATISFIED
	4: "★",  # CONTRIBUTES_TO_LANDMARK
}
const STATE_NAME := {
	0: "NOT_ARRIVED",
	1: "ARRIVED",
	2: "WANT_REVEALED",
	3: "SATISFIED",
	4: "CONTRIBUTES_TO_LANDMARK",
}

var _characters: PluginBase
var _patrons:    PluginBase
var _demand:     PluginBase
var _catalog:    PluginBase

# UI refs
var _canvas: CanvasLayer
var _panel:  PanelContainer
var _tab:    Button
var _cards_box: VBoxContainer
var _hint_label: Label
var _patron_cards: Dictionary = {}  # patron_id -> _PatronCard

func inject(deps: Dictionary) -> void:
	_characters = deps.get("CharacterSystem")
	_patrons    = deps.get("PatronSystem")
	_demand     = deps.get("Demand")

func _plugin_ready() -> void:
	_catalog = PluginManager.get_plugin("BuildingCatalog")
	_build_ui()
	_apply_collapsed_from_map()
	_wire_signals()
	call_deferred("_refresh", "boot", "")
	print("[Dashboard] ready: patrons=%d" % (_patrons.all_patron_ids().size() if _patrons else 0))

# ── UI construction ─────────────────────────────────────────────────────

func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 5
	add_child(_canvas)

	# Collapse tab flush to the screen edge.
	_tab = Button.new()
	_tab.text = "◀"
	_tab.focus_mode = Control.FOCUS_NONE
	_tab.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tab.offset_left   = -(PANEL_WIDTH + TAB_WIDTH)
	_tab.offset_right  = -PANEL_WIDTH
	_tab.offset_top    = 60
	_tab.offset_bottom = 110
	_tab.pressed.connect(_on_toggle_collapsed)
	_canvas.add_child(_tab)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left   = -PANEL_WIDTH
	_panel.offset_right  = 0
	_panel.offset_top    = 60
	_panel.offset_bottom = -10
	_canvas.add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	_panel.add_child(outer)

	var title := Label.new()
	title.text = "Patrons"
	title.add_theme_font_size_override("font_size", 18)
	outer.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_cards_box = VBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 10)
	_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cards_box)

	_hint_label = Label.new()
	_hint_label.text = "Grow your town"
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
	outer.add_child(_hint_label)

	_build_patron_cards()

func _build_patron_cards() -> void:
	for pid in _patrons.all_patron_ids():
		var card := _PatronCard.new(pid, self)
		_patron_cards[pid] = card
		_cards_box.add_child(card.root)

# ── Signal wiring ───────────────────────────────────────────────────────

func _wire_signals() -> void:
	GameEvents.character_state_changed.connect(_on_character_state_changed)
	GameEvents.character_arrived.connect(func(cid): _refresh("character_arrived", cid))
	GameEvents.character_want_revealed.connect(func(cid): _refresh("character_want_revealed", cid))
	GameEvents.character_satisfied.connect(func(cid): _refresh("character_satisfied", cid))
	GameEvents.patron_landmark_ready.connect(func(pid): _refresh("patron_landmark_ready", pid))
	GameEvents.patron_landmark_completed.connect(func(pid): _refresh("patron_landmark_completed", pid))
	GameEvents.patron_state_changed.connect(func(pid, _s): _refresh("patron_state_changed", pid))
	GameEvents.demand_unserved_changed.connect(func(_b, _v): _refresh("demand_unserved_changed", ""))
	GameEvents.map_loaded.connect(_on_map_loaded)

func _on_character_state_changed(cid: String, new_state: int) -> void:
	print("[Dashboard] refresh: trigger=character_state_changed id=%s new_state=%s"
		% [cid, STATE_NAME.get(new_state, str(new_state))])
	_refresh("character_state_changed", cid)

func _on_map_loaded(_m: DataMap) -> void:
	_apply_collapsed_from_map()
	_refresh("map_loaded", "")

# ── Refresh loop ────────────────────────────────────────────────────────

func _refresh(_trigger: String, _subject: String) -> void:
	for pid in _patron_cards.keys():
		(_patron_cards[pid] as _PatronCard).update()
	var hint := compute_hint(snapshot())
	_hint_label.text = hint
	print("[Dashboard] hint: \"%s\"" % hint)

# ── Public helpers / snapshot for tests ─────────────────────────────────

class Snapshot:
	var patrons: Array = []     # Array[Dictionary] — per-patron summary
	var character_defs: Dictionary = {}  # cid → def dict
	var first_arrived: String = ""
	var first_want_revealed: String = ""
	var first_landmark_available: String = ""

func snapshot() -> Snapshot:
	var snap := Snapshot.new()
	for pid in _patrons.all_patron_ids():
		var pdef: Dictionary = _patrons.get_def(pid)
		var pstate: int = _patrons.get_state(pid)
		var chars := []
		for cid in pdef.get("character_ids", []):
			var cdef: Dictionary = _characters.get_def(cid)
			var cstate: int = _characters.get_state(cid)
			chars.append({"cid": cid, "state": cstate, "def": cdef})
			snap.character_defs[cid] = cdef
			if cstate == 1 and snap.first_arrived.is_empty():
				snap.first_arrived = cid
			elif cstate == 2 and snap.first_want_revealed.is_empty():
				snap.first_want_revealed = cid
		if pstate == 1 and snap.first_landmark_available.is_empty():
			snap.first_landmark_available = pid
		snap.patrons.append({"pid": pid, "state": pstate, "def": pdef, "characters": chars})
	return snap

## Priority: talk > build > landmark > generic.
## Public + static-friendly so tests can drive it with a hand-built snapshot.
func compute_hint(snap: Snapshot) -> String:
	if not snap.first_arrived.is_empty():
		var name := _display_name_for(snap.character_defs.get(snap.first_arrived, {}), snap.first_arrived)
		return "Talk to %s" % name
	if not snap.first_want_revealed.is_empty():
		var wc: Dictionary = snap.character_defs.get(snap.first_want_revealed, {})
		var want_id: String = String(wc.get("want_building_id", ""))
		var want_name := _building_display_name(want_id)
		if want_name.is_empty():
			want_name = "their want"
		return "Build a %s" % want_name
	if not snap.first_landmark_available.is_empty():
		var lid: String = String(_patrons.get_def(snap.first_landmark_available).get("landmark_building_id", ""))
		var lname := _building_display_name(lid)
		if lname.is_empty():
			lname = "landmark"
		return "Place the %s" % lname
	return "Grow your town"

func _building_display_name(bid: String) -> String:
	if bid.is_empty() or _catalog == null:
		return ""
	if _catalog.has_method("get_summary_by_id"):
		var s: Dictionary = _catalog.get_summary_by_id(bid)
		return String(s.get("display_name", ""))
	return ""

func _display_name_for(cdef: Dictionary, fallback: String) -> String:
	var n := String(cdef.get("display_name", ""))
	return n if not n.is_empty() else fallback

# ── Collapse toggle ─────────────────────────────────────────────────────

func _on_toggle_collapsed() -> void:
	var now := not _panel.visible
	set_collapsed(not now)  # not now == collapsed-after-toggle

func set_collapsed(value: bool) -> void:
	if _panel == null: return
	_panel.visible = not value
	_tab.text = "▶" if value else "◀"
	# Slide the tab to the window edge when collapsed so it stays reachable.
	if value:
		_tab.offset_left  = -TAB_WIDTH
		_tab.offset_right = 0
	else:
		_tab.offset_left  = -(PANEL_WIDTH + TAB_WIDTH)
		_tab.offset_right = -PANEL_WIDTH
	if GameState.map:
		GameState.map.dashboard_collapsed = value
	print("[Dashboard] collapsed: value=%s" % str(value))

func _apply_collapsed_from_map() -> void:
	if GameState.map:
		set_collapsed(bool(GameState.map.dashboard_collapsed))

# ── Per-patron card ─────────────────────────────────────────────────────

class _PatronCard:
	var pid: String
	var plugin: PluginBase
	var root: PanelContainer
	var title_label: Label
	var char_rows: Dictionary = {}  # cid → {state: Label, hint: Label}
	var landmark_label: Label

	func _init(patron_id: String, owner: PluginBase) -> void:
		pid = patron_id
		plugin = owner
		_build()
		update()

	func _build() -> void:
		root = PanelContainer.new()
		root.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		root.add_child(vbox)

		title_label = Label.new()
		title_label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(title_label)

		var pdef: Dictionary = plugin.call("get_patron_def", pid)
		for cid in pdef.get("character_ids", []):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			vbox.add_child(row)

			var state_lbl := Label.new()
			state_lbl.custom_minimum_size.x = 18
			row.add_child(state_lbl)

			var hint_lbl := Label.new()
			hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(hint_lbl)

			char_rows[cid] = {"state": state_lbl, "hint": hint_lbl}

		landmark_label = Label.new()
		landmark_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.88))
		vbox.add_child(landmark_label)

	func update() -> void:
		var pdef: Dictionary = plugin.call("get_patron_def", pid)
		var pstate: int = plugin.call("get_patron_state", pid)
		title_label.text = "%s — %s" % [
			String(pdef.get("display_name", pid)),
			plugin.call("building_name_for_patron", pid),
		]

		var satisfied := 0
		for cid in pdef.get("character_ids", []):
			var row: Dictionary = char_rows.get(cid, {})
			if row.is_empty(): continue
			var cstate: int = plugin.call("get_character_state", cid)
			var cdef: Dictionary = plugin.call("get_character_def", cid)
			(row["state"] as Label).text = String(STATE_ICON.get(cstate, "?"))
			(row["hint"] as Label).text = plugin.call("format_character_line", cid, cstate, cdef)
			if cstate >= 3:
				satisfied += 1

		var total := int(pdef.get("character_ids", []).size())
		match pstate:
			0:  # LOCKED
				landmark_label.text = "Landmark: locked (%d/%d)" % [satisfied, total]
			1:  # LANDMARK_AVAILABLE
				landmark_label.text = "Landmark: ready to build"
			2:  # COMPLETED
				landmark_label.text = "Landmark: ✓ built"

# ── Methods consumed by _PatronCard via call(). Kept in the outer plugin
# so the card stays thin and the logic is testable. ─────────────────────

func get_patron_def(pid: String) -> Dictionary:
	return _patrons.get_def(pid)

func get_patron_state(pid: String) -> int:
	return _patrons.get_state(pid)

func get_character_def(cid: String) -> Dictionary:
	return _characters.get_def(cid)

func get_character_state(cid: String) -> int:
	return _characters.get_state(cid)

func building_name_for_patron(pid: String) -> String:
	var pdef: Dictionary = _patrons.get_def(pid)
	var name := _building_display_name(String(pdef.get("landmark_building_id", "")))
	return name if not name.is_empty() else "?"

func format_character_line(cid: String, state: int, cdef: Dictionary) -> String:
	var name := _display_name_for(cdef, cid)
	match state:
		0:
			var bucket := String(cdef.get("associated_bucket", ""))
			var threshold := float(cdef.get("arrival_threshold", 0))
			return "%s — needs %d %s demand" % [name, int(threshold), bucket]
		1:
			return "%s — talk to them" % name
		2:
			var want := _building_display_name(String(cdef.get("want_building_id", "")))
			if want.is_empty():
				want = "their want"
			return "%s — build %s" % [name, want]
		3:
			return "%s — satisfied" % name
		4:
			return "%s — contributes" % name
		_:
			return name
