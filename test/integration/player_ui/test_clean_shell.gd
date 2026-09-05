extends GutTest

func test_main_scene_has_no_legacy_player_hud_or_dev_controls() -> void:
	var source := FileAccess.get_file_as_string("res://scenes/main.tscn")
	for legacy in ["name=\"Top\"", "name=\"Instructions\"", "name=\"DevCommands\""]:
		assert_false(source.contains(legacy), legacy)
	var palette := FileAccess.get_file_as_string("res://plugins/palette/palette_plugin.gd")
	assert_true(palette.contains("func _build_ui() -> void:\n\tpass"))
