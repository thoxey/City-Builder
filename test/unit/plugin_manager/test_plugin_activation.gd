extends GutTest

func test_release_rejects_all_development_plugins() -> void:
	assert_false(PluginManager.should_activate_plugin("QuestDebug", false, false))
	assert_false(PluginManager.should_activate_plugin("RoadDebug", false, true))
	assert_false(PluginManager.should_activate_plugin("Playtest", false, false))

func test_ordinary_debug_requires_road_opt_in_and_never_loads_quest_panel() -> void:
	assert_false(PluginManager.should_activate_plugin("QuestDebug", true, false))
	assert_false(PluginManager.should_activate_plugin("RoadDebug", true, false))
	assert_true(PluginManager.should_activate_plugin("RoadDebug", true, true))
	assert_true(PluginManager.should_activate_plugin("Playtest", true, false))
	assert_true(PluginManager.should_activate_plugin("PlayerUI", false, false))
