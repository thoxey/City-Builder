extends GutTest

const Coordinator := preload("res://plugins/simulation/simulation_transaction_plugin.gd")
const Intent := preload("res://scripts/simulation/simulation_intent.gd")

func _run(registration_ids: Array[StringName]) -> Dictionary:
	GameState.reset_state_version()
	var totals := {"value":0}
	var coordinator = Coordinator.new()
	coordinator.register_reducer(&"economy", [&"add"], func(intents, _context):
		var value := 0
		for intent in intents: value += int(intent.get_payload().amount)
		return {"ok":true, "plan":{"value":value}, "domains":[&"economy"]},
		func(plan, _context): totals.value += int(plan.value); return {"ok":true})
	for id in registration_ids:
		var captured_id := id
		coordinator.register_contributor(id, [&"economy"], func(context, sink):
			sink.submit(Intent.create("%s:%d" % [captured_id, context.absolute_hour],
				captured_id, "city", &"economy", &"add", {"amount":1})))
	var outcome: Dictionary = coordinator.run_hour(7, 7)
	var result := {"state":totals.duplicate(true), "ledger_hash":coordinator.ledger_hash(),
		"intent_ids":outcome.ledger.map(func(row): return row.intent_id)}
	coordinator.free()
	return result

func test_reversed_registration_has_identical_state_ledger_and_order() -> void:
	var normal := _run([&"alpha", &"beta", &"gamma"])
	var reversed := _run([&"gamma", &"beta", &"alpha"])
	assert_eq(reversed, normal)
