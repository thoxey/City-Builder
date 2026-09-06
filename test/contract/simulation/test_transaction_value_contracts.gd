extends GutTest

const HourContextType := preload("res://scripts/simulation/hour_context.gd")
const IntentType := preload("res://scripts/simulation/simulation_intent.gd")
const LedgerType := preload("res://scripts/simulation/transaction_ledger_entry.gd")
const ChangeSetType := preload("res://scripts/simulation/authoritative_change_set.gd")

func test_hour_context_detaches_nested_inputs() -> void:
	var projections := {"city": {"cash": 10}}
	var context = HourContextType.create("hour:1:v0", 1, 0, 1, {"simulation": 7}, 0, projections, {"clock": 1})
	projections["city"]["cash"] = 99
	var first: Dictionary = context.get_projection("city")
	first["cash"] = -1
	assert_eq(context.get_projection("city")["cash"], 10)

func test_intents_have_stable_identity_and_complete_canonical_order() -> void:
	var a = IntentType.create("i2", &"community", "resident:2", &"community", &"add", {"amount": 1}, 5, &"add", 2)
	var b = IntentType.create("i1", &"community", "resident:1", &"community", &"add", {"amount": 1}, 5, &"add", 2)
	assert_true(a.is_valid())
	assert_true(b.is_valid())
	assert_true(b.canonical_key() < a.canonical_key())
	var payload: Dictionary = a.get_payload()
	payload["amount"] = 999
	assert_eq(a.get_payload()["amount"], 1)

func test_ledger_reason_codes_and_dispositions_are_finite() -> void:
	assert_true(LedgerType.is_disposition(LedgerType.DISPOSITION_COMMITTED))
	assert_true(LedgerType.is_reason_code(LedgerType.REASON_DUPLICATE_INTENT))
	assert_false(LedgerType.is_reason_code(&"free_form_failure"))

func test_change_set_canonicalizes_domains_entities_and_detaches() -> void:
	var change = ChangeSetType.create("c1", &"building_mutation", "place:1", 2, 3,
		[&"community", &"structures", &"community"],
		{"community": ["resident:2", "resident:1"], "structures": ["4:2"]},
		{"population": {"before": 1, "after": 2}}, {"community": 4})
	assert_true(change.is_valid())
	assert_eq(change.get_domains(), [&"structures", &"community"])
	assert_eq(change.get_entity_keys()["community"], ["resident:1", "resident:2"])
	var exported: Dictionary = change.to_dict()
	exported["deltas"]["population"]["after"] = 100
	assert_eq(change.to_dict()["deltas"]["population"]["after"], 2)
