extends GutTest

const Builder := preload("res://scripts/builder.gd")

func test_mode_priority() -> void:
	assert_eq(Builder.resolve_input_mode(true, true, true, true, true), "modal")
	assert_eq(Builder.resolve_input_mode(false, true, true, true, true), "radial")
	assert_eq(Builder.resolve_input_mode(false, false, true, true, true), "inspection")
	assert_eq(Builder.resolve_input_mode(false, false, false, true, true), "demolition")
	assert_eq(Builder.resolve_input_mode(false, false, false, false, true), "placement")
	assert_eq(Builder.resolve_input_mode(false, false, false, false, false), "world")

func test_radial_and_placement_are_mutually_exclusive() -> void:
	assert_eq(Builder.resolve_input_mode(false, true, false, false, true), "radial")
