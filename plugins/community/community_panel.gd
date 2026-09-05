extends VBoxContainer
class_name CommunityPanel

const PAGE_SIZE := 16
const SECTIONS := ["overview", "residents", "places"]

var _community: PluginBase
var _model: Dictionary = {}
var _previous_model: Dictionary = {}
var _section := "overview"
var _selected_resident_id := 0
var _selected_place_key := ""
var _resident_page := 0
var _search_text := ""
var _home_filter := "all"
var _risk_filter := "all"
var _outlook_filter := "all"
var _quality_filter := "all"
var _refresh_queued := false
var _notification_queue: Array = []
var _notifications: Array = []
var _inspect_active := false

var _notification_label: Button
var _notification_target_id := 0
var _section_buttons: Dictionary = {}
var _scroll: ScrollContainer
var _content: VBoxContainer

func setup(community: PluginBase) -> void:
	_community = community
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	_build_shell()
	_wire_events()
	if GameState.map:
		_section = String(GameState.map.community_section)
		if _section not in SECTIONS: _section = "overview"
	queue_refresh("setup")

func _build_shell() -> void:
	_notification_label = CommunityUIFactory.button("", "Open the resident connected to this Community event")
	_notification_label.add_theme_color_override("font_color", CommunityUIFactory.MUSTARD)
	_notification_label.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_notification_label.pressed.connect(_open_notification_target)
	_notification_label.visible = false
	add_child(_notification_label)
	var navigation := HBoxContainer.new()
	for section in SECTIONS:
		var button := CommunityUIFactory.button(section.capitalize(), "Open Community %s" % section)
		button.toggle_mode = true
		button.pressed.connect(func(): show_section(section))
		navigation.add_child(button)
		_section_buttons[section] = button
	add_child(navigation)
	_scroll = ScrollContainer.new()
	_scroll.name = "CommunityScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	add_child(_scroll)
	_content = VBoxContainer.new()
	_content.name = "CommunityContent"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	_scroll.add_child(_content)

func _wire_events() -> void:
	GameEvents.community_ui_refresh_requested.connect(func(reason): queue_refresh(reason))
	GameEvents.structure_placed.connect(func(_p, _s, _o): queue_refresh("placed"))
	GameEvents.structure_demolished.connect(_on_structure_demolished)
	GameEvents.community_programme_changed.connect(func(_a, _p): queue_refresh("programme"))
	GameEvents.map_loaded.connect(func(_m): _load_preferences(); queue_refresh("map"))
	GameEvents.community_place_selected.connect(_on_place_selected)
	GameEvents.community_notification.connect(_on_notification)

func queue_refresh(_reason: String = "") -> void:
	if _refresh_queued: return
	_refresh_queued = true
	call_deferred("_perform_refresh")

func _perform_refresh() -> void:
	_refresh_queued = false
	if _community == null or not _community.has_method("get_ui_model"): return
	_previous_model = _model
	_model = _community.get_ui_model(_previous_model)
	if _selected_resident_id > 0 and get_resident(_selected_resident_id).is_empty():
		_selected_resident_id = 0
	if not _selected_place_key.is_empty() and not _model.get("places", {}).has(_selected_place_key):
		_selected_place_key = ""
	_render()

func show_section(section: String) -> void:
	if section not in SECTIONS: return
	_section = section
	if GameState.map: GameState.map.community_section = section
	_render()
	var button: Button = _section_buttons.get(section)
	if button: button.grab_focus()

func _render() -> void:
	if _content == null: return
	CommunityUIFactory.clear(_content)
	for key in _section_buttons: (_section_buttons[key] as Button).button_pressed = key == _section
	match _section:
		"residents": _render_residents()
		"places": _render_places()
		_: _render_overview()

