extends GutTest

const PlayerUI := preload("res://plugins/player_ui/player_ui_plugin.gd")

func test_live_unavailability_cancels_active_preview_with_canonical_reason() -> void:
	var ui := PlayerUI.new()
	ui._selected_entry_id = "pub"
	ui._palette = _Palette.new()
	ui._builder = _Builder.new()
	ui._dock = _Dock.new()
	ui._radial = _Radial.new()
	ui._refresh_model()
	assert_eq(ui._builder.cancel_count, 1)
	assert_eq(ui._dock.reason, "Requires 30 Commerce demand")
	assert_eq(ui._radial.model_updates, 1)
	ui._palette.free(); ui._builder.free(); ui._dock.free(); ui._radial.free()
	ui.free()

class _Palette extends PluginBase:
	func get_plugin_name() -> String: return "TestPalette"
	func get_build_menu_model() -> Dictionary:
		return {"entries_by_id": {"pub": {"can_select": false, "availability_label": "Requires 30 Commerce demand"}}}
class _Builder extends Node:
	var cancel_count := 0
	func is_placement_active() -> bool: return true
	func cancel_placement() -> void: cancel_count += 1
class _Dock extends PlayerToolDock:
	var reason := ""
	func set_model(_model: Dictionary) -> void: pass
	func show_placement(_id: String, value := "", _rotation := 0) -> void: reason = value
class _Radial extends RadialBuildMenu:
	var model_updates := 0
	func set_model(_model: Dictionary) -> void: model_updates += 1
