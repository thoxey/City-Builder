extends PanelContainer
class_name PlacementConsequencesPanel

const QUALITY_ORDER := ["opportunity", "liveability", "beauty", "belonging"]
const ICON_ROOT := "res://sprites/community_icons/game/"
const COLOURS := {
	"positive": Color("58705a"),
	"negative": Color("a9473f"),
	"unchanged": Color("77745a"),
	"invalid": Color("a9473f"),
	"replacement": Color("c9743f"),
	"uncertain": Color("d3a526"),
	"neutral": Color("171713"),
}
const WIDE_HALF_WIDTH := 285.0
const COMPACT_HALF_WIDTH := 235.0
const COMPACT_BREAKPOINT := 1400.0
const COMPACT_CENTRE_SHIFT := -190.0
const SAFE_MARGIN := 12.0

var _heading: Label
var _rows: VBoxContainer
var _last_quote: Dictionary = {}
var _left_safe_inset := 0.0
var _right_safe_inset := 0.0
var _layout_viewport_width := 1920.0

func setup() -> void:
	name = "PlacementConsequencesPanel"
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_apply_horizontal_layout()
	offset_top = -288.0
	offset_bottom = -216.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e7d3ad")
	style.border_color = Color("171713")
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	add_child(content)
	_heading = Label.new()
	_heading.text = "THIS LOCATION"
	_heading.add_theme_font_size_override("font_size", 16)
	_heading.add_theme_color_override("font_color", Color("171713"))
	content.add_child(_heading)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	content.add_child(_rows)
	hide_quote()

func set_right_safe_inset(inset: float) -> void:
	_right_safe_inset = maxf(0.0, inset)
	_apply_horizontal_layout()

func set_left_safe_inset(inset: float) -> void:
	_left_safe_inset = maxf(0.0, inset)
	_apply_horizontal_layout()

func apply_compact_layout(viewport_width: float) -> void:
	_layout_viewport_width = maxf(1.0, viewport_width)
	_apply_horizontal_layout()

func _apply_horizontal_layout() -> void:
	var compact := _layout_viewport_width <= COMPACT_BREAKPOINT
	var nominal_half_width := COMPACT_HALF_WIDTH if compact else WIDE_HALF_WIDTH
	var left_edge := SAFE_MARGIN
	if _left_safe_inset > 0.0:
		left_edge = maxf(left_edge, _left_safe_inset + SAFE_MARGIN)
	var right_edge := maxf(left_edge + 1.0, _layout_viewport_width - _right_safe_inset - SAFE_MARGIN)
	var half_width := minf(nominal_half_width, (right_edge - left_edge) * 0.5)
	var desired_centre := _layout_viewport_width * 0.5
	if compact:
		desired_centre += COMPACT_CENTRE_SHIFT
	var centre := clampf(desired_centre, left_edge + half_width, right_edge - half_width)
	var centre_shift := centre - _layout_viewport_width * 0.5
	offset_left = centre_shift - half_width
	offset_right = centre_shift + half_width

func show_quote(quote: Dictionary) -> void:
	_last_quote = quote.duplicate(true)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var models := presentation_rows(quote)
	if models.is_empty():
		visible = false
		return
	visible = true
	for row in models:
		_rows.add_child(_make_row(row))
	_resize_for_rows(models.size())

func hide_quote() -> void:
	_last_quote.clear()
	visible = false

func _resize_for_rows(count: int) -> void:
	var height := clampf(46.0 + float(count) * 24.0, 72.0, 310.0)
	offset_top = offset_bottom - height

