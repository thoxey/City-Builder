extends GutTest

const Reducer := preload("res://scripts/simulation/resource_reducer.gd")
const Intent := preload("res://scripts/simulation/simulation_intent.gd")

func test_allocation_is_priority_then_identity_stable() -> void:
	var intents := [
		Intent.create("b", &"workplace", "b", &"resources", &"demand", {"type_id":"workers", "amount":4, "target_key":"workers"}, 1),
		Intent.create("s", &"residential", "source", &"resources", &"supply", {"type_id":"workers", "amount":5, "target_key":"workers"}),
		Intent.create("a", &"workplace", "a", &"resources", &"demand", {"type_id":"workers", "amount":4, "target_key":"workers"}, 1),
	]
	intents.sort_custom(func(a, b): return a.canonical_key() < b.canonical_key())
	var result: Dictionary = Reducer.reduce(intents, null)
	assert_true(result.ok)
	assert_eq(result.plan.fulfillment.a, 4)
	assert_eq(result.plan.fulfillment.b, 1)
	assert_eq(result.plan.satisfaction.workers, 0.625)