func _render_overview() -> void:
	var overview: Dictionary = _model.get("overview", {})
	var empty: Variant = overview.get("empty_state")
	if empty is Dictionary:
		var empty_card := CommunityUIFactory.card(empty["title"], "community")
		empty_card["content"].add_child(CommunityUIFactory.label(empty["body"]))
		empty_card["content"].add_child(CommunityUIFactory.label(empty["action_hint"], 12, CommunityUIFactory.MUSTARD))
		_content.add_child(empty_card["root"])
	_add_card("Housing", "housing-capacity", [
		"%d occupied places · %d free places · %d total" % [int(overview.get("occupied_homes", 0)), int(overview.get("free_homes", 0)), int(overview.get("capacity", 0))],
		"%.0f%% occupied · %d without homes" % [float(overview.get("occupancy_percent", 0.0)), int(overview.get("homeless_count", 0))],
		_housing_build_status(overview),
	])
	var qualities := CommunityUIFactory.card("Four qualities", "composite-happiness")
	for quality in overview.get("qualities", []):
		var direction := String(quality.get("direction", "unknown"))
		var symbol: String = {"rising": "↑", "falling": "↓", "stable": "→", "unknown": "·"}.get(direction, "·")
		var text := "%s  %.1f  %s %s" % [quality["label"], float(quality["current"]), symbol, direction]
		qualities["content"].add_child(CommunityUIFactory.icon_label(quality["icon_key"], text))
	_content.add_child(qualities["root"])
	var migration: Dictionary = overview.get("migration", {})
	var latest_event := String(migration.get("latest_event", ""))
	if latest_event.is_empty(): latest_event = "No migration check has happened yet"
	elif int(overview.get("free_homes", 0)) > 0 and latest_event.contains("no free housing"):
		latest_event = "Earlier result (housing is available now): " + latest_event
	else:
		latest_event = "Latest daily check: " + latest_event
	_add_card("Migration", "arrival", ["Arrivals %d · Departures %d" % [int(migration.get("arrivals", 0)), int(migration.get("departures", 0))], "Rejected %d · Net %+.0f" % [int(migration.get("rejections", 0)), float(migration.get("net", 0))], latest_event, "%d housing places are free right now" % int(overview.get("free_homes", 0))])
	var composition := CommunityUIFactory.card("Composition", "community")
	if overview.get("composition", {}).get("empty", true):
		composition["content"].add_child(CommunityUIFactory.label("No residents to describe yet."))
	else:
		for row in overview["composition"]["outlooks"]:
			composition["content"].add_child(CommunityUIFactory.label("%s  %d (%.0f%%)" % [row["label"], int(row["count"]), float(row["proportion"]) * 100.0]))
		for row in overview["composition"]["dominant_lenses"]:
			composition["content"].add_child(CommunityUIFactory.label("%s emphasis  %d" % [row["label"], int(row["count"])]))
	_content.add_child(composition["root"])
	var drivers := CommunityUIFactory.card("What is shaping happiness?", "positive-effect")
	drivers["content"].add_child(CommunityUIFactory.label("Largest active effects, totalled across the residents they currently reach.", 12, CommunityUIFactory.TAUPE))
	_render_driver_rows(drivers["content"], overview.get("positive_drivers", []), true)
	_render_driver_rows(drivers["content"], overview.get("negative_drivers", []), false)
	_content.add_child(drivers["root"])
	var warnings: Array = overview.get("warnings", [])
	if not warnings.is_empty():
		var card := CommunityUIFactory.card("Warnings", "warning")
		for warning in warnings: card["content"].add_child(CommunityUIFactory.icon_label("warning", "WARNING · " + String(warning["message"])))
		_content.add_child(card["root"])

func _render_driver_rows(parent: VBoxContainer, rows: Array, positive: bool) -> void:
	if rows.is_empty():
		parent.add_child(CommunityUIFactory.label(("+ Positive" if positive else "− Negative") + ": none active", 12, CommunityUIFactory.TAUPE))
		return
	for row in rows.slice(0, 3):
		parent.add_child(CommunityUIFactory.icon_label("positive-effect" if positive else "negative-effect", "%s %s · %s · total across %d resident%s" % [CommunityUIFactory.signed_amount(float(row["amount"])), String(row.get("quality", "effect")).capitalize(), row["source_display_name"], int(row["residents"]), "" if int(row["residents"]) == 1 else "s"]))

