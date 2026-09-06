extends GutTest

const EVIDENCE_PATH := "res://specs/005-reachable-first-patron/validation/last-run.json"
const PaletteCls := preload("res://plugins/palette/palette_plugin.gd")
const DashboardCls := preload("res://plugins/dashboard/dashboard_plugin.gd")
const PlaytestCls := preload("res://plugins/playtest/playtest_plugin.gd")
const UniqueRegistryCls := preload("res://plugins/unique_registry/unique_registry_plugin.gd")
const BuilderCls := preload("res://scripts/builder.gd")
const STORY_IDS := [
	"building_pirate_radio",
	"building_crazy_golf",
	"building_members_club",
	"building_theatre",
]

func test_rejected_story_placement_keeps_the_canonical_state_hash() -> void:
	var evidence := _json(EVIDENCE_PATH)
	var actions: Array = evidence.get("actions", [])
	var index := actions.find_custom(func(row): return row.get("request_id", "") == "078a-theatre-blocked-before-patron")
	assert_gt(index, 0)
	assert_eq(actions[index].get("status"), "rejected")
	assert_eq(actions[index].get("reason"), PlaytestActionResult.PATRON_NOT_READY)
	assert_eq(actions[index].get("state_hash"), actions[index - 1].get("state_hash"), "locked placement is an atomic no-op")

func test_final_story_decisions_and_patron_projection_agree() -> void:
	var progression: Dictionary = _json(EVIDENCE_PATH).get("final", {}).get("progression", {})
	var patron: Dictionary = progression.get("patrons", {}).get("aristocrat", {})
	var theatre: Dictionary = progression.get("story_buildings", {}).get("building_theatre", {})
	assert_eq(patron.get("state_name"), "COMPLETED")
	assert_true(patron.get("donation_applied", false))
	assert_true(theatre.get("placed", false))
	assert_eq(theatre.get("primary_reason"), PlaytestActionResult.UNIQUE_ALREADY_PLACED)
	assert_eq(theatre.get("reasons", [])[0], PlaytestActionResult.UNIQUE_ALREADY_PLACED)

