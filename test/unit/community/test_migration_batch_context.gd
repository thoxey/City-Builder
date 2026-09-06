extends GutTest

const CommunityPlugin := preload("res://plugins/community/community_plugin.gd")

class CachedFactsCommunity extends "res://plugins/community/community_plugin.gd":
	var source_calls := 0
	func _free_housing_slots() -> Array:
		return [{"anchor":Vector2i.ZERO, "slot":0}]
	func _source_records(_hour: int) -> Array:
		source_calls += 1
		return []

var _saved_map: DataMap
var _saved_registry: Dictionary
var _saved_structures: Array[Structure]

func before_each() -> void:
	_saved_map = GameState.map
	_saved_registry = GameState.building_registry
	_saved_structures = GameState.structures
	GameState.map = DataMap.new()
	GameState.building_registry = {}
	GameState.structures = []

func after_each() -> void:
	GameState.map = _saved_map
	GameState.building_registry = _saved_registry
	GameState.structures = _saved_structures

func test_unchanged_revision_reuses_facts_but_returns_fresh_available_homes() -> void:
	var community := CachedFactsCommunity.new()
	community._balance = {"personality_generation_version":1}
	var first: Dictionary = community._migration_quote_context()
	first.available_homes.clear()
	var second: Dictionary = community._migration_quote_context()
	assert_eq(community.source_calls, 1)
	assert_eq(second.available_homes.size(), 1)
	assert_eq(community.get_migration_fact_cache_stats().hits, 1)
	community.free()

func test_explicit_runtime_invalidation_rebuilds_migration_facts_once() -> void:
	var community := CachedFactsCommunity.new()
	community._balance = {"personality_generation_version":1}
	community._migration_quote_context()
	community._dispose_compiled_runtime()
	community._migration_quote_context()
	assert_eq(community.source_calls, 2)
	assert_eq(community.get_migration_fact_cache_stats().misses, 2)
	community.free()