func _housing_build_status(overview: Dictionary) -> String:
	var free_places := int(overview.get("free_homes", 0))
	if free_places > 0:
		return "Current: arrivals have room; an earlier rejection may no longer apply"
	var capacity := int(overview.get("capacity", 0))
	var demand = PluginManager.get_plugin("Demand")
	var snapshot: Dictionary = demand.get_bucket_snapshot("residential") if demand and demand.has_method("get_bucket_snapshot") else {}
	var available := int(floor(float(snapshot.get("unserved", 0.0))))
	var next_cost := int(demand.ref_cost_housing) if demand else 5
	if available >= next_cost:
		if capacity <= 0:
			return "Current: no homes yet; you can build a House now"
		return "Current: town is full; you can build another House now"
	if capacity <= 0:
		return "Current: no homes yet; Homes demand %d/%d toward the first House" % [available, next_cost]
	return "Current: town is full; Homes demand %d/%d toward the next House" % [available, next_cost]

func _add_card(title: String, icon_slug: String, lines: Array) -> void:
	var card := CommunityUIFactory.card(title, icon_slug)
	for line in lines: card["content"].add_child(CommunityUIFactory.label(String(line)))
	_content.add_child(card["root"])

func _render_residents() -> void:
	if _selected_resident_id > 0:
		_render_resident_detail(get_resident(_selected_resident_id))
		return
	var search := LineEdit.new(); search.placeholder_text = "Search Resident #"; search.text = _search_text; search.focus_mode = Control.FOCUS_ALL
	search.text_changed.connect(func(value): _search_text = value; _resident_page = 0; _render())
	_content.add_child(search)
	var filters := HBoxContainer.new()
	filters.add_child(_filter_option("Home", ["all", "housed", "homeless"], _home_filter, func(v): _home_filter = v))
	filters.add_child(_filter_option("Risk", ["all", "stable", "at_risk", "homeless"], _risk_filter, func(v): _risk_filter = v))
	_content.add_child(filters)
	var personality_filters := HBoxContainer.new()
	personality_filters.add_child(_filter_option("Outlook", ["all", "identity", "freedom", "care"], _outlook_filter, func(v): _outlook_filter = v))
	personality_filters.add_child(_filter_option("Weakest", ["all", "opportunity", "liveability", "beauty", "belonging"], _quality_filter, func(v): _quality_filter = v))
	_content.add_child(personality_filters)
	var residents := filtered_residents()
	if residents.is_empty():
		_add_card("No matching residents", "search", ["Clear or change filters to see residents."])
		return
	var start := _resident_page * PAGE_SIZE; var page: Array = residents.slice(start, mini(start + PAGE_SIZE, residents.size()))
	for resident in page:
		var risk: String = resident["retention"]["state"]
		var button := CommunityUIFactory.button("%s  ·  %.1f happiness  ·  %s  ·  %s" % [resident["label"], float(resident["composite_happiness"]), resident["dominant_lens_label"], risk.replace("_", " ").capitalize()])
		button.icon = load(CommunityUIFactory.ICON_ROOT + ("at-risk" if risk != "stable" else "resident") + ".png")
		button.expand_icon = true; button.custom_minimum_size.y = 34
		button.pressed.connect(func(): _selected_resident_id = int(resident["resident_id"]); _render())
		_content.add_child(button)
	var pager := HBoxContainer.new(); var previous := CommunityUIFactory.button("← Previous"); var next := CommunityUIFactory.button("Next →")
	previous.disabled = _resident_page <= 0; next.disabled = start + PAGE_SIZE >= residents.size()
	previous.pressed.connect(func(): _resident_page -= 1; _render()); next.pressed.connect(func(): _resident_page += 1; _render())
	pager.add_child(previous); pager.add_child(CommunityUIFactory.label("Page %d of %d · %d residents" % [_resident_page + 1, ceili(float(residents.size()) / PAGE_SIZE), residents.size()])); pager.add_child(next); _content.add_child(pager)
	if bool(_model.get("resident_capped", false)): _content.add_child(CommunityUIFactory.icon_label("information", "Resident results capped at the authoritative snapshot limit."))

func _filter_option(label_text: String, values: Array, selected: String, changed: Callable) -> OptionButton:
	var option := OptionButton.new(); option.tooltip_text = label_text + " filter"; option.focus_mode = Control.FOCUS_ALL
	for value in values: option.add_item((label_text + ": " if value == "all" else "") + String(value).replace("_", " ").capitalize()); option.set_item_metadata(option.item_count - 1, value)
	for index in option.item_count:
		if String(option.get_item_metadata(index)) == selected: option.select(index)
	option.item_selected.connect(func(index): changed.call(String(option.get_item_metadata(index))); _resident_page = 0; _render())
	return option

