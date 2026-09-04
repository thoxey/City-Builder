extends GutTest

const PluginManagerCls := preload("res://scripts/plugin_manager.gd")

func test_playtest_is_disabled_in_release_builds() -> void:
	assert_false(PluginManagerCls.should_activate_plugin("Playtest", false))
	assert_true(PluginManagerCls.should_activate_plugin("Playtest", true))
	assert_true(PluginManagerCls.should_activate_plugin("Economy", false))
