extends GutTest

const Context := preload("res://scripts/simulation/hour_context.gd")
const Intent := preload("res://scripts/simulation/simulation_intent.gd")
const ChangeSet := preload("res://scripts/simulation/authoritative_change_set.gd")

func test_runtime_records_are_not_datamap_properties_or_serialized_payload() -> void:
	var map := DataMap.new()
	var property_names: Array[String] = []
	for property in map.get_property_list():
		property_names.append(String(property.name))
	for forbidden in ["state_version", "hour_context", "simulation_intents", "transaction_ledger", "compiled_runtime", "presentation_cache"]:
		assert_false(forbidden in property_names, "%s must not be saveable DataMap state" % forbidden)

func test_runtime_records_do_not_change_canonical_gameplay_hash() -> void:
	var payload := {"cash": 1000, "structures": [], "community_residents": []}
	var before := JSON.stringify(payload).sha256_text()
	Context.create("h1-v0", 1, 0, 1, {"seed": 7}, 0, {"town": {}}, {"topology": 0})
	Intent.create("economy:income:1", &"economy", "city", &"economy", &"add", {"amount": 5})
	ChangeSet.create("change:h1-v0", &"hourly_transaction", "h1-v0", 0, 1, [&"clock", &"economy"])
	assert_eq(JSON.stringify(payload).sha256_text(), before)

func test_state_version_changes_once_on_commit_and_resets_at_load_boundary() -> void:
	GameState.reset_state_version()
	assert_eq(GameState.get_state_version(), 0)
	assert_eq(GameState.commit_state_version(0), 1)
	assert_eq(GameState.get_state_version(), 1)
	assert_eq(GameState.commit_state_version(0), -1, "stale commits must not advance")
	assert_eq(GameState.get_state_version(), 1)
	GameState.reset_state_version()
	assert_eq(GameState.get_state_version(), 0)
