extends GutTest

## Focused contract tests for feature 020's authored ground-treatment policy.
## Fixtures are loaded through the catalogue's public API so these assertions cover
## both parsing and the summary projection consumed by Builder.

const BuildingCatalogPlugin := preload("res://plugins/building_catalog/building_catalog_plugin.gd")

const FIXTURE_ROOT := "user://test_fixtures/building_catalog_ground_treatment"
const GOOD_MODEL := "res://models/grass.glb"

var _plugin: BuildingCatalogPlugin


func before_each() -> void:
	_wipe_fixture_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE_ROOT))
	_plugin = BuildingCatalogPlugin.new()


func after_each() -> void:
	if _plugin != null and is_instance_valid(_plugin):
		_plugin.free()
	_plugin = null
	_wipe_fixture_dir()


func test_absent_ground_treatment_defaults_to_replace() -> void:
	_write_json("absent.json", _minimal_building("absent_policy"))

	_plugin.ensure_loaded(FIXTURE_ROOT)

	var summary := _plugin.get_summary_by_id("absent_policy")
	assert_false(summary.is_empty(), "fixture should remain present in the catalogue")
	assert_eq(
		String(summary.get("ground_treatment", "")),
		"replace",
		"omitting ground_treatment must preserve the existing ground-replacement behavior"
	)


func test_grass_underlay_projects_to_catalogue_summary() -> void:
	var data := _minimal_building("underlay_policy")
	data["ground_treatment"] = "grass_underlay"
	_write_json("underlay.json", data)

	_plugin.ensure_loaded(FIXTURE_ROOT)

	var summary := _plugin.get_summary_by_id("underlay_policy")
	assert_false(summary.is_empty(), "valid ground treatment must not reject the building")
	assert_eq(
		String(summary.get("ground_treatment", "")),
		"grass_underlay",
		"Builder must receive the authored treatment through the catalogue summary"
	)


func test_invalid_ground_treatment_reports_content_error_and_falls_back_to_replace() -> void:
	var data := _minimal_building("invalid_policy")
	data["ground_treatment"] = "floating_carpet"
	_write_json("invalid.json", data)

	# BuildingCatalog is expected to push an `invalid_ground_treatment` content error.
	# This GUT version cannot reliably intercept engine push_error() calls, so stderr from
	# the focused run supplies the diagnostic evidence while fallback remains asserted.
	_plugin.ensure_loaded(FIXTURE_ROOT)

	var summary := _plugin.get_summary_by_id("invalid_policy")
	assert_false(summary.is_empty(), "an invalid policy should use the safe fallback")
	assert_eq(
		String(summary.get("ground_treatment", "")),
		"replace",
		"unknown authored values must never enable an underlay implicitly"
	)


func _minimal_building(building_id: String) -> Dictionary:
	return {
		"building_id": building_id,
		"display_name": building_id.capitalize(),
		"description": "",
		"model_path": GOOD_MODEL,
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
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "failed to open fixture file for write: %s" % path)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()


func _wipe_fixture_dir() -> void:
	var dir := DirAccess.open(FIXTURE_ROOT)
	if dir == null:
		return
	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if filename != "." and filename != ".." and not dir.current_is_dir():
			dir.remove(filename)
		filename = dir.get_next()
	dir.list_dir_end()
