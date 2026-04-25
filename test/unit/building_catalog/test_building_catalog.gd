extends GutTest

## Unit tests for the BuildingCatalog plugin (Phase 3a / M0).
## Each test writes fixture JSON into a user://-rooted temp dir, points a fresh
## plugin instance at it, and asserts on the loader's public surface.
##
## Fixtures use known-good model paths from res://models/ so ResourceLoader.exists()
## resolves. The loader's private _load_dir is driven via the public ensure_loaded(dir)
## entry point to keep tests black-box.

const BuildingCatalogPlugin := preload("res://plugins/building_catalog/building_catalog_plugin.gd")

const FIXTURE_ROOT := "user://test_fixtures/building_catalog"
const GOOD_MODEL_A := "res://models/road-straight.glb"
const GOOD_MODEL_B := "res://models/grass.glb"
const GOOD_MODEL_C := "res://models/road-corner.glb"

var _plugin: BuildingCatalogPlugin

func before_each() -> void:
	_wipe_fixture_dir()
	DirAccess.make_dir_recursive_absolute(FIXTURE_ROOT)
	_plugin = BuildingCatalogPlugin.new()

func after_each() -> void:
	if _plugin != null and is_instance_valid(_plugin):
		_plugin.free()
	_plugin = null
	_wipe_fixture_dir()

# ── Tests ─────────────────────────────────────────────────────────────────────

func test_loads_all_json_in_dir() -> void:
	_write_json("a.json", _minimal_building("alpha", GOOD_MODEL_A))
	_write_json("b.json", _minimal_building("bravo", GOOD_MODEL_B))
	_write_json("c.json", _minimal_building("charlie", GOOD_MODEL_C))

	_plugin.ensure_loaded(FIXTURE_ROOT)

	assert_eq(_plugin.get_all().size(), 3, "expected all 3 JSON files to load")
	assert_not_null(_plugin.get_by_id("alpha"))
	assert_not_null(_plugin.get_by_id("bravo"))
	assert_not_null(_plugin.get_by_id("charlie"))

func test_stable_index_across_reloads() -> void:
	_write_json("a.json", _minimal_building("pub",      GOOD_MODEL_A))
	_write_json("b.json", _minimal_building("grass",    GOOD_MODEL_B))
	_write_json("c.json", _minimal_building("road",     GOOD_MODEL_C))

	_plugin.ensure_loaded(FIXTURE_ROOT)
	var first_pub:   int = _plugin.get_item_index("pub")
	var first_grass: int = _plugin.get_item_index("grass")
	var first_road:  int = _plugin.get_item_index("road")

	# Fresh instance, same fixture directory — ordering must not drift.
	_plugin.free()
	_plugin = BuildingCatalogPlugin.new()
	_plugin.ensure_loaded(FIXTURE_ROOT)

	assert_eq(_plugin.get_item_index("pub"),   first_pub,   "pub index drifted across reload")
	assert_eq(_plugin.get_item_index("grass"), first_grass, "grass index drifted across reload")
	assert_eq(_plugin.get_item_index("road"),  first_road,  "road index drifted across reload")

func test_profile_type_dispatch() -> void:
	var profiles := [
		{"type": "BuildingMetadata"},
		{
			"type": "BuildingProfile",
			"category": "commercial",
			"capacity": 42,
			"active_start": 9.0,
			"active_end": 17.0,
		},
		{
			"type": "RoadMetadata",
			"road_type": 1,
			"connections": [[1, 0], [0, 1]],
			"speed_limit": 50,
			"lanes": 2,
		},
	]
	var data := _minimal_building("mixed", GOOD_MODEL_A)
	data["profiles"] = profiles
	_write_json("mixed.json", data)

	_plugin.ensure_loaded(FIXTURE_ROOT)

	var s: Structure = _plugin.get_by_id("mixed")
	assert_not_null(s, "structure should have loaded")
	assert_eq(s.metadata.size(), 3, "expected 3 profile entries")
	assert_true(s.find_metadata(BuildingMetadata) != null, "BuildingMetadata missing")
	assert_true(s.find_metadata(BuildingProfile) != null, "BuildingProfile missing")
	var road: RoadMetadata = s.find_metadata(RoadMetadata) as RoadMetadata
	assert_not_null(road, "RoadMetadata missing")
	assert_eq(road.road_type,   1,  "road_type not parsed")
	assert_eq(road.speed_limit, 50, "speed_limit not parsed")
	assert_eq(road.lanes,       2,  "lanes not parsed")
	assert_eq(road.connections.size(), 2, "connections not parsed")
	assert_eq(road.connections[0], Vector2i(1, 0))

	var bp: BuildingProfile = s.find_metadata(BuildingProfile) as BuildingProfile
	assert_eq(bp.category, "commercial")
	assert_eq(bp.capacity, 42)
	assert_eq(bp.active_start, 9.0)
	assert_eq(bp.active_end,   17.0)

func test_missing_model_path_errors() -> void:
	_write_json("ok.json",  _minimal_building("good_one", GOOD_MODEL_A))
	var bad := _minimal_building("bad_one", "res://models/does_not_exist.glb")
	_write_json("bad.json", bad)

	# Silence the expected push_error so it doesn't fail the GUT run.
	_plugin.ensure_loaded(FIXTURE_ROOT)

	assert_eq(_plugin.get_all().size(), 1, "only the valid JSON should load")
	assert_not_null(_plugin.get_by_id("good_one"))
	assert_null(_plugin.get_by_id("bad_one"), "bad model path must be skipped")

