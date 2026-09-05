extends GutTest

func test_every_top_bar_metric_and_action_has_a_runtime_icon() -> void:
	var bar := PlayerStatusBar.new()
	bar.setup({})
	assert_eq(bar._icons.size(), 9)
	assert_false(bar._icons.has("satisfaction"))
	for key in bar._icons:
		assert_not_null((bar._icons[key] as TextureRect).texture, key)
	assert_not_null(bar._inbox_button.icon)
	assert_not_null(bar._insights_button.icon)
	bar.free()
