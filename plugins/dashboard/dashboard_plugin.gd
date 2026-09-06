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

const CompactGuidanceViewCls := preload("res://plugins/dashboard/compact_guidance_view.gd")

var _performance_debug_logs := OS.get_environment("CITY_BUILDER_PERFORMANCE_DEBUG_LOGS") == "1"

func get_plugin_name() -> String: return "Dashboard"
func get_dependencies() -> Array[String]: return ["CharacterSystem", "PatronSystem", "Demand", "Community", "BuildingCatalog", "RoadNetwork", "OpeningTutorial", "PresentationScheduler", "ProjectionRegistry"]

const PANEL_WIDTH := 380
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
var _community:  PluginBase
var _road_network: PluginBase
var _opening_tutorial: PluginBase
var _presentation_scheduler: PluginBase
var _projection_registry: PluginBase
var _first_land_quest: Variant

# UI refs
var _canvas: CanvasLayer
var _panel:  PanelContainer
var _tab:    Button
var _cards_box: VBoxContainer
var _hint_label: Label
var _community_label: Label
var _patron_cards: Dictionary = {}  # patron_id -> _PatronCard
var _community_panel: CommunityPanel
var _community_overlay: CommunityMapOverlay
var _patrons_root: VBoxContainer
var _community_root: Control
var _top_tabs: Dictionary = {}
var _selected_top_tab := "community"
var _guidance_view: Control
var _player_input_mode := "world"

func inject(deps: Dictionary) -> void:
	_characters = deps.get("CharacterSystem")
	_patrons    = deps.get("PatronSystem")
	_demand     = deps.get("Demand")
	_community  = deps.get("Community")
	_catalog    = deps.get("BuildingCatalog")
	_road_network = deps.get("RoadNetwork")
	_opening_tutorial = deps.get("OpeningTutorial")
	_presentation_scheduler = deps.get("PresentationScheduler")
	_projection_registry = deps.get("ProjectionRegistry")