func test_every_canonical_milestone_agrees_across_public_progression_surfaces() -> void:
	var saved_map := GameState.map
	var saved_structures := GameState.structures
	var saved_cells := GameState.cell_to_building.duplicate(true)
	var saved_registry := GameState.building_registry.duplicate(true)
	GameState.map = DataMap.new()
	GameState.cell_to_building = {}
	GameState.building_registry = {}

	var catalog := ParityCatalog.new()
	var demand := ParityDemand.new()
	var economy := ParityEconomy.new()
	var land := ParityLand.new()
	var characters := ParityCharacters.new()
	var patrons := ParityPatrons.new()
	var uniques := UniqueRegistryCls.new()
	uniques._catalog = catalog
	uniques._demand = demand
	uniques._characters = characters
	uniques._patrons = patrons
	uniques._index_uniques()

	var palette := PaletteCls.new()
	palette._catalog = catalog
	palette._demand = demand
	palette._economy = economy
	palette._uniques = uniques
	palette._build_entries()

	var dashboard := DashboardCls.new()
	dashboard._catalog = catalog
	dashboard._demand = demand
	dashboard._characters = characters
	dashboard._patrons = patrons

	var playtest := PlaytestCls.new()
	playtest._status = "ready"
	playtest._catalog = catalog
	playtest._demand = demand
	playtest._economy = economy
	playtest._palette = palette
	playtest._uniques = uniques
	playtest._characters = characters
	playtest._patrons = patrons

	var builder := BuilderCls.new()
	builder.structures = catalog.items
	builder._catalog = catalog
	builder._demand = demand
	builder._economy = economy
	builder._land = land
	builder._uniques = uniques
	GameState.structures = catalog.items

	var milestones: Array = _json(EVIDENCE_PATH).get("milestones", [])
	assert_eq(milestones.size(), 15, "the canonical trace retains every required boundary")
	for milestone: Dictionary in milestones:
		var context := String(milestone.get("milestone_id", "unknown"))
		characters.apply_milestone(milestone)
		patrons.apply_milestone(milestone)
		catalog.tier_projections = milestone.get("demand", {}).duplicate(true)
		uniques._placed.clear()
		for building_id in milestone.get("placed_building_ids", []):
			uniques._placed[String(building_id)] = Vector2i.ZERO
		_refresh_unlock_cache(uniques)
		palette._refresh()

		var menu: Dictionary = palette.get_build_menu_model()
		var choices: Array = playtest.get_choices({"available_only":false}).get("choices", [])
		var progression: Dictionary = playtest._progression_snapshot()
		var patron_drawer: Object = dashboard.snapshot()
		for character_id in progression.characters:
			assert_eq(patron_drawer.character_projections.get(character_id, {}), progression.characters[character_id], "%s character projection %s" % [context, character_id])
		for patron_id in progression.patrons:
			assert_eq(patron_drawer.patron_projections.get(patron_id, {}), progression.patrons[patron_id], "%s patron projection %s" % [context, patron_id])
		assert_eq(patron_drawer.next_step.get("kind", ""), progression.next_step.get("kind", ""), "%s next-step kind" % context)
		assert_eq(patron_drawer.next_step.get("subject_id", ""), progression.next_step.get("subject_id", ""), "%s next-step subject" % context)

		for story_id in STORY_IDS:
			var canonical: Dictionary = uniques.evaluate_unlock(story_id)
			var radial: Dictionary = menu.get("entries_by_id", {}).get(story_id, {})
			var choice: Dictionary = _find_choice(choices, story_id)
			var command: Dictionary = builder.evaluate_placement(story_id, Vector2i(20, 20))
			var command_gate: Dictionary = command.get("details", {}).get("progression_gate", {})
			assert_eq(radial.get("can_select", false), canonical.get("selectable", false), "%s radial %s" % [context, story_id])
			assert_eq(radial.get("reasons", []), canonical.get("reasons", []), "%s radial reasons %s" % [context, story_id])
			assert_eq(choice.get("available", false), canonical.get("selectable", false), "%s playtest choice %s" % [context, story_id])
			assert_eq(choice.get("reasons", []), canonical.get("reasons", []), "%s playtest reasons %s" % [context, story_id])
			assert_eq(command_gate.get("selectable", false), canonical.get("selectable", false), "%s Builder %s" % [context, story_id])
			assert_eq(command_gate.get("primary_reason"), canonical.get("primary_reason"), "%s Builder reason %s" % [context, story_id])

	builder.free()
	playtest.free()
	dashboard.free()
	palette.free()
	uniques.free()
	characters.free()
	patrons.free()
	land.free()
	economy.free()
	demand.free()
	catalog.free()
	GameState.map = saved_map
	GameState.structures = saved_structures
	GameState.cell_to_building = saved_cells
	GameState.building_registry = saved_registry

func _refresh_unlock_cache(uniques: Node) -> void:
	uniques._unlocked_cache.clear()
	for story_id in uniques.get_all_profiles():
		if bool(uniques.evaluate_unlock(story_id).get("unlocked", false)):
			uniques._unlocked_cache[story_id] = true

func _find_choice(choices: Array, story_id: String) -> Dictionary:
	for choice: Dictionary in choices:
		if choice.get("choice_id", "") == story_id:
			return choice
	return {}

func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