func filtered_residents() -> Array:
	var result: Array = []
	for resident in _model.get("residents", []):
		if not _search_text.is_empty() and not String(resident["label"]).to_lower().contains(_search_text.to_lower()): continue
		if _home_filter == "housed" and resident["is_homeless"]: continue
		if _home_filter == "homeless" and not resident["is_homeless"]: continue
		if _risk_filter != "all" and resident["retention"]["state"] != _risk_filter: continue
		if _outlook_filter != "all" and resident["dominant_lens"] != _outlook_filter: continue
		if _quality_filter != "all" and _lowest_quality(resident) != _quality_filter: continue
		result.append(resident)
	return result

func _render_resident_detail(resident: Dictionary) -> void:
	if resident.is_empty(): _selected_resident_id = 0; _render(); return
	var back := CommunityUIFactory.button("← Residents"); back.pressed.connect(func(): _selected_resident_id = 0; _render()); _content.add_child(back)
	_add_card(resident["label"], "resident", ["%.1f composite happiness" % float(resident["composite_happiness"]), "%s · %s emphasis" % [resident["outlook_label"], resident["dominant_lens_label"]], resident["home_label"], _activity_text(resident["activity"])])
	var qualities := CommunityUIFactory.card("Current and target qualities", "composite-happiness")
	for quality in resident["qualities"]: qualities["content"].add_child(CommunityUIFactory.icon_label(quality["icon_key"], "%s  %.1f → %.1f" % [quality["label"], float(quality["current"]), float(quality["target"])]))
	_content.add_child(qualities["root"])
	var personality := CommunityUIFactory.card("Personality", "rooted-identity")
	for quality in CommunityConstants.QUALITIES:
		var weights: Dictionary = resident["lens_weights_by_quality"].get(quality, {})
		personality["content"].add_child(CommunityUIFactory.label("%s · Rooted %.0f%% · Independent %.0f%% · Civic %.0f%%" % [quality.capitalize(), float(weights.get("identity", 0.0)) * 100.0, float(weights.get("freedom", 0.0)) * 100.0, float(weights.get("care", 0.0)) * 100.0]))
	_content.add_child(personality["root"])
	var sensitivity := CommunityUIFactory.card("Sensitivities", "noise-sensitivity")
	for row in resident["sensitivities"]: sensitivity["content"].add_child(CommunityUIFactory.icon_label(row["icon_key"], "%s ×%.2f" % [row["label"], float(row["value"])]))
	_content.add_child(sensitivity["root"])
	var retention: Dictionary = resident["retention"]
	var remaining := int(retention["hours_remaining"])
	_add_card("Retention", "at-risk" if retention["state"] != "stable" else "grace-period-timer", [String(retention["message"]), "%d hour%s remaining" % [remaining, "" if remaining == 1 else "s"]])
	_render_effect_section("Positive effects", "positive-effect", resident["positive_effects"])
	_render_effect_section("Negative effects", "negative-effect", resident["negative_effects"])

func _render_effect_section(title: String, icon_slug: String, effects: Array) -> void:
	var card := CommunityUIFactory.card(title, icon_slug)
	if effects.is_empty(): card["content"].add_child(CommunityUIFactory.label("None active", 12, CommunityUIFactory.TAUPE))
	for effect in effects:
		var status := "ACTIVE" if effect["active_now"] else "INACTIVE"
		card["content"].add_child(CommunityUIFactory.icon_label(icon_slug, "%s %s · %s\n%s · %s · %s · %s · %s" % [CommunityUIFactory.signed_amount(float(effect["applied_amount"])), effect["quality_label"], effect["reason"], effect["source_display_name"], effect["manifestation_label"], effect["scope_label"], effect["schedule_label"], status]))
	_content.add_child(card["root"])