func _plugin_ready() -> void:
	# FirstLandQuest is an optional seam: resolve it when that feature plugin is
	# present without making older projects fail dependency injection.
	var manager := get_parent()
	if manager and manager.has_method("get_plugin"):
		_first_land_quest = manager.get_plugin("FirstLandQuest")
	_build_ui()
	_apply_collapsed_from_map()
	_wire_signals()
	if _presentation_scheduler:
		_presentation_scheduler.register_presenter(&"dashboard", [&"structures", &"topology", &"occupancy",
			&"resources", &"economy", &"demand", &"community", &"progression", &"presentation_config"],
			func(): return _panel != null and _panel.visible,
			func(_version, _domains): _refresh("committed", ""))
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
	_tab.focus_mode = Control.FOCUS_ALL
	_tab.tooltip_text = "Collapse or expand the Community and Patrons sidebar"
	_tab.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tab.offset_left   = -(PANEL_WIDTH + TAB_WIDTH)
	_tab.offset_right  = -PANEL_WIDTH
	_tab.offset_top    = 90
	_tab.offset_bottom = 140
	_tab.pressed.connect(_on_toggle_collapsed)
	_canvas.add_child(_tab)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left   = -PANEL_WIDTH
	_panel.offset_right  = 0
	_panel.offset_top    = 90
	# Reserve the bottom-right time controls. PlayerUI also reserves this
	# drawer's width for radial and dock placement while it is expanded.
	_panel.offset_bottom = -92
	_canvas.add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	_panel.add_child(outer)

	var title := Label.new()
	title.text = "Town insights"
	title.add_theme_font_size_override("font_size", 18)
	outer.add_child(title)
	var tab_row := HBoxContainer.new()
	for tab_name in ["community", "patrons"]:
		var button := Button.new()
		button.text = tab_name.capitalize()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.tooltip_text = "Open the %s tab" % tab_name.capitalize()
		button.icon = load("res://sprites/community_icons/game/%s-tab.png" % tab_name)
		button.expand_icon = true
		button.pressed.connect(func(): select_top_tab(tab_name))
		tab_row.add_child(button)
		_top_tabs[tab_name] = button
	outer.add_child(tab_row)

	_community_root = VBoxContainer.new()
	_community_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_community_root)
	_community_panel = CommunityPanel.new()
	_community_panel.setup(_community)
	_community_root.add_child(_community_panel)

	_patrons_root = VBoxContainer.new()
	_patrons_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_patrons_root)
	_community_label = Label.new()
	_community_label.text = "Community  0/0"
	_community_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_community_label.add_theme_color_override("font_color", Color(0.72, 0.92, 1.0))
	_patrons_root.add_child(_community_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_patrons_root.add_child(scroll)
	_cards_box = VBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 10)
	_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cards_box)
	_hint_label = Label.new()
	_hint_label.text = "Grow your town"
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
	_patrons_root.add_child(_hint_label)
	_build_patron_cards()

	_community_overlay = CommunityMapOverlay.new()
	_canvas.add_child(_community_overlay)
	_canvas.move_child(_community_overlay, 0)
	_guidance_view = CompactGuidanceViewCls.new()
	_canvas.add_child(_guidance_view)
	_guidance_view.build()
	_selected_top_tab = String(GameState.map.community_selected_tab) if GameState.map else "community"
	select_top_tab(_selected_top_tab)

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
	if not _presentation_scheduler:
		GameEvents.demand_unserved_changed.connect(func(_b, _v): _refresh("demand_unserved_changed", ""))
	GameEvents.map_loaded.connect(_on_map_loaded)
	if not _presentation_scheduler:
		GameEvents.community_population_changed.connect(func(_p, _c): _refresh("community_population", ""))
		GameEvents.community_qualities_changed.connect(func(_q): _refresh("community_qualities", ""))
	GameEvents.community_ui_requested.connect(open_community)
	if not _presentation_scheduler:
		GameEvents.community_ui_refresh_requested.connect(func(_r): _refresh_overlay())
	GameEvents.player_input_mode_changed.connect(_on_player_input_mode_changed)
	if not _presentation_scheduler:
		GameEvents.structure_placed.connect(func(_position, _index, _orientation): _refresh("structure_placed", ""))
	if _opening_tutorial and _opening_tutorial.has_signal("projection_changed"):
		_opening_tutorial.connect("projection_changed", func(_projection): _refresh("opening_tutorial", ""))
	_wire_optional_first_quest()

func _wire_optional_first_quest() -> void:
	if _first_land_quest and _first_land_quest.has_signal("projection_changed"):
		var callback := Callable(self, "_on_first_land_quest_projection_changed")
		if not _first_land_quest.is_connected("projection_changed", callback):
			_first_land_quest.connect("projection_changed", callback)

func _on_first_land_quest_projection_changed(_projection: Dictionary) -> void:
	_refresh("first_land_quest", "")

func _on_character_state_changed(cid: String, new_state: int) -> void:
	print("[Dashboard] refresh: trigger=character_state_changed id=%s new_state=%s"
		% [cid, STATE_NAME.get(new_state, str(new_state))])
	_refresh("character_state_changed", cid)

func _on_map_loaded(_m: DataMap) -> void:
	_apply_collapsed_from_map()
	select_top_tab(String(GameState.map.community_selected_tab) if GameState.map else "community")
	_refresh("map_loaded", "")

# ── Refresh loop ────────────────────────────────────────────────────────

func _refresh(_trigger: String, _subject: String) -> void:
	if _community_label and _community:
		var community_summary: Dictionary = _projection_registry.get_projection(&"community.operational") if _projection_registry else _community.get_operational_snapshot()
		_community_label.text = CommunityInspector.summary_text(community_summary)
	for pid in _patron_cards.keys():
		(_patron_cards[pid] as _PatronCard).update()
	var snap := snapshot()
	var hint := compute_hint(snap)
	_hint_label.text = hint
	if _guidance_view:
		_guidance_view.set_guidance(build_compact_guidance_model(snap))
	_refresh_overlay()
	if _performance_debug_logs: print("[Dashboard] hint: \"%s\"" % hint)

