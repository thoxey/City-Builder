extends GutTest

const Builder := preload("res://scripts/builder.gd")

func test_modal_radial_and_tool_modes_have_one_canonical_priority() -> void:
	assert_eq(Builder.resolve_input_mode(true, true, true, true, true), "modal")
	assert_eq(Builder.resolve_input_mode(false, true, true, true, true), "radial")
	assert_eq(Builder.resolve_input_mode(false, false, true, true, true), "inspection")
	assert_eq(Builder.resolve_input_mode(false, false, false, true, true), "demolition")
	assert_eq(Builder.resolve_input_mode(false, false, false, false, true), "placement")