func _render_places() -> void:
	if not _selected_place_key.is_empty(): _render_place_detail(_model.get("places", {}).get(_selected_place_key, {})); return
	var controls := HBoxContainer.new(); var inspect := CommunityUIFactory.button("Stop inspect" if _inspect_active else "Inspect map"); inspect.toggle_mode = true; inspect.button_pressed = _inspect_active
	inspect.pressed.connect(func(): _inspect_active = inspect.button_pressed; GameEvents.community_inspect_mode_changed.emit(_inspect_active)); controls.add_child(inspect)
	var overlay := OptionButton.new(); overlay.focus_mode = Control.FOCUS_ALL
	for mode in ["off", "opportunity", "liveability", "beauty", "belonging", "identity", "freedom", "care"]: overlay.add_item("Overlay: " + String(mode).capitalize()); overlay.set_item_metadata(overlay.item_count - 1, mode)
	var saved_mode := String(GameState.map.community_overlay_mode) if GameState.map else "off"
	for index in overlay.item_count:
		if overlay.get_item_metadata(index) == saved_mode: overlay.select(index)
	overlay.item_selected.connect(func(index): var mode: String = overlay.get_item_metadata(index); if GameState.map: GameState.map.community_overlay_mode = mode; GameEvents.community_ui_refresh_requested.emit("overlay"))
	controls.add_child(overlay); _content.add_child(controls)
	if _model.get("places", {}).is_empty(): _add_card("No Community places", "place-inspection", ["Build a home, amenity or source of local effects, then inspect it here."]); return
	var keys: Array = _model["places"].keys(); keys.sort_custom(_place_key_before)
	for key in keys:
		var place: Dictionary = _model["places"][key]; var state := "ACTIVE" if place["active"] else "INACTIVE"
		var button := CommunityUIFactory.button("%s %s · %s · %d affected" % [state, place["display_name"], CommunityUIFactory.anchor_label(place["anchor"]), place["affected_resident_ids"].size()])
		button.pressed.connect(func(): _selected_place_key = key; _render()); _content.add_child(button)

func _render_place_detail(place: Dictionary) -> void:
	if place.is_empty(): _selected_place_key = ""; _render(); return
	var back := CommunityUIFactory.button("← Places"); back.pressed.connect(func(): _selected_place_key = ""; _render()); _content.add_child(back)
	var operation_line := "Operation data unavailable"
	if not place.get("operation", {}).is_empty():
		var access := "ROAD ACCESS" if bool(place.get("road_accessible", false)) else "NO ROAD ACCESS"
		var state := "OPERATING" if bool(place.get("operating", false)) else "IDLE"
		operation_line = "%s · %s · %d fulfilled" % [access, state, int(place.get("fulfilled", 0))]
		if not String(place.get("operation_reason", "")).is_empty(): operation_line += " · " + String(place["operation_reason"]).replace("_", " ")
	_add_card(place["display_name"], "place-inspection", [CommunityUIFactory.anchor_label(place["anchor"]), ("ACTIVE" if place["active"] else "INACTIVE") + " · " + place["active_schedule_label"], operation_line, "Reach: %s · participant capacity: %s" % [str(place["radii"]), str(place["capacities"])], "%d housed · %d participating · %d affected" % [place["housed_resident_ids"].size(), place["participating_resident_ids"].size(), place["affected_resident_ids"].size()]])
	if not place["available_programmes"].is_empty():
		var programme := CommunityUIFactory.card("Programme", "programme"); var options := OptionButton.new(); options.focus_mode = Control.FOCUS_ALL
		for option in place["available_programmes"]: options.add_item(option["label"]); options.set_item_metadata(options.item_count - 1, option["programme_id"]); if option["programme_id"] == place["current_programme"]: options.select(options.item_count - 1)
		options.item_selected.connect(func(index): _request_programme(place["anchor"], String(options.get_item_metadata(index))))
		programme["content"].add_child(options); programme["content"].add_child(CommunityUIFactory.label("Preview: authored themes and schedules; resident outcomes are evaluated by Community.", 12, CommunityUIFactory.TEAL)); _content.add_child(programme["root"])
	_render_effect_section("Positive contribution", "positive-effect", place["positive_effects"])
	_render_effect_section("Negative contribution", "negative-effect", place["negative_effects"])
	_render_effect_section("Authored effects and schedules", "active-schedule", place.get("authored_effects", []))
	var key := CommunityInspector._anchor_key(place["anchor"])
	var neighbourhood: Dictionary = _model.get("neighbourhoods", {}).get(key, {})
	if not neighbourhood.is_empty():
		var lines: Array = ["%d residents" % neighbourhood["resident_count"]]
		for quality in CommunityConstants.QUALITIES: lines.append("%s %.1f" % [quality.capitalize(), float(neighbourhood["average_qualities"][quality])])
		_add_card("Neighbourhood", "neighbourhood", lines)