func select_top_tab(tab_name: String) -> void:
	_selected_top_tab = tab_name if tab_name in ["community", "patrons"] else "community"
	if _community_root: _community_root.visible = _selected_top_tab == "community"
	if _patrons_root: _patrons_root.visible = _selected_top_tab == "patrons"
	for key in _top_tabs: (_top_tabs[key] as Button).button_pressed = key == _selected_top_tab
	if GameState.map: GameState.map.community_selected_tab = _selected_top_tab

func open_community() -> void:
	set_collapsed(false)
	select_top_tab("community")
	if _top_tabs.has("community"): (_top_tabs["community"] as Button).grab_focus()

func _refresh_overlay() -> void:
	if _community_overlay == null or _community_panel == null: return
	var mode := String(GameState.map.community_overlay_mode) if GameState.map else "off"
	_community_overlay.set_projection(_community_panel._model, mode)

# ── Public helpers / snapshot for tests ─────────────────────────────────

class Snapshot:
	var patrons: Array = []     # Array[Dictionary] — per-patron summary
	var character_defs: Dictionary = {}  # cid → def dict
	var character_projections: Dictionary = {}
	var patron_projections: Dictionary = {}
	var first_arrived: String = ""
	var first_want_revealed: String = ""
	var first_landmark_available: String = ""
	var opening_projection: Dictionary = {}
	var first_quest_projection: Dictionary = {}
	var tutorial_handoff: Dictionary = {}
	var next_step: Dictionary = {}

func snapshot() -> Snapshot:
	var snap := Snapshot.new()
	if _opening_tutorial:
		if _opening_tutorial.has_method("get_projection"):
			snap.opening_projection = _opening_tutorial.get_projection().duplicate(true)
		if _opening_tutorial.has_method("get_state"):
			var tutorial_state: Dictionary = _opening_tutorial.get_state()
			snap.tutorial_handoff = tutorial_state.get("completion_handoff", {}).duplicate(true)
	if _first_land_quest and _first_land_quest.has_method("get_projection"):
		snap.first_quest_projection = _first_land_quest.get_projection().duplicate(true)
	for pid in _patrons.all_patron_ids():
		var pdef: Dictionary = _patrons.get_def(pid)
		var pstate: int = _patrons.get_state(pid)
		if _patrons.has_method("get_progression_snapshot"):
			snap.patron_projections[pid] = _patrons.get_progression_snapshot(pid).duplicate(true)
		var chars := []
		for cid in pdef.get("character_ids", []):
			var cdef: Dictionary = _characters.get_def(cid)
			var cstate: int = _characters.get_state(cid)
			if _characters.has_method("evaluate_character_gate"):
				snap.character_projections[cid] = _characters.evaluate_character_gate(cid).duplicate(true)
			chars.append({"cid": cid, "state": cstate, "def": cdef})
			snap.character_defs[cid] = cdef
		snap.patrons.append({"pid": pid, "state": pstate, "def": pdef, "characters": chars})
	var ordered_character_ids: Array = snap.character_projections.keys()
	ordered_character_ids.sort()
	for cid in ordered_character_ids:
		var state := int(snap.character_projections[cid].get("state", 0))
		if state == 1 and snap.first_arrived.is_empty(): snap.first_arrived = cid
		if state == 2 and snap.first_want_revealed.is_empty(): snap.first_want_revealed = cid
	var ordered_patron_ids: Array = snap.patron_projections.keys()
	ordered_patron_ids.sort()
	for pid in ordered_patron_ids:
		if int(snap.patron_projections[pid].get("state", 0)) == 1:
			snap.first_landmark_available = pid
			break
	snap.next_step = _next_step_for_snapshot(snap)
	return snap

