extends GutTest

const DialogueSchema := preload("res://plugins/dialogue/dialogue_schema.gd")
const LINE_ART_MANIFEST_PATH := "res://art/ui/dialogue/line-art/manifest.json"
const SEMANTIC_EXPRESSIONS := [
	"neutral", "pleased", "disapproving", "angry", "surprised", "concerned", "thoughtful",
]

func test_all_authored_dialogue_and_expression_maps_are_valid_with_context() -> void:
	var diagnostics: Array = []
	for path in _json_paths("res://data/events", true):
		if path.ends_with("_manifest.json"):
			continue
		var record := _read_json(path)
		if String(record.get("event_type", "")) != "dialogue":
			continue
		diagnostics.append_array(_validate_event(record, path))
	for path in _json_paths("res://data/characters", false):
		diagnostics.append_array(_validate_character_expressions(_read_json(path), path))
	assert_eq(diagnostics, [], JSON.stringify(diagnostics))

func test_validation_diagnostic_has_stable_file_event_node_and_beat_context() -> void:
	var record := {
		"event_id":"broken",
		"event_type":"dialogue",
		"trigger":{"event":"manual"},
		"payload":{
			"participants":["player", "aristocrat_residential"],
			"entry_node_id":"n_start",
			"nodes":[{"node_id":"n_start", "beats":[{"type":"aside", "text":"No"}], "on_enter":[], "options":[]}],
		},
	}
	var diagnostics := _validate_event(record, "res://fixture/broken.json")
	assert_eq(diagnostics[0]["file"], "res://fixture/broken.json")
	assert_eq(diagnostics[0]["event_id"], "broken")
	assert_eq(diagnostics[0]["node_id"], "n_start")
	assert_eq(diagnostics[0]["beat_index"], 0)
	assert_eq(diagnostics[0]["code"], "unknown_dialogue_beat_type")

func test_line_art_manifest_runtime_assets_are_semantic_black_rgba_with_alpha() -> void:
	var manifest := _read_json(LINE_ART_MANIFEST_PATH)
	assert_eq(manifest.get("state_order", []).map(func(state): return state["id"]), SEMANTIC_EXPRESSIONS)
	assert_eq(manifest.get("format", {}).get("runtime_dimensions").map(func(value): return int(value)), [512, 512])
	assert_eq(manifest.get("format", {}).get("colour_mode"), "RGBA")
	assert_eq(manifest.get("format", {}).get("colour_space"), "sRGB")
	assert_eq(manifest.get("format", {}).get("visible_rgb"), "#000000")
	assert_eq(manifest.get("format", {}).get("alpha"), "straight")
	assert_eq(manifest.get("characters", []).size(), 3)
	for entry_variant in manifest.get("characters", []):
		var entry: Dictionary = entry_variant
		assert_eq(entry.get("expressions", {}).keys(), SEMANTIC_EXPRESSIONS)
		for expression in SEMANTIC_EXPRESSIONS:
			var path := String(entry["expressions"][expression])
			assert_true(FileAccess.file_exists(path), "%s:%s" % [entry["character_id"], expression])
			var image := Image.load_from_file(path)
			assert_eq(image.get_size(), Vector2i(512, 512))
			assert_eq(image.get_format(), Image.FORMAT_RGBA8)
			assert_true(_has_transparency_and_black_visible_rgb(image), path)

func test_flick_is_not_part_of_the_line_art_integration() -> void:
	var manifest := _read_json(LINE_ART_MANIFEST_PATH)
	assert_false(manifest.get("characters", []).any(
		func(entry): return String(entry.get("character_id", "")) == "aristocrat_commercial"
	))
	var flick := _read_json("res://data/characters/aristocrat_commercial.json")
	for path in flick.get("expressions", {}).values():
		assert_false(String(path).contains("/line_art/"))

static func _validate_event(record: Dictionary, path: String) -> Array:
	var result := DialogueSchema.normalize_event(record)
	var contexts: Array = []
	for diagnostic_variant in result.get("diagnostics", []):
		var diagnostic: Dictionary = diagnostic_variant
		var context := {
			"file": path,
			"event_id": String(record.get("event_id", "")),
			"node_id": "",
			"beat_index": -1,
			"code": String(diagnostic.get("code", "")),
		}
		var diagnostic_path := String(diagnostic.get("path", ""))
		var node_match := RegEx.new()
		node_match.compile("payload\\.nodes\\[(\\d+)\\]")
		var node_result := node_match.search(diagnostic_path)
		if node_result:
			var node_index := int(node_result.get_string(1))
			var nodes: Array = record.get("payload", {}).get("nodes", [])
			if node_index >= 0 and node_index < nodes.size():
				context["node_id"] = String((nodes[node_index] as Dictionary).get("node_id", ""))
		var beat_match := RegEx.new()
		beat_match.compile("\\.beats\\[(\\d+)\\]")
		var beat_result := beat_match.search(diagnostic_path)
		if beat_result:
			context["beat_index"] = int(beat_result.get_string(1))
		contexts.append(context)
	return contexts

static func _validate_character_expressions(character: Dictionary, path: String) -> Array:
	var contexts: Array = []
	var expressions: Variant = character.get("expressions", {})
	if not expressions is Dictionary or expressions.is_empty():
		return contexts
	var default_expression := String(character.get("default_expression", ""))
	if default_expression.is_empty() or not expressions.has(default_expression):
		contexts.append({"file":path, "character_id":character.get("character_id", ""), "code":"invalid_default_expression"})
	var names: Array = expressions.keys()
	names.sort()
	for expression in names:
		var resource_path := String(expressions[expression])
		if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
			contexts.append({"file":path, "character_id":character.get("character_id", ""), "expression":expression, "code":"missing_expression_resource"})
	return contexts

static func _has_transparency_and_black_visible_rgb(image: Image) -> bool:
	var has_transparency := false
	var has_visible_pixel := false
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a < 1.0:
				has_transparency = true
			if pixel.a > 0.0:
				has_visible_pixel = true
				if pixel.r > 0.0001 or pixel.g > 0.0001 or pixel.b > 0.0001:
					return false
	return has_transparency and has_visible_pixel

static func _json_paths(root: String, recurse: bool) -> Array[String]:
	var output: Array[String] = []
	_walk(root, recurse, output)
	output.sort()
	return output

static func _walk(root: String, recurse: bool, output: Array[String]) -> void:
	var directory := DirAccess.open(root)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := root.path_join(entry)
		if directory.current_is_dir() and recurse:
			_walk(path, true, output)
		elif entry.ends_with(".json"):
			output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()

static func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
