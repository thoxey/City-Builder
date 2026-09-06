extends PanelContainer
class_name PlayerStatusBar

signal insights_requested
signal inbox_requested

const FONT := preload("res://fonts/lilita_one_regular.ttf")
var _providers: Dictionary = {}
var _labels: Dictionary = {}
var _titles: Dictionary = {}
var _icons: Dictionary = {}
var _metrics: Dictionary = {}
var _demand_hover_projections: Dictionary = {}
var _elapsed := 0.0
var _compact := false
var _ui_scale := 1.0
var _insights_button: Button
var _inbox_button: Button

const METRICS := [
	["cash", "Cash", "Cash", "res://sprites/ui/status/cash-purse.png"],
	["budget", "Budget/hr", "Budget", "res://sprites/community_icons/game/increasing.png"],
	["output", "Industrial output per hour", "Output", "res://sprites/community_icons/game/current-activity.png"],
	["attractiveness", "Attractiveness", "Attract.", "res://sprites/community_icons/game/beauty.png"],
	["residential", "Homes demand", "Homes", "res://sprites/community_icons/game/housing-capacity.png"],
	["industrial", "Work demand", "Work", "res://sprites/ui/build-menu/categories/industry.png"],
	["commercial", "Shop demand", "Shops", "res://sprites/ui/build-menu/categories/commerce.png"],
	["population", "Population", "Pop.", "res://sprites/community_icons/game/population.png"],
	["community", "Community happiness", "Community", "res://sprites/community_icons/game/community.png"],
]

func setup(providers: Dictionary) -> void:
	_providers = providers
	name = "PlayerStatusBar"
	theme_type_variation = "StatusBar"
	anchor_left = 0.02
	anchor_top = 0.0
	anchor_right = 0.98
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 10.0
	offset_bottom = 118.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_%s" % side, 16)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_%s" % side, 10)
	add_child(margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)
	for item in METRICS:
		row.add_child(_metric(String(item[0]), String(item[1]), String(item[2]), String(item[3])))
	_insights_button = Button.new()
	_insights_button.text = ""
	_insights_button.icon = load("res://sprites/community_icons/game/information.png")
	_insights_button.flat = true
	_insights_button.expand_icon = true
	_insights_button.add_theme_constant_override("icon_max_width", 48)
	_insights_button.custom_minimum_size = Vector2(68, 68)
	_insights_button.tooltip_text = "Open Town Insights"
	_insights_button.pressed.connect(func(): insights_requested.emit())
	row.add_child(_insights_button)
	_inbox_button = Button.new()
	_inbox_button.text = ""
	_inbox_button.icon = load("res://sprites/community_icons/game/programme.png")
	_inbox_button.flat = true
	_inbox_button.expand_icon = true
	_inbox_button.add_theme_constant_override("icon_max_width", 48)
	_inbox_button.custom_minimum_size = Vector2(68, 68)
	_inbox_button.tooltip_text = "Open Inbox"
	_inbox_button.pressed.connect(func(): inbox_requested.emit())
	row.add_child(_inbox_button)
	refresh()

func _metric(key: String, title_text: String, compact_title: String, icon_path: String) -> VBoxContainer:
	var metric := VBoxContainer.new()
	metric.name = key.capitalize()
	metric.alignment = BoxContainer.ALIGNMENT_CENTER
	metric.add_theme_constant_override("separation", 0)
	metric.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metric.custom_minimum_size = Vector2(86, 68)
	metric.tooltip_text = title_text
	var title := Label.new()
	title.text = title_text
	title.visible = false
	title.set_meta("full_title", title_text)
	title.set_meta("compact_title", compact_title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 14)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	metric.add_child(title)
	var value_row := HBoxContainer.new()
	value_row.alignment = BoxContainer.ALIGNMENT_CENTER
	value_row.add_theme_constant_override("separation", 2)
	metric.add_child(value_row)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = load(icon_path)
	icon.custom_minimum_size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_row.add_child(icon)
	var value := Label.new()
	value.name = "Value"
	value.text = "—"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_override("font", FONT)
	value.add_theme_font_size_override("font_size", 32)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_row.add_child(value)
	_titles[key] = title
	_icons[key] = icon
	_labels[key] = value
	_metrics[key] = metric
	return metric

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.25:
		_elapsed = 0.0
		refresh()

func refresh() -> void:
	if _labels.is_empty() or not is_instance_valid(_inbox_button): return
	var economy = _providers.get("Economy")
	var workplace = _providers.get("Workplace")
	var attractiveness = _providers.get("Attractiveness")
	var demand = _providers.get("Demand")
	var community = _providers.get("Community")
	var inbox = _providers.get("Inbox")
	_labels.cash.text = "£%d" % (GameState.map.cash if GameState.map else 0)
	_labels.budget.text = "£%d/hr" % (economy.get_last_hourly_income() if economy else 0)
	_labels.output.text = "%d/hr" % (workplace.get_total_output() if workplace else 0)
	_labels.attractiveness.text = "%d" % (attractiveness.city_score() if attractiveness else 0)
	for bucket_id in ["residential", "industrial", "commercial"]:
		var snap: Dictionary = demand.get_bucket_snapshot(bucket_id) if demand else {}
		var available := int(floor(float(snap.get("unserved", 0))))
		_labels[bucket_id].text = "%d" % available
		var hover := _demand_hover_projection(bucket_id, snap)
		_demand_hover_projections[bucket_id] = hover
		(_metrics[bucket_id] as Control).tooltip_text = String(hover["text"])
	var pop: int = community.get_population() if community else 0
	var cap: int = community.get_capacity() if community else 0
	_labels.population.text = "%d/%d" % [pop, cap]
	_labels.community.text = "%d%%" % int(round(community.get_average_composite() if community else 50.0))
	var pending: int = inbox.get_pending_count() if inbox and inbox.has_method("get_pending_count") else 0
	_inbox_button.text = "%d" % pending if pending > 0 else ""
	_inbox_button.tooltip_text = "Open Inbox%s" % (" (%d unread)" % pending if pending > 0 else "")

