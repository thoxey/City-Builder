extends GutTest

const Coordinator := preload("res://plugins/simulation/simulation_transaction_plugin.gd")
const Intent := preload("res://scripts/simulation/simulation_intent.gd")

func _coordinator_with_reducer(applied: Array) -> Variant:
	var coordinator = Coordinator.new()
	coordinator.register_reducer(&"economy", [&"add"], func(intents, _context):
		var total := 0
		for intent in intents: total += int(intent.get_payload().amount)
		return {"ok": true, "plan": {"total": total}, "domains": [&"economy"]},
		func(plan, _context): applied.append(plan.total); return {"ok": true})
	return coordinator

func test_collects_sorts_and_commits_once() -> void:
	GameState.reset_state_version()
	var applied: Array = []
	var coordinator = _coordinator_with_reducer(applied)
	coordinator.register_contributor(&"zeta", [&"economy"], func(_context, sink):
		sink.submit(Intent.create("z", &"zeta", "city", &"economy", &"add", {"amount": 2})))
	coordinator.register_contributor(&"alpha", [&"economy"], func(_context, sink):
		sink.submit(Intent.create("a", &"alpha", "city", &"economy", &"add", {"amount": 3})))
	var result: Dictionary = coordinator.run_hour(1, 1)
	assert_true(result.ok)
	assert_eq(applied, [5])
	assert_eq(GameState.get_state_version(), 1)
	assert_eq(result.ledger.map(func(row): return row.intent_id), ["a", "z"])
	coordinator.free()

func test_duplicate_intent_rejects_atomically_and_preserves_version() -> void:
	GameState.reset_state_version()
	var applied: Array = []
	var coordinator = _coordinator_with_reducer(applied)
	coordinator.register_contributor(&"alpha", [&"economy"], func(_context, sink):
		for _i in 2: sink.submit(Intent.create("same", &"alpha", "city", &"economy", &"add", {"amount": 1})))
	var result: Dictionary = coordinator.run_hour(1, 1)
	assert_false(result.ok)
	assert_eq(result.failure.reason_code, "duplicate_intent")
	assert_true(applied.is_empty())
	assert_eq(GameState.get_state_version(), 0)
	coordinator.free()

func test_unknown_operation_and_stale_version_reject_before_commit() -> void:
	GameState.reset_state_version()
	var applied: Array = []
	var coordinator = _coordinator_with_reducer(applied)
	coordinator.register_contributor(&"alpha", [&"economy"], func(_context, sink):
		sink.submit(Intent.create("set", &"alpha", "city", &"economy", &"set", {"amount": 1})))
	assert_eq(coordinator.run_hour(1, 1).failure.reason_code, "unknown_operation")
	assert_true(applied.is_empty())
	assert_eq(coordinator.run_hour(1, 1, {}, {}, 99).failure.reason_code, "stale_state_version")
	coordinator.free()

func test_reentry_is_rejected() -> void:
	GameState.reset_state_version()
	var nested := {}
	var coordinator = Coordinator.new()
	coordinator.register_reducer(&"economy", [&"add"], func(_intents, _context): return {"ok": true, "plan": {}, "domains": [&"economy"]}, func(_plan, _context): return {"ok": true})
	coordinator.register_contributor(&"alpha", [&"economy"], func(_context, sink):
		nested.merge(coordinator.run_hour(2, 2)); sink.submit(Intent.create("a", &"alpha", "city", &"economy", &"add", {"amount": 1})))
	assert_true(coordinator.run_hour(1, 1).ok)
	assert_eq(nested.failure.reason_code, "reentrant_transaction")
	coordinator.free()

func test_collection_side_effect_is_rejected_before_reduction() -> void:
	var saved_map := GameState.map
	GameState.map = DataMap.new()
	GameState.reset_state_version()
	var applied: Array = []
	var before_cash := GameState.map.cash
	var coordinator = _coordinator_with_reducer(applied)
	coordinator.register_contributor(&"alpha", [&"economy"], func(_context, _sink): GameState.map.cash += 1)
	var result: Dictionary = coordinator.run_hour(1, 1)
	assert_false(result.ok)
	assert_eq(result.failure.reason_code, "collection_side_effect")
	assert_true(applied.is_empty())
	assert_eq(GameState.map.cash, before_cash)
	coordinator.free()
	GameState.map = saved_map
