extends RefCounted
class_name CommunityUIFactory

const ICON_ROOT := "res://sprites/community_icons/game/"
const INK := Color("171713")
const PARCHMENT := Color("e7d3ad")
const GREEN := Color("58705a")
const ORANGE := Color("c9743f")
const TEAL := Color("2e8290")
const MUSTARD := Color("d3a526")
const ROSE := Color("b9516d")
const RED := Color("a9473f")
const TAUPE := Color("77745a")

static func icon(slug: String, size: int = 20, tooltip: String = "") -> TextureRect:
	var value := TextureRect.new()
	var path := ICON_ROOT + slug + ".png"
	if ResourceLoader.exists(path):
		value.texture = load(path)
	value.custom_minimum_size = Vector2(size, size)
	value.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	value.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	value.tooltip_text = tooltip
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return value

static func label(text: String, size: int = 13, colour: Color = Color.WHITE) -> Label:
	var value := Label.new()
	value.text = text
	value.add_theme_font_size_override("font_size", size)
	value.add_theme_color_override("font_color", colour)
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return value

static func icon_label(slug: String, text: String, tooltip: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(icon(slug, 20, tooltip))
	row.add_child(label(text))
	return row

static func button(text: String, tooltip: String = "") -> Button:
	var value := Button.new()
	value.text = text
	value.tooltip_text = tooltip
	value.focus_mode = Control.FOCUS_ALL
	return value

static func card(title: String, slug: String = "information") -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var heading := icon_label(slug, title)
	(heading.get_child(1) as Label).add_theme_font_size_override("font_size", 15)
	box.add_child(heading)
	return {"root": panel, "content": box}

static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

static func signed_amount(amount: float) -> String:
	return "%+.1f" % amount

static func anchor_label(anchor: Variant) -> String:
	if anchor == null:
		return "No home"
	if anchor is Dictionary:
		return "(%d, %d)" % [int(anchor.get("x", 0)), int(anchor.get("z", anchor.get("y", 0)))]
	if anchor is Vector2i:
		return "(%d, %d)" % [anchor.x, anchor.y]
	return "Unknown location"
