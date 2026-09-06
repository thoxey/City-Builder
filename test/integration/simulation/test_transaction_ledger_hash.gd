extends GutTest

const Coordinator := preload("res://plugins/simulation/simulation_transaction_plugin.gd")
const Intent := preload("res://scripts/simulation/simulation_intent.gd")

func _coordinator() -> Variant:
	var coordinator = Coordinator.new()
	coordinator.register_reducer(&"economy", [&"add"], func(intents, _context):
		return {"ok":true, "plan":{"count":intents.size()}, "domains":[&"economy"]},
		func(_plan, _context): return {"ok":true})
	coordinator.register_contributor(&"source", [&"economy"], func(context, sink):
		sink.submit(Intent.create("intent:%d" % context.absolute_hour, &"source", "city",
			&"economy", &"add", {"amount":1})))
	return coordinator

func test_hash_is_deterministic_across_equivalent_histories() -> void:
	GameState.reset_state_version()
	var first = _coordinator()
	for hour in 8:
		assert_true(first.run_hour(hour, hour).ok)
	var first_hash: String = first.ledger_hash()
	first.free()

	GameState.reset_state_version()
	var second = _coordinator()
	for hour in 8:
		assert_true(second.run_hour(hour, hour).ok)
	assert_eq(second.ledger_hash(), first_hash)
	second.free()

func test_hash_covers_rows_evicted_from_bounded_inspection_window() -> void:
	GameState.reset_state_version()
	var coordinator = _coordinator()
	var initial_hash: String = coordinator.ledger_hash()
	for hour in Coordinator.MAX_LEDGER_ENTRIES + 1:
		assert_true(coordinator.run_hour(hour, hour % 24).ok)
	assert_eq(coordinator.get_ledger().size(), Coordinator.MAX_LEDGER_ENTRIES)
	assert_ne(coordinator.ledger_hash(), initial_hash)
	coordinator.free()
