extends GutTest

## Unit tests for the Palette plugin (Phase 2 / M2).
##
## The palette collapses the catalog into cyclable build entries — pooled
## variants merge, non-pooled roads hide, and the list is filtered against
## the current cash / demand state. We drive the plugin with stub Catalog /
## Demand / Economy plugins so the tests don't depend on the live scene.

const PalettePluginCls := preload("res://plugins/palette/palette_plugin.gd")

# ── Stubs ─────────────────────────────────────────────────────────────────────

class StubCatalog:
	extends PluginBase
	var structures: Array[Structure] = []
	var summaries: Array = []
	func get_plugin_name() -> String: return "BuildingCatalog"
	func get_all() -> Array[Structure]: return structures
	func get_summary() -> Array: return summaries
	func get_pool_config(_pid: String) -> Dictionary: return {}
	func add_structure(bid: String, category: String, pool_id: String,
			has_road_meta: bool = false, profile_category: String = "") -> int:
		var s := Structure.new()
		s.pool_id = pool_id
		var md: Array[StructureMetadata] = []
		if has_road_meta:
			md.append(RoadMetadata.new())
		if not profile_category.is_empty():
			var p := BuildingProfile.new()
			p.category = profile_category
			p.capacity = 5
			md.append(p)
		s.metadata = md
		structures.append(s)
		summaries.append({
			"building_id": bid,
			"display_name": bid.capitalize(),
			"category": category,
			"pool_id": pool_id,
		})
		return structures.size() - 1

class StubDemand:
	extends PluginBase
	var locked_ids: Dictionary = {}   # building_id → true
	var _catalog: PluginBase
	func get_plugin_name() -> String: return "Demand"
	func can_afford(structure: Structure) -> bool:
		if _catalog == null:
			return true
		var summaries: Array = _catalog.get_summary()
		var structures: Array[Structure] = _catalog.get_all()
		for i in structures.size():
			if structures[i] == structure:
				var bid: String = summaries[i].get("building_id", "")
				return not locked_ids.has(bid)
		return true

class StubEconomy:
	extends PluginBase
	var broke_for_ids: Dictionary = {}
	var _catalog: PluginBase
	func get_plugin_name() -> String: return "Economy"
	func can_afford_cash(structure: Structure) -> bool:
		if _catalog == null:
			return true
		var summaries: Array = _catalog.get_summary()
		var structures: Array[Structure] = _catalog.get_all()
		for i in structures.size():
			if structures[i] == structure:
				var bid: String = summaries[i].get("building_id", "")
				return not broke_for_ids.has(bid)
		return true

# ── Setup ─────────────────────────────────────────────────────────────────────

var _plugin: Node
var _catalog: StubCatalog
var _demand: StubDemand
var _economy: StubEconomy

func before_each() -> void:
	_catalog = StubCatalog.new()
	_demand  = StubDemand.new()
	_economy = StubEconomy.new()
	_demand._catalog = _catalog
	_economy._catalog = _catalog
	_plugin = PalettePluginCls.new()
	add_child(_plugin)
	_plugin._catalog = _catalog
	_plugin._demand  = _demand
	_plugin._economy = _economy

func after_each() -> void:
	if _plugin and is_instance_valid(_plugin):
		_plugin.queue_free()
	_plugin = null
	if _catalog and is_instance_valid(_catalog):
		_catalog.free()
	if _demand and is_instance_valid(_demand):
		_demand.free()
	if _economy and is_instance_valid(_economy):
		_economy.free()

## Re-run the palette's builder after fixture setup — mirrors _plugin_ready
## minus the UI and signal-connection side-effects.
func _rebuild() -> void:
	_plugin._build_entries()
	_plugin._build_ui()
	_plugin._refresh()

# ── Tests ─────────────────────────────────────────────────────────────────────

func test_pool_members_collapse_to_one_entry() -> void:
	_catalog.add_structure("house_a", "generic", "residential_t1", false, "residential")
	_catalog.add_structure("house_b", "generic", "residential_t1", false, "residential")
	_catalog.add_structure("tower",   "generic", "residential_t2", false, "residential")
	_rebuild()

	assert_eq(_plugin._all_entries.size(), 2, "two pools → two entries")
	var by_id: Dictionary = {}
	for e in _plugin._all_entries:
		by_id[e.id] = e
	assert_eq(by_id["residential_t1"].structure_indices.size(), 2, "t1 pool collapses two houses")
	assert_eq(by_id["residential_t2"].structure_indices.size(), 1, "tower stands alone in its pool")