## Priority: opening tutorial > first quest > talk > build > landmark > generic.
## Public + static-friendly so tests can drive it with a hand-built snapshot.
func compute_hint(snap: Snapshot) -> String:
	var step := snap.next_step if not snap.next_step.is_empty() else _next_step_for_snapshot(snap)
	match String(step.get("kind", "grow")):
		"opening_tutorial", "first_quest": return String(step.get("text", "Continue your opening."))
		"resolve_arrival": return "Talk to %s" % String(step.get("subject_label", "the new arrival"))
		"place_request": return "Build a %s" % String(step.get("subject_label", "requested building"))
		"place_landmark":
			var landmark_label := String(step.get("subject_label", "landmark"))
			return "Place %s" % landmark_label if landmark_label.to_lower().begins_with("the ") else "Place the %s" % landmark_label
		"fulfilled_demand": return "Grow %s: %d/%d fulfilled" % [String(step.get("bucket_label", "town")), int(step.get("current", 0)), int(step.get("required", 0))]
		"placed_tier": return "Place tier %d %s (current tier %d)" % [int(step.get("required", 0)), String(step.get("bucket_label", "town")), int(step.get("current", 0))]
		"complete": return "First patron complete"
	return "Grow your town"


## Presentation-only projection for the dismissible world HUD bubble. It owns no
## progression or placement behavior and never mutates the canonical next step.
func build_compact_guidance_model(snap: Snapshot) -> Dictionary:
	if _opening_tutorial and _opening_tutorial.has_method("is_complete") and not _opening_tutorial.is_complete():
		return _build_opening_tutorial_guidance(_opening_tutorial.get_projection())
	var step: Dictionary = (snap.next_step if not snap.next_step.is_empty() else _next_step_for_snapshot(snap)).duplicate(true)
	var kind := String(step.get("kind", "grow"))
	var candidate_id := "ambrose"
	var expression := "thoughtful"
	match kind:
		"resolve_arrival":
			candidate_id = String(step.get("owner_character_id", ""))
			expression = "concerned"
		"place_request":
			candidate_id = String(step.get("owner_character_id", ""))
			expression = "concerned"
		"place_landmark": candidate_id = "%s_patron" % String(step.get("owner_patron_id", ""))
		"complete": expression = "pleased"
		"first_quest": expression = "pleased"
	if candidate_id.is_empty() or not _has_approved_line_art(candidate_id, expression):
		candidate_id = "ambrose"
		expression = "pleased" if kind == "complete" else "thoughtful"

	var definition: Dictionary = _characters.get_def(candidate_id) if _characters else {}
	var speaker_name := String(definition.get("display_name", candidate_id))
	var subject_label := String(step.get("subject_label", ""))
	var owner_label := String(step.get("owner_character_label", ""))
	var text := ""
	match kind:
		"opening_tutorial", "first_quest": text = String(step.get("text", ""))
		"resolve_arrival":
			text = "Open the Inbox when you're ready to talk." if candidate_id != "ambrose" else "%s is waiting in your Inbox." % subject_label
		"place_request":
			text = "Place %s next." % subject_label if candidate_id != "ambrose" else "%s needs a %s. Place one next." % [owner_label, subject_label]
		"place_landmark": text = "Place %s next." % subject_label
		"place_foundation": text = "Place the Town Hall first to found your town."
		"fulfilled_demand": text = "Place %s until %d demand is fulfilled. You're at %d." % [String(step.get("bucket_label", "town")), int(step.get("required", 0)), int(step.get("current", 0))]
		"placed_tier": text = "Place a tier %d %s building next. The town is at tier %d." % [int(step.get("required", 0)), String(step.get("bucket_label", "town")), int(step.get("current", 0))]
		"complete": text = "The first patron is complete. Nicely done."
		_: text = "Keep growing the town. I'll let you know what we need next."

	var portrait := _resolve_guidance_portrait(candidate_id, expression)
	return {
		"kind":kind,
		"speaker_id":candidate_id,
		"speaker_name":speaker_name,
		"expression":portrait.get("expression", expression),
		"text":text,
		"portrait_path":portrait.get("path", ""),
		"portrait_source":portrait.get("source", "missing"),
		"target_id":step.get("subject_id", ""),
		"target_label":subject_label,
	}