func test_duplicate_building_id_errors() -> void:
	_write_json("first.json",  _minimal_building("dupe", GOOD_MODEL_A))
	_write_json("second.json", _minimal_building("dupe", GOOD_MODEL_B))
	_write_json("third.json",  _minimal_building("unique", GOOD_MODEL_C))

	_plugin.ensure_loaded(FIXTURE_ROOT)

	# Duplicates collapse to one; the unique stays; total = 2.
	assert_eq(_plugin.get_all().size(), 2, "duplicate id should not produce two entries")
	assert_not_null(_plugin.get_by_id("dupe"))
	assert_not_null(_plugin.get_by_id("unique"))

func test_save_schema_defaults() -> void:
	# DataStructure should default to empty building_id; the loader uses a
	# non-empty building_id as the single signal that an entry is restorable.
	var ds := DataStructure.new()
	assert_eq(ds.building_id, "", "new DataStructure starts with empty building_id")
	assert_eq(ds.position, Vector2i.ZERO, "new DataStructure position defaults to (0,0)")
	assert_eq(ds.orientation, 0, "new DataStructure orientation defaults to 0")
	assert_true(ds.footprint_cells.is_empty(), "new DataStructure has no footprint cells")

	var fresh := DataMap.new()
	assert_true(fresh.structures.is_empty(), "fresh DataMap has no structures")

func test_get_pool_returns_matching_buildings() -> void:
	var a := _minimal_building("house_a", GOOD_MODEL_A); a["pool_id"] = "residential_t1"
	var b := _minimal_building("house_b", GOOD_MODEL_B); b["pool_id"] = "residential_t1"
	var c := _minimal_building("tower",   GOOD_MODEL_C); c["pool_id"] = "residential_t2"
	var d := _minimal_building("shop",    GOOD_MODEL_A); d["pool_id"] = ""
	_write_json("a.json", a); _write_json("b.json", b)
	_write_json("c.json", c); _write_json("d.json", d)

	_plugin.ensure_loaded(FIXTURE_ROOT)

	var t1 := _plugin.get_pool("residential_t1")
	assert_eq(t1.size(), 2, "t1 pool should contain both houses")
	var t1_ids: Array = []
	for s in t1:
		for bid in ["house_a", "house_b"]:
			if _plugin.get_by_id(bid) == s:
				t1_ids.append(bid)
	assert_eq(t1_ids.size(), 2, "t1 pool members should be house_a and house_b")

	var t2 := _plugin.get_pool("residential_t2")
	assert_eq(t2.size(), 1, "t2 pool should contain only the tower")

	var empty := _plugin.get_pool("nonexistent")
	assert_eq(empty.size(), 0, "unknown pool returns empty array")

	# Indices round-trip too.
	var t1_idx := _plugin.get_pool_indices("residential_t1")
	assert_eq(t1_idx.size(), 2, "pool_indices matches pool membership")

func test_pool_config_loads_from_sidecar_dir() -> void:
	_write_json("house.json", _minimal_building("house", GOOD_MODEL_A))

	# Sidecar directory prefixed with _ — catalog walks it separately.
	var pools_dir := FIXTURE_ROOT.path_join("_pools")
	DirAccess.make_dir_recursive_absolute(pools_dir)
	var pool_data := {
		"pool_id": "residential_t1",
		"bucket": "residential",
		"tier": 1,
		"demand_threshold": 12,
		"demand_per_unit": 4,
	}
	var path := pools_dir.path_join("residential_t1.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(pool_data))
	f.close()

	_plugin.ensure_loaded(FIXTURE_ROOT)

	var cfg: Dictionary = _plugin.get_pool_config("residential_t1")
	assert_false(cfg.is_empty(), "pool config should have loaded")
	assert_eq(int(cfg.get("demand_threshold", -1)), 12, "threshold round-trips")
	assert_eq(int(cfg.get("demand_per_unit", -1)),  4,  "per_unit round-trips")
	assert_eq(int(cfg.get("tier", -1)),             1,  "tier round-trips")

	# Missing pool returns empty dict, not null.
	var missing: Dictionary = _plugin.get_pool_config("nope")
	assert_true(missing.is_empty(), "unknown pool_id returns empty dict")

	# The sidecar JSON must NOT appear as a structure.
	assert_null(_plugin.get_by_id("residential_t1"), "pool config must not register as a building")
	assert_eq(_plugin.get_all().size(), 1, "only the real building loads")

# ── Helpers ───────────────────────────────────────────────────────────────────

func _minimal_building(bid: String, model_path: String) -> Dictionary:
	return {
		"building_id": bid,
		"display_name": bid.capitalize(),
		"description": "",
		"model_path": model_path,
		"model_scale": 1.0,
		"model_offset": [0, 0, 0],
		"model_rotation_y": 0.0,
		"footprint": [[0, 0]],
		"category": "generic",
		"profiles": [],
		"tags": [],
	}

func _write_json(filename: String, data: Dictionary) -> void:
	var path := FIXTURE_ROOT.path_join(filename)
	var f := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(f, "failed to open fixture file for write: %s" % path)
	f.store_string(JSON.stringify(data))
	f.close()

func _wipe_fixture_dir() -> void:
	var dir := DirAccess.open(FIXTURE_ROOT)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var full := FIXTURE_ROOT.path_join(name)
			if dir.current_is_dir():
				OS.move_to_trash(ProjectSettings.globalize_path(full))
			else:
				dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()
