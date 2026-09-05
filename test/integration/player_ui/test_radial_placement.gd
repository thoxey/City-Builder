extends GutTest

const PlayerUI := preload("res://plugins/player_ui/player_ui_plugin.gd")

func test_accepted_selection_closes_radial_and_starts_placement_once() -> void:
	var ui := PlayerUI.new()
	ui._palette = _Palette.new(true)
	ui._builder = _Builder.new()
	ui._dock = _Dock.new()
	ui._radial = _Radial.new()
	ui._request_entry("grass")
	assert_eq(ui._palette.requests, ["grass"])
	assert_eq(ui._builder.begin_count, 1)
	assert_eq(ui._radial.close_count, 1)
	assert_eq(ui._dock.placement_ids, ["grass"])
	_free_doubles(ui)
	ui.free()

func test_rejected_selection_keeps_radial_open_and_does_not_place() -> void:
	var ui := PlayerUI.new()
	ui._palette = _Palette.new(false)
	ui._builder = _Builder.new()
	ui._dock = _Dock.new()
	ui._radial = _Radial.new()
	ui._request_entry("locked")
	assert_eq(ui._builder.begin_count, 0)
	assert_eq(ui._radial.close_count, 0)
	assert_eq(ui._radial.model_updates, 1)
	_free_doubles(ui)
	ui.free()

func _free_doubles(ui: Node) -> void:
	ui._palette.free(); ui._builder.free(); ui._dock.free(); ui._radial.free()

class _Palette extends PluginBase:
	var accepted: bool
	var requests: Array[String] = []
	func _init(value: bool) -> void: accepted = value
	func get_plugin_name() -> String: return "TestPalette"
	func request_select_entry(id: String) -> Dictionary:
		requests.append(id); return {"accepted": accepted}
	func get_build_menu_model() -> Dictionary: return {"entries_by_id": {}}

class _Builder extends Node:
	var begin_count := 0
	func begin_placement_from_palette() -> bool: begin_count += 1; return true
	func is_placement_active() -> bool: return false

class _Dock extends PlayerToolDock:
	var placement_ids: Array[String] = []
	func set_model(_model: Dictionary) -> void: pass
	func show_placement(id: String, _reason := "", _rotation := 0) -> void: placement_ids.append(id)

class _Radial extends RadialBuildMenu:
	var close_count := 0
	var model_updates := 0
	func close_menu() -> void: close_count += 1
	func set_model(_model: Dictionary) -> void: model_updates += 1
