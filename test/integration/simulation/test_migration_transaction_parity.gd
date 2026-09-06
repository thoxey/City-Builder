extends GutTest

const CommunityPlugin := preload("res://plugins/community/community_plugin.gd")
const Context := preload("res://scripts/simulation/hour_context.gd")
const Sink := preload("res://scripts/simulation/intent_sink.gd")

class RejectingCommunity extends "res://plugins/community/community_plugin.gd":
	func _free_housing_slots() -> Array:
		return [{"anchor":Vector2i.ZERO, "slot":0}]
	func _source_records(_hour: int) -> Array: return []
	func quote_migration(_candidate: CommunityResident, _context: Dictionary = {}) -> Dictionary:
		return {"ok":false, "reason":"below_threshold"}

func _plugin() -> Variant:
	var community := RejectingCommunity.new()
	community._balance = {"candidate_batch_size":4, "migration_hour":6,
		"personality_generation_version":1}
	community._generator = CommunityPersonalityGenerator.new([])
	community._rng.seed = 6066
	return community

func test_collection_emits_stable_independently_attributable_candidate_intents_without_advancing_rng() -> void:
	var community = _plugin()
	var context = Context.create("hour:30", 30, 1, 6, {}, 0, {}, {})
	var before_state: int = community._rng.state
	var first = Sink.create(&"community", [&"community"])
	community._collect_hour(context, first)
	var second = Sink.create(&"community", [&"community"])
	community._collect_hour(context, second)
	assert_eq(community._rng.state, before_state)
	assert_eq(first.intents().map(func(intent): return intent.to_dict()),
		second.intents().map(func(intent): return intent.to_dict()))
	var candidates: Array = first.intents().filter(func(intent): return intent.operation == &"migration_candidate")
	assert_eq(candidates.size(), 4)
	assert_eq(candidates.map(func(intent): return intent.entity_key),
		["candidate:1:00", "candidate:1:01", "candidate:1:02", "candidate:1:03"])
	community.free()

func test_attributed_seed_plan_matches_legacy_rng_progression_and_decisions() -> void:
	var saved_map := GameState.map
	GameState.map = DataMap.new()
	var attributed = _plugin()
	var context = Context.create("hour:6", 6, 0, 6, {}, 0, {}, {})
	var sink = Sink.create(&"community", [&"community"])
	attributed._collect_hour(context, sink)
	var records: Array = sink.intents().filter(func(intent): return intent.operation == &"migration_candidate").map(func(intent): return intent.get_payload())
	attributed._run_daily_migration([], null, records)
	var attributed_state: int = attributed._rng.state
	var attributed_migration: Dictionary = attributed._migration.duplicate(true)
	attributed.free()

	GameState.map = DataMap.new()
	var legacy = _plugin()
	legacy._run_daily_migration()
	assert_eq(legacy._rng.state, attributed_state)
	assert_eq(legacy._migration, attributed_migration)
	legacy.free()
	GameState.map = saved_map