func apply_compact_layout(viewport_width: float) -> void:
	var compact := viewport_width < 1440.0
	_compact = compact
	_ui_scale = ui_scale_for_width(viewport_width)
	scale = Vector2(_ui_scale, _ui_scale)
	pivot_offset = Vector2.ZERO
	if _ui_scale > 1.0:
		anchor_left = 0.0
		anchor_right = 0.0
		offset_left = viewport_width * 0.02
		offset_right = offset_left + viewport_width * 0.96 / _ui_scale
		offset_top = 10.0 * _ui_scale
		offset_bottom = offset_top + 108.0
	else:
		anchor_left = 0.02
		anchor_right = 0.98
		offset_left = 0.0
		offset_right = 0.0
		offset_top = 10.0
		offset_bottom = 118.0
	for key in _labels:
		(_labels[key] as Label).add_theme_font_size_override("font_size", 28 if compact else 32)
		var title := _titles[key] as Label
		title.visible = false
		(_icons[key] as TextureRect).custom_minimum_size = Vector2(46, 46) if compact else Vector2(52, 52)
	if _insights_button:
		_insights_button.text = ""
		_insights_button.custom_minimum_size = Vector2(62, 62) if compact else Vector2(68, 68)
		_insights_button.add_theme_constant_override("icon_max_width", 44 if compact else 48)
	if _inbox_button:
		_inbox_button.text = ""
		_inbox_button.custom_minimum_size = Vector2(62, 62) if compact else Vector2(68, 68)
		_inbox_button.add_theme_constant_override("icon_max_width", 44 if compact else 48)


static func ui_scale_for_width(viewport_width: float) -> float:
	return clampf(viewport_width / 1920.0, 1.0, 2.0)


func _demand_hover_projection(bucket_id: String, snapshot: Dictionary) -> Dictionary:
	var display_name: String = {
		"residential": "Homes",
		"industrial": "Work",
		"commercial": "Shops",
	}.get(bucket_id, bucket_id.capitalize())
	var current_available := int(floor(float(snapshot.get("unserved", 0.0))))
	var lifetime_earned := int(floor(float(snapshot.get("total", 0.0))))
	var targets := _lifetime_targets(bucket_id, lifetime_earned)
	var lines: Array[String] = [
		"%s demand" % display_name,
		"Current available: %d" % current_available,
		"Lifetime earned: %d" % lifetime_earned,
	]
	if not targets.is_empty():
		lines.append("Lifetime unlock targets:")
		for target in targets:
			lines.append("%d — %s%s" % [
				int(target["threshold"]), String(target["display_name"]),
				" (reached)" if bool(target["reached"]) else "",
			])
	return {
		"bucket_id": bucket_id,
		"display_name": display_name,
		"current_available": current_available,
		"lifetime_earned": lifetime_earned,
		"lifetime_targets": targets,
		"text": "\n".join(lines),
	}


func _lifetime_targets(bucket_id: String, lifetime_earned: int) -> Array:
	var result: Array = []
	var uniques: Variant = _providers.get("UniqueRegistry")
	if uniques == null or not uniques.has_method("get_all_profiles"):
		return result
	var catalog: Variant = _providers.get("BuildingCatalog")
	var profiles: Dictionary = uniques.get_all_profiles()
	for building_id_variant in profiles:
		var building_id := String(building_id_variant)
		var profile: Variant = profiles[building_id_variant]
		var profile_bucket := String(_profile_field(profile, "bucket", ""))
		var threshold := int(_profile_field(profile, "prerequisite_threshold", 0))
		if profile_bucket != bucket_id or threshold <= 0:
			continue
		var display_name := building_id.replace("building_", "").replace("_", " ").capitalize()
		if catalog != null and catalog.has_method("get_summary_by_id"):
			var summary: Dictionary = catalog.get_summary_by_id(building_id)
			display_name = String(summary.get("display_name", display_name))
		result.append({
			"building_id": building_id,
			"display_name": display_name,
			"threshold": threshold,
			"reached": lifetime_earned >= threshold,
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		if int(a["threshold"]) != int(b["threshold"]):
			return int(a["threshold"]) < int(b["threshold"])
		return String(a["display_name"]) < String(b["display_name"])
	)
	return result


static func _profile_field(profile: Variant, field: String, fallback: Variant) -> Variant:
	if profile is Dictionary:
		return profile.get(field, fallback)
	if profile is Object:
		var value: Variant = profile.get(field)
		return fallback if value == null else value
	return fallback