func _build_opening_tutorial_guidance(projection: Dictionary) -> Dictionary:
	if projection.is_empty() or String(projection.get("status", "")) == "complete":
		return {}
	var expression := String(projection.get("expression", "thoughtful"))
	var definition: Dictionary = _characters.get_def("ambrose") if _characters else {}
	var portrait := _resolve_guidance_portrait("ambrose", expression)
	var target: Dictionary = projection.get("target", {}) if projection.get("target", {}) is Dictionary else {}
	return {
		"kind":"opening_tutorial",
		"speaker_id":"ambrose",
		"speaker_name":String(definition.get("display_name", "Ambrose")),
		"expression":portrait.get("expression", expression),
		"text":String(projection.get("text", "")),
		"portrait_path":portrait.get("path", ""),
		"portrait_source":portrait.get("source", "missing"),
		# CompactGuidanceView's dismissal key must change only for a semantic beat
		# or blocker variant, not for a numeric progress refresh.
		"target_id":String(projection.get("projection_key", projection.get("step_id", ""))),
		"target_label":String(target.get("label", "")),
		"tutorial_step_id":String(projection.get("step_id", "")),
		"beat_id":String(projection.get("beat_id", "")),
		"status":String(projection.get("status", "active")),
		"progress":projection.get("progress", {}).duplicate(true),
		"blocker":projection.get("blocker", null),
	}


func _has_approved_line_art(character_id: String, expression: String) -> bool:
	if _characters == null:
		return false
	var definition: Dictionary = _characters.get_def(character_id)
	var expressions: Dictionary = definition.get("expressions", {}) if definition.get("expressions", {}) is Dictionary else {}
	var path := String(expressions.get(expression, ""))
	return path.contains("/line_art/") and ResourceLoader.exists(path)