func _make_row(model: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	var slug := String(model.get("icon", "information"))
	var path := ICON_ROOT + slug + ".png"
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.text = String(model.get("text", ""))
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", COLOURS.get(String(model.get("tone", "neutral")), COLOURS.neutral))
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.tooltip_text = String(model.get("tooltip", ""))
	row.add_child(label)
	return row

static func presentation_rows(quote: Dictionary) -> Array:
	var rows: Array = []
	var status := String(quote.get("status", "invalid"))
	if status == "invalid":
		var reason := String(quote.get("reason", "cannot_place_here")).replace("_", " ").capitalize()
		rows.append({"kind":"invalid", "text":"Blocked — %s" % reason, "tone":"invalid", "icon":"warning", "actionable":true})
	elif status == "replacement":
		var removed_count: int = quote.get("replacement", {}).get("removed_buildings", []).size()
		rows.append({"kind":"replacement", "text":"Replacement — removes %d building%s after confirmation" % [removed_count, "" if removed_count == 1 else "s"], "tone":"replacement", "icon":"warning", "actionable":true})
	var access: Dictionary = quote.get("access", {})
	if not access.is_empty() and not bool(access.get("ok", true)):
		var access_text := String(access.get("reason", "Access uncertain")).replace("_", " ").capitalize()
		rows.append({"kind":"access", "text":access_text, "tone":"invalid", "icon":"neighbourhood", "actionable":true})
	# Invalid envelopes have no trustworthy positive or negative domain effects, but
	# can still carry separate access and uncertainty warnings.
	if status != "invalid":
		var community: Dictionary = quote.get("community", {})
		var quality_deltas: Dictionary = community.get("quality_deltas", {})
		var has_quality_change := false
		for quality in QUALITY_ORDER:
			var delta := float(quality_deltas.get(quality, 0.0))
			if delta == 0.0:
				continue
			has_quality_change = true
			var tone := "positive" if delta > 0.0 else "negative"
			rows.append({"kind":"quality", "text":"%s %s" % [String(quality).capitalize(), _signed(delta)], "tone":tone, "icon":quality, "actionable":false, "semantic_delta":delta})
		var resident_count := int(community.get("affected_resident_count", 0))
		var home_count := int(community.get("affected_home_count", 0))
		var neighbour_count := int(quote.get("same_type_neighbours", 0))
		if has_quality_change and (resident_count > 0 or home_count > 0 or neighbour_count > 0):
			var affected_parts: PackedStringArray = []
			if resident_count > 0:
				affected_parts.append("%d resident%s" % [resident_count, "" if resident_count == 1 else "s"])
			if home_count > 0:
				affected_parts.append("%d home%s" % [home_count, "" if home_count == 1 else "s"])
			var affected_text := " · ".join(affected_parts)
			if not affected_text.is_empty():
				affected_text += " affected"
			if neighbour_count > 0:
				if not affected_text.is_empty():
					affected_text += " · "
				affected_text += "%d similar nearby" % neighbour_count
			rows.append({"kind":"affected", "text":affected_text, "tone":"neutral", "icon":"resident", "actionable":false})
		var radius_labels: PackedStringArray = []
		for radius in community.get("effect_radii", []):
			if int(radius) > 0:
				radius_labels.append(str(radius))
		if has_quality_change and not radius_labels.is_empty():
			rows.append({"kind":"reach", "text":"Effect reach: %s tile%s" % [", ".join(radius_labels), "" if radius_labels.size() == 1 else "s"], "tone":"neutral", "icon":"effect-radius", "actionable":false})
		var attractiveness: Dictionary = quote.get("attractiveness", {})
		if not attractiveness.is_empty():
			var appeal_delta := float(attractiveness.get("city_delta", 0.0))
			var tile_count := int(attractiveness.get("affected_tile_count", 0))
			if appeal_delta != 0.0:
				var appeal_tone := "positive" if appeal_delta > 0.0 else "negative"
				var appeal_text := "Town appeal %s" % _signed(appeal_delta)
				if tile_count > 0:
					appeal_text += " across %d tile%s" % [tile_count, "" if tile_count == 1 else "s"]
				rows.append({"kind":"attractiveness", "text":appeal_text, "tone":appeal_tone, "icon":"effect-radius", "actionable":false, "semantic_delta":appeal_delta})
			elif tile_count > 0:
				rows.append({"kind":"attractiveness", "text":"Town appeal shifts across %d tile%s" % [tile_count, "" if tile_count == 1 else "s"], "tone":"neutral", "icon":"effect-radius", "actionable":false, "semantic_delta":appeal_delta})
	var uncertainties: Array = quote.get("uncertainties", [])
	if not uncertainties.is_empty():
		rows.append({"kind":"uncertainty", "text":_uncertainty_label(String(uncertainties[0])), "tone":"uncertain", "icon":"information", "tooltip":", ".join(uncertainties), "actionable":true})
	return rows.slice(0, 10)

static func _uncertainty_label(code: String) -> String:
	match code:
		"participant_allocation_after_commit", "reachable_assignment_after_commit":
			return "Assignments settle after placement"
		"network_reconnections_after_commit":
			return "Network changes settle after placement"
		_:
			return "After placement: %s" % code.replace("_", " ")

static func _signed(value: float) -> String:
	if value == 0.0:
		return "±0"
	return "%+.1f" % value