func test_standalone_buildings_are_distinct_entries() -> void:
	_catalog.add_structure("pub",     "unique", "")
	_catalog.add_structure("medical", "unique", "")
	_rebuild()

	assert_eq(_plugin._all_entries.size(), 2, "two standalone → two entries")
	for e in _plugin._all_entries:
		assert_eq(e.structure_indices.size(), 1, "standalone entry has exactly one member")

func test_pooled_road_shown_nonpooled_road_hidden() -> void:
	_catalog.add_structure("road_straight", "road", "road", true)
	_catalog.add_structure("road_corner",   "road", "",     true)
	_catalog.add_structure("road_split",    "road", "",     true)
	_rebuild()

	assert_eq(_plugin._all_entries.size(), 1, "only the pooled road should surface")
	assert_eq(_plugin._all_entries[0].id, "road")

func test_affordable_filter_hides_unaffordable_entries() -> void:
	_catalog.add_structure("house_a", "generic", "residential_t1", false, "residential")
	_catalog.add_structure("tower",   "generic", "residential_t2", false, "residential")
	_rebuild()

	assert_eq(_plugin._affordable_ids.size(), 2, "both affordable to start")

	_demand.locked_ids["tower"] = true
	_plugin._refresh()

	assert_eq(_plugin._affordable_ids.size(), 1, "locking the tower removes t2 entry")
	assert_eq(_plugin._affordable_ids[0], "residential_t1")

func test_pool_stays_visible_if_any_member_affordable() -> void:
	# The pool is a set — losing one model to affordability shouldn't hide the
	# whole pool, only losing all of them.
	_catalog.add_structure("house_a", "generic", "residential_t1", false, "residential")
	_catalog.add_structure("house_b", "generic", "residential_t1", false, "residential")
	_rebuild()

	_demand.locked_ids["house_a"] = true
	_plugin._refresh()

	assert_eq(_plugin._affordable_ids.size(), 1)
	assert_eq(_plugin._affordable_ids[0], "residential_t1", "pool visible while b is still buildable")

	_demand.locked_ids["house_b"] = true
	_plugin._refresh()

	assert_eq(_plugin._affordable_ids.size(), 0, "both members locked → pool disappears")

func test_selection_snaps_when_current_entry_unaffordable() -> void:
	_catalog.add_structure("pub",    "unique", "")
	_catalog.add_structure("shop",   "generic", "commercial_t1", false, "commercial")
	_catalog.add_structure("tower",  "generic", "residential_t2", false, "residential")
	_rebuild()

	# Select pub, then make it unaffordable.
	_plugin._selected_id = "pub"
	_economy.broke_for_ids["pub"] = true
	_plugin._refresh()

	assert_ne(_plugin._selected_id, "pub", "selection moved off the unaffordable entry")
	assert_true(_plugin._selected_id in _plugin._affordable_ids, "selection landed on an affordable entry")

func test_pick_structure_index_returns_pool_member() -> void:
	var a_idx := _catalog.add_structure("house_a", "generic", "residential_t1", false, "residential")
	var b_idx := _catalog.add_structure("house_b", "generic", "residential_t1", false, "residential")
	_rebuild()

	_plugin._selected_id = "residential_t1"

	# 30 rolls — every result must be one of the two members (no index leaks).
	var seen: Dictionary = {}
	for i in 30:
		var picked: int = _plugin.pick_structure_index_for_build()
		assert_true(picked == a_idx or picked == b_idx,
			"pick must be a pool member (got %d)" % picked)
		seen[picked] = true
	# With 30 rolls across 2 members, P(both seen) ≈ 1 - 2 × 0.5^30 ≈ 1.
	assert_eq(seen.size(), 2, "random pick should reach both members over 30 rolls")

func test_cycling_stays_within_affordable() -> void:
	_catalog.add_structure("grass",   "nature", "grass")
	_catalog.add_structure("pavement", "road",  "pavement")
	_catalog.add_structure("road",    "road",   "road", true)
	_rebuild()

	var start_id := _plugin._selected_id
	_plugin.select_next()
	assert_ne(_plugin._selected_id, start_id, "select_next moves selection")

	# Three affordable entries — three select_next rolls should wrap back to start.
	for i in 3:
		_plugin.select_next()
	# After 4 total next() calls on 3 entries, we've wrapped once — selection
	# should equal the entry one step forward from where we started.
	assert_true(_plugin._selected_id in _plugin._affordable_ids,
		"selection stays within affordable list through cycling")
