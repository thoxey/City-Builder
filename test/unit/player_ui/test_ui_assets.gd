extends GutTest

func test_manifest_runtime_assets_exist_and_match_declared_dimensions() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/ui/build-menu/manifest.json"))
	assert_eq(manifest.get("version"), 4)
	for record in manifest.get("assets", []):
		for runtime in record.get("runtime", []):
			var path := "res://" + String(runtime.path)
			assert_true(FileAccess.file_exists(path), "missing runtime asset: %s" % path)
			var image := Image.load_from_file(path)
			assert_eq(Vector2i(image.get_width(), image.get_height()), Vector2i(int(runtime.dimensions[0]), int(runtime.dimensions[1])), "dimension mismatch: %s" % path)

func test_catalog_icon_keys_resolve_to_runtime_entries_or_controls() -> void:
	for path in _json_paths("res://data/buildings"):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_true(data.has("ui_group"), "missing ui_group: %s" % path)
		assert_true(data.has("ui_order"), "missing ui_order: %s" % path)
		assert_true(data.has("ui_icon"), "missing ui_icon: %s" % path)
		var icon := String(data.get("ui_icon", "missing-artwork"))
		var exists := FileAccess.file_exists("res://sprites/ui/build-menu/entries/%s.png" % icon) or FileAccess.file_exists("res://sprites/ui/build-menu/controls/%s.png" % icon)
		assert_true(exists, "missing icon derivative: %s" % icon)

func _json_paths(root: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null: return result
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		var path := root.path_join(name)
		if dir.current_is_dir(): result.append_array(_json_paths(path))
		elif name.ends_with(".json"): result.append(path)
		name = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result