func _request_programme(anchor: Variant, programme_id: String) -> void:
	var cell: Variant = CommunityConstants.coordinate(anchor)
	if cell == null: return
	var result: Dictionary = _community.request_programme_change(cell, programme_id)
	if not result.get("ok", false): _show_notification(String(result.get("reason", "Programme change failed")))

func get_resident(id: int) -> Dictionary:
	for resident in _model.get("residents", []):
		if int(resident["resident_id"]) == id: return resident
	return {}

func get_live_row_count() -> int:
	return mini(PAGE_SIZE, filtered_residents().size())

func _lowest_quality(resident: Dictionary) -> String:
	var lowest := "opportunity"
	for quality in resident.get("qualities", []):
		if float(quality["current"]) < float(resident["qualities"][CommunityConstants.QUALITIES.find(lowest)]["current"]): lowest = quality["quality_id"]
	return lowest

func _activity_text(activity: Variant) -> String:
	if not activity is Dictionary: return "No current activity"
	var programme := String(activity.get("programme", "")); return "Activity at %s%s" % [String(activity.get("building_id", "place")).replace("building_", "").replace("_", " ").capitalize(), " · " + programme.replace("_", " ").capitalize() if not programme.is_empty() else ""]

func _on_notification(kind: String, resident_id: int, message: String) -> void:
	_notification_queue.append({"kind": kind, "resident_id": resident_id, "message": message})
	if _notification_queue.size() == 1: call_deferred("_flush_notifications")

func _flush_notifications() -> void:
	var counts := {}; var latest := {}
	for item in _notification_queue: counts[item["kind"]] = int(counts.get(item["kind"], 0)) + 1; latest[item["kind"]] = item
	_notification_queue.clear()
	var parts: Array[String] = []
	for kind in counts:
		parts.append(String(latest[kind]["message"]) if counts[kind] == 1 else "%d %s events" % [counts[kind], String(kind)])
	var latest_item: Dictionary = latest.values().back() if not latest.is_empty() else {}
	_show_notification(" · ".join(parts), int(latest_item.get("resident_id", 0)))

func _show_notification(message: String, resident_id: int = 0) -> void:
	_notifications.append(message)
	if _notifications.size() > 8: _notifications.pop_front()
	_notification_target_id = resident_id
	_notification_label.text = message + ("  →" if resident_id > 0 else "")
	_notification_label.disabled = resident_id <= 0
	_notification_label.visible = true

func _open_notification_target() -> void:
	if _notification_target_id <= 0: return
	if get_resident(_notification_target_id).is_empty():
		_show_notification("That resident is no longer in the Community snapshot")
		return
	_selected_resident_id = _notification_target_id
	show_section("residents")

func _place_key_before(a: String, b: String) -> bool:
	var av := a.split(","); var bv := b.split(",")
	var ax := int(av[0]) if av.size() > 0 else 0; var az := int(av[1]) if av.size() > 1 else 0
	var bx := int(bv[0]) if bv.size() > 0 else 0; var bz := int(bv[1]) if bv.size() > 1 else 0
	if ax != bx: return ax < bx
	return az < bz

func _on_place_selected(anchor: Vector2i) -> void:
	var key := CommunityInspector._anchor_key(anchor)
	if _model.get("places", {}).has(key): _selected_place_key = key; show_section("places")
	else: _show_notification("No Community effect data for that place")

func _on_structure_demolished(position: Vector3i) -> void:
	if _selected_place_key == CommunityInspector._anchor_key(position): _selected_place_key = ""
	queue_refresh("demolished")

func _load_preferences() -> void:
	if not GameState.map: return
	_section = String(GameState.map.community_section)
	if _section not in SECTIONS: _section = "overview"

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.echo: return
	if event.keycode == KEY_ESCAPE:
		if _selected_resident_id > 0: _selected_resident_id = 0; _render(); get_viewport().set_input_as_handled()
		elif not _selected_place_key.is_empty(): _selected_place_key = ""; _render(); get_viewport().set_input_as_handled()
		elif _section != "overview": show_section("overview"); get_viewport().set_input_as_handled()