class ParityCatalog extends PluginBase:
	var items: Array[Structure] = []
	var summaries: Array = []
	var tier_projections: Dictionary = {}
	func _init() -> void:
		_add("building_pirate_radio", "Pirate Radio Station", "residential", "aristocrat_residential", "want", 60, ["building_postwar_tower_block"])
		_add("building_crazy_golf", "Crazy Golf", "industrial", "aristocrat_industrial", "want", 60, ["building_pipe_factory"])
		_add("building_members_club", "Private Members' Club", "commercial", "aristocrat_commercial", "want", 60, ["building_nightclub"])
		_add("building_theatre", "The Theatre", "residential", "", "landmark", 0, ["building_members_club", "building_crazy_golf", "building_pirate_radio"])
	func _add(id: String, label: String, bucket: String, character_id: String, role: String, threshold: int, prerequisites: Array) -> void:
		var profile := UniqueProfile.new()
		profile.bucket = bucket
		profile.character_id = character_id
		profile.patron_id = "aristocrat"
		profile.chain_role = role
		profile.prerequisite_threshold = threshold
		profile.prerequisite_ids = PackedStringArray(prerequisites)
		var structure := Structure.new()
		structure.metadata = [profile]
		items.append(structure)
		summaries.append({"building_id":id, "display_name":label, "category":"unique", "cash_cost":0, "ui_group":"landmarks", "ui_order":items.size()})
	func get_all() -> Array[Structure]: return items
	func get_summary() -> Array: return summaries
	func get_summary_by_index(index: int) -> Dictionary: return summaries[index]
	func get_summary_by_id(id: String) -> Dictionary:
		for summary: Dictionary in summaries:
			if summary.building_id == id: return summary
		return {}
	func get_item_index(id: String) -> int:
		for index in summaries.size():
			if summaries[index].building_id == id: return index
		return -1
	func get_id_by_index(index: int) -> String: return String(summaries[index].building_id) if index >= 0 and index < summaries.size() else ""
	func get_pool_indices(_id: String) -> Array[int]: return []
	func get_bucket_tier_snapshot(bucket: String) -> Dictionary: return tier_projections.get(bucket, {"attained_tier":0, "tier_evidence":[]})

class ParityDemand extends PluginBase:
	func bucket_for_category(category: String) -> String: return category if category in ["residential", "industrial", "commercial"] else ""
	func bucket_display_name(bucket: String) -> String: return "housing" if bucket == "residential" else bucket
	func get_total(_bucket: String) -> float: return 1000.0
	func get_value(_bucket: String) -> float: return 1000.0
	func get_fulfilled(_bucket: String) -> float: return 1000.0
	func can_afford(_structure: Structure) -> bool: return true
	func quote_placement(_structure: Structure) -> Dictionary: return {"ok":true, "bucket_id":"", "cost":0.0, "have":1000.0, "threshold":0.0, "reason":""}

class ParityEconomy extends PluginBase:
	func can_afford_cash(_structure: Structure) -> bool: return true
	func quote_cash(_structure: Structure) -> Dictionary: return {"ok":true, "cost":0, "have":1000}

class ParityLand extends PluginBase:
	func is_allowed(_cell: Vector2i) -> bool: return true

class ParityCharacters extends PluginBase:
	var projections: Dictionary = {}
	func apply_milestone(milestone: Dictionary) -> void: projections = milestone.get("characters", {}).duplicate(true)
	func all_character_ids() -> Array: return projections.keys()
	func is_quest_character(_id: String) -> bool: return true
	func get_state(id: String) -> int: return int(projections.get(id, {}).get("state", 0))
	func get_def(id: String) -> Dictionary: return projections.get(id, {}).duplicate(true)
	func evaluate_character_gate(id: String) -> Dictionary: return projections.get(id, {}).duplicate(true)

class ParityPatrons extends PluginBase:
	var projections: Dictionary = {}
	func apply_milestone(milestone: Dictionary) -> void: projections = milestone.get("patrons", {}).duplicate(true)
	func all_patron_ids() -> Array: return projections.keys()
	func get_state(id: String) -> int: return int(projections.get(id, {}).get("state", 0))
	func get_def(id: String) -> Dictionary:
		var projection: Dictionary = projections.get(id, {})
		return {"patron_id":id, "display_name":projection.get("display_name", id), "character_ids":projection.get("characters", []).map(func(row): return row.get("character_id", "")), "landmark_building_id":projection.get("landmark_building_id", "")}
	func get_progression_snapshot(id: String) -> Dictionary: return projections.get(id, {}).duplicate(true)
