extends SceneTree

const OUTPUT := "res://specs/004-radial-build-ui/validation/screenshots"

func _initialize() -> void:
	call_deferred("_capture_story")

func _capture_story() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(12)
	var plugin_manager := root.get_node("PluginManager")
	var ui = plugin_manager.get_plugin("PlayerUI")
	var dashboard = plugin_manager.get_plugin("Dashboard")
	var builder := current_scene.find_child("Builder", true, false)
	dashboard.set_collapsed(true)
	await _frames(3)
	await _shot("01-clean-idle")
	ui.open_build_menu()
	await _shot("02-category-radial")
	ui._radial._level = "items"
	ui._radial._group_id = "nature"
	ui._radial._focused_index = 2
	ui._radial._rebuild_actions()
	await _shot("03-nature-item-radial")
	ui._radial._group_id = "landmarks"
	ui._radial._focused_index = 0
	ui._radial._rebuild_actions()
	await _shot("04-locked-item")
	ui._radial.close_menu()
	ui._request_entry("building_duck_pond")
	await _shot("05-active-placement")
	builder._update_preview_color(Vector2i(-2, -1))
	ui._dock.show_placement("building_duck_pond", "Footprint is occupied")
	await _shot("06-blocked-placement")
	ui._toggle_demolition(true)
	await _shot("07-demolition")
	ui._toggle_demolition(false)
	dashboard.open_community()
	await _shot("08-community-drawer")
	builder._overbuild_dialog.popup_centered()
	await _shot("09-confirmation-modal")
	builder._overbuild_dialog.hide()
	dashboard.set_collapsed(true)
	ui.open_build_menu()
	ui._radial._origin = ui._radial.clamp_origin(Vector2.ZERO, Rect2(Vector2.ZERO, ui._radial.size), ui._radial.OUTER_RADIUS + 86.0, ui._radial.SAFE_MARGIN)
	ui._radial._layout_wedges()
	await _shot("10-edge-clamped-radial")
	ui._radial.close_menu()
	root.size = Vector2i(1920, 1080)
	await _frames(4)
	ui.open_build_menu()
	await _shot("11-wide-layout")
	quit()

func _shot(name: String) -> void:
	await _frames(3)
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT, name]))
	if error != OK: push_error("capture_failed: %s (%s)" % [name, error])

func _frames(count: int) -> void:
	for _i in count:
		await process_frame