func _resolve_guidance_portrait(character_id: String, expression: String) -> Dictionary:
	var definition: Dictionary = _characters.get_def(character_id) if _characters else {}
	var expressions: Dictionary = definition.get("expressions", {}) if definition.get("expressions", {}) is Dictionary else {}
	var path := String(expressions.get(expression, ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		return {"path":path, "expression":expression, "source":"semantic_expression"}
	var fallback_expression := String(definition.get("default_expression", ""))
	path = String(expressions.get(fallback_expression, ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		return {"path":path, "expression":fallback_expression, "source":"default_expression"}
	path = String(definition.get("portrait", ""))
	return {"path":path, "expression":"", "source":"legacy_portrait"} if not path.is_empty() and ResourceLoader.exists(path) else {}


func _on_player_input_mode_changed(mode: String) -> void:
	_player_input_mode = mode
	if _guidance_view:
		_guidance_view.set_suppressed(mode in ["modal", "radial", "inspection"])

func _next_step_for_snapshot(snap: Snapshot) -> Dictionary:
	if not snap.opening_projection.is_empty() and String(snap.opening_projection.get("status", "active")) != "complete":
		return {
			"kind":"opening_tutorial", "subject_id":snap.opening_projection.get("projection_key", "opening_tutorial"),
			"subject_label":snap.opening_projection.get("target", {}).get("label", "") if snap.opening_projection.get("target", {}) is Dictionary else "",
			"text":snap.opening_projection.get("text", ""), "source":"opening_tutorial",
		}
	if not snap.first_quest_projection.is_empty() and String(snap.first_quest_projection.get("status", snap.first_quest_projection.get("phase", ""))).to_lower() in ["pending", "available", "active", "agreed"]:
		return {
			"kind":"first_quest", "subject_id":snap.first_quest_projection.get("quest_id", "first_land_quest"),
			"subject_label":snap.first_quest_projection.get("label", "First land quest"),
			"text":snap.first_quest_projection.get("direction", snap.first_quest_projection.get("text", "Continue to your first land quest.")),
			"source":"first_quest",
		}
	# The durable handoff is the fallback only until an owning quest plugin has
	# supplied an authoritative projection. In particular, a completed quest must
	# fall through to normal character/patron direction instead of being revived.
	if snap.first_quest_projection.is_empty() and bool(snap.tutorial_handoff.get("applied", false)):
		return {"kind":"first_quest", "subject_id":"first_land_quest", "subject_label":"First land quest",
			"text":"Continue to your first land quest.", "source":"first_quest"}
	if not snap.first_arrived.is_empty():
		var arrived: Dictionary = snap.character_projections.get(snap.first_arrived, {})
		return {"kind":"resolve_arrival", "subject_id":snap.first_arrived,
			"subject_label":arrived.get("display_name", _display_name_for(snap.character_defs.get(snap.first_arrived, {}), snap.first_arrived)),
			"owner_character_id":snap.first_arrived}
	if not snap.first_want_revealed.is_empty():
		var cid := snap.first_want_revealed
		var request: Dictionary = snap.character_projections.get(cid, {})
		var want_id := String(request.get("want_building_id", snap.character_defs.get(cid, {}).get("want_building_id", "")))
		return {"kind":"place_request", "subject_id":want_id,
			"subject_label":request.get("want_display_name", _building_display_name(want_id)),
			"owner_character_id":cid,
			"owner_character_label":request.get("display_name", _display_name_for(snap.character_defs.get(cid, {}), cid))}
	if not snap.first_landmark_available.is_empty():
		var pid := snap.first_landmark_available
		var patron: Dictionary = snap.patron_projections.get(pid, {})
		var landmark_id := String(patron.get("landmark_building_id", _patrons.get_def(pid).get("landmark_building_id", "")))
		return {"kind":"place_landmark", "subject_id":landmark_id,
			"subject_label":patron.get("landmark_display_name", _building_display_name(landmark_id)),
			"owner_patron_id":pid}
	var character_ids: Array = snap.character_projections.keys()
	character_ids.sort()
	for cid in character_ids:
		var gate: Dictionary = snap.character_projections[cid]
		if int(gate.get("state", 0)) != 0:
			continue
		if not gate.get("demand_met", false):
			return {"kind":"fulfilled_demand", "subject_id":cid,
				"bucket_label":gate.get("bucket_label", gate.get("bucket", "town")),
				"current":gate.get("fulfilled", 0), "required":gate.get("required_fulfilled", 0)}
		if not gate.get("tier_met", false):
			return {"kind":"placed_tier", "subject_id":cid,
				"bucket_label":gate.get("bucket_label", gate.get("bucket", "town")),
				"current":gate.get("attained_tier", 0), "required":gate.get("required_tier", 0),
				"tier_evidence":gate.get("tier_evidence", []).duplicate(true)}
	var patron_ids: Array = snap.patron_projections.keys()
	if not patron_ids.is_empty() and patron_ids.all(func(pid): return int(snap.patron_projections[pid].get("state", 0)) >= 2):
		return {"kind":"complete", "subject_id":"", "subject_label":"First patron complete"}
	return {"kind":"grow"}

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
		var patron_projection: Dictionary = plugin.call("get_patron_projection", pid)
		var pstate: int = int(patron_projection.get("state", plugin.call("get_patron_state", pid)))
		title_label.text = "%s — %s" % [
			String(pdef.get("display_name", pid)),
			plugin.call("building_name_for_patron", pid),
		]

		var satisfied := int(patron_projection.get("satisfied_count", 0))
		for cid in pdef.get("character_ids", []):
			var row: Dictionary = char_rows.get(cid, {})
			if row.is_empty(): continue
			var cstate: int = plugin.call("get_character_state", cid)
			var cdef: Dictionary = plugin.call("get_character_def", cid)
			(row["state"] as Label).text = String(STATE_ICON.get(cstate, "?"))
			(row["hint"] as Label).text = plugin.call("format_character_line", cid, cstate, cdef)
			if patron_projection.is_empty() and cstate >= 3:
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

func get_patron_projection(pid: String) -> Dictionary:
	return _patrons.get_progression_snapshot(pid) if _patrons.has_method("get_progression_snapshot") else {}

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
			if _characters.has_method("evaluate_character_gate"):
				var gate: Dictionary = _characters.evaluate_character_gate(cid)
				return "%s — %d/%d %s; tier %d/%d" % [name,
					int(gate.get("fulfilled", 0)), int(gate.get("required_fulfilled", 0)),
					String(gate.get("bucket_label", gate.get("bucket", "town"))),
					int(gate.get("attained_tier", 0)), int(gate.get("required_tier", 0))]
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
