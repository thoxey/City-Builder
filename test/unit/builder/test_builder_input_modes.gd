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

func test_placement_feedback_fades_quickly_then_eases_into_a_bounded_taper() -> void:
	var samples := [
		Builder.placement_feedback_alpha(0.0),
		Builder.placement_feedback_alpha(0.8),
		Builder.placement_feedback_alpha(1.6),
		Builder.placement_feedback_alpha(2.4),
		Builder.placement_feedback_alpha(Builder.PLACEMENT_FEEDBACK_DURATION),
	]
	assert_almost_eq(samples[0], 1.0, 0.0001)
	assert_almost_eq(samples[-1], 0.0, 0.0001)
	for index in range(1, samples.size()):
		assert_lt(samples[index], samples[index - 1], "opacity is strictly monotonic before cleanup")
	var early_drop: float = samples[0] - samples[1]
	var final_drop: float = samples[-2] - samples[-1]
	assert_gt(early_drop, final_drop, "initial fade is steeper than the final taper")
	assert_gt(samples[2], 0.25, "icon remains readable halfway through the longer lifetime")
	assert_eq(Builder.placement_feedback_alpha(99.0), 0.0, "feedback is fully transparent by its cleanup bound")
