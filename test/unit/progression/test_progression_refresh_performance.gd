extends GutTest

const UniqueRegistryCls := preload("res://plugins/unique_registry/unique_registry_plugin.gd")
const FRAME_BUDGET_MS := 16.7
const SAMPLE_COUNT := 500

func test_canonical_progression_refresh_stays_within_one_frame() -> void:
	var catalog := RefreshCatalog.new()
	var demand := RefreshDemand.new()
	var characters := RefreshCharacters.new()
	var patrons := RefreshPatrons.new()
	var registry := UniqueRegistryCls.new()
	registry._catalog = catalog
	registry._demand = demand
	registry._characters = characters
	registry._patrons = patrons
	registry._index_uniques()
	registry._placed = {
		"building_postwar_tower_block":Vector2i.ZERO,
		"building_pipe_factory":Vector2i.ZERO,
		"building_nightclub":Vector2i.ZERO,
	}
	registry._refresh_unlocks() # Warm caches and exclude one-time signal work.

	var total_usec := 0
	var max_usec := 0
	for _sample in SAMPLE_COUNT:
		var started := Time.get_ticks_usec()
		registry._refresh_unlocks()
		var elapsed := Time.get_ticks_usec() - started
		total_usec += elapsed
		max_usec = maxi(max_usec, elapsed)
	var average_ms := float(total_usec) / float(SAMPLE_COUNT) / 1000.0
	var max_ms := float(max_usec) / 1000.0
	gut.p("PROGRESSION_REFRESH_PERF profiles=%d samples=%d average_ms=%.4f max_ms=%.4f" % [registry.get_all_profiles().size(), SAMPLE_COUNT, average_ms, max_ms])
	assert_eq(registry.get_all_profiles().size(), 7)
	assert_lt(max_ms, FRAME_BUDGET_MS, "slowest canonical refresh took %.4f ms" % max_ms)

	registry.free()
	patrons.free()
	characters.free()
	demand.free()
	catalog.free()

class RefreshCatalog extends PluginBase:
	var structures: Array[Structure] = []
	var summaries: Array = []
	func _init() -> void:
		_add("building_postwar_tower_block", "residential", "", "chain", 10, [])
		_add("building_pipe_factory", "industrial", "", "chain", 40, [])
		_add("building_nightclub", "commercial", "", "chain", 60, [])
		_add("building_pirate_radio", "residential", "aristocrat_residential", "want", 60, ["building_postwar_tower_block"])
		_add("building_crazy_golf", "industrial", "aristocrat_industrial", "want", 60, ["building_pipe_factory"])
		_add("building_members_club", "commercial", "aristocrat_commercial", "want", 60, ["building_nightclub"])
		_add("building_theatre", "residential", "", "landmark", 0, ["building_pirate_radio", "building_crazy_golf", "building_members_club"])
	func _add(id: String, bucket: String, character_id: String, role: String, threshold: int, prerequisites: Array) -> void:
		var profile := UniqueProfile.new()
		profile.bucket = bucket
		profile.character_id = character_id
		profile.patron_id = "aristocrat"
		profile.chain_role = role
		profile.prerequisite_threshold = threshold
		profile.prerequisite_ids = PackedStringArray(prerequisites)
		var structure := Structure.new()
		structure.metadata = [profile]
		structures.append(structure)
		summaries.append({"building_id":id, "display_name":id})
	func get_all() -> Array[Structure]: return structures
	func get_summary() -> Array: return summaries
	func get_summary_by_id(id: String) -> Dictionary: return {"building_id":id, "display_name":id}

class RefreshDemand extends PluginBase:
	func bucket_for_category(category: String) -> String: return category
	func bucket_display_name(bucket: String) -> String: return bucket
	func get_total(_bucket: String) -> float: return 1000.0
	func get_value(_bucket: String) -> float: return 1000.0

class RefreshCharacters extends PluginBase:
	func get_state(_id: String) -> int: return 2
	func get_def(id: String) -> Dictionary: return {"display_name":id}

class RefreshPatrons extends PluginBase:
	func get_state(_id: String) -> int: return 1
	func get_def(id: String) -> Dictionary: return {"display_name":id}
