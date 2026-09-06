extends GutTest

const ExporterCls := preload("res://addons/data_editor_tools/manifest_exporter.gd")

func test_dialogue_and_expression_fields_are_exported_without_schema_rewriting() -> void:
	var manifest: Dictionary = ExporterCls.new().build_manifest()
	var event: Dictionary = _find_by_id(manifest["events"], "event_id", "aristocrat_residential_arrival")
	assert_eq(event["participants"], ["player", "aristocrat_residential"])
	assert_eq(event["entry_node_id"], "n_start")
	assert_eq(event["dialogue_nodes"][0]["beats"].map(func(beat): return beat["type"]), [
		"speech", "speech", "narration", "speech",
	])
	assert_eq(event["body"]["payload"]["nodes"], event["dialogue_nodes"], "round trip remains verbatim")
	var character: Dictionary = _find_by_id(manifest["characters"], "character_id", "aristocrat_residential")
	assert_eq(character["default_expression"], "neutral")
	assert_eq(character["expressions"]["surprised"], "res://data/characters/aristocrat_residential/expressions/line_art/surprised.png")
	var ambrose: Dictionary = _find_by_id(manifest["characters"], "character_id", "ambrose")
	var william: Dictionary = _find_by_id(manifest["characters"], "character_id", "aristocrat_patron")
	assert_eq(ambrose["expressions"].keys(), [
		"neutral", "pleased", "disapproving", "angry", "surprised", "concerned", "thoughtful",
	])
	assert_eq(william["default_expression"], "neutral")
	assert_eq(william.get("expressions", {}).get("angry", ""), "res://data/characters/william/expressions/line_art/angry.png")

func test_legacy_body_dialogue_remains_available_verbatim_in_manifest() -> void:
	var manifest: Dictionary = ExporterCls.new().build_manifest()
	var event: Dictionary = _find_by_id(manifest["events"], "event_id", "aristocrat_commercial_arrival")
	assert_true(event["body"]["payload"]["nodes"][0].has("body"))
	assert_eq(event["dialogue_nodes"][0]["body"], event["body"]["payload"]["nodes"][0]["body"])


func test_opening_tutorial_events_use_only_approved_labelled_placeholders() -> void:
	var manifest: Dictionary = ExporterCls.new().build_manifest()
	var expected := {
		"tutorial_opening_beauty_homes": "AMBROSE PLACEHOLDER: explain that positive Beauty creates Homes demand",
		"tutorial_opening_home_adjacency": "AMBROSE PLACEHOLDER: explain the home adjacency result that was actually observed",
		"tutorial_opening_work_participation": "AMBROSE PLACEHOLDER: explain that residents now work and earn money",
		"tutorial_opening_complete": "AMBROSE PLACEHOLDER: acknowledge the first shop and hand off toward Sir William and more land",
	}
	for event_id in expected:
		var event: Dictionary = _find_by_id(manifest["events"], "event_id", event_id)
		assert_false(event.is_empty(), "%s exported" % event_id)
		if event.is_empty():
			continue
		var nodes: Array = event.get("dialogue_nodes", [])
		assert_eq(nodes.size(), 1, "%s has one placeholder node" % event_id)
		var beats: Array = nodes[0].get("beats", []) if not nodes.is_empty() else []
		assert_eq(beats.size(), 1, "%s has one placeholder beat" % event_id)
		if not beats.is_empty():
			assert_eq(beats[0].get("text", ""), expected[event_id])
			assert_true(String(beats[0].get("text", "")).begins_with("AMBROSE PLACEHOLDER:"))


func test_exported_manifest_contains_all_integrated_line_art_expressions() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/events/_manifest.json"))
	assert_true(parsed is Dictionary, "headless-exported manifest parses")
	if not parsed is Dictionary:
		return
	var expected_states := [
		"neutral", "pleased", "disapproving", "angry", "surprised", "concerned", "thoughtful",
	]
	var manifest: Dictionary = parsed
	for character_id in ["ambrose", "aristocrat_residential", "aristocrat_patron"]:
		var character: Dictionary = _find_by_id(manifest.get("characters", []), "character_id", character_id)
		assert_eq(character.get("default_expression", ""), "neutral", "%s default" % character_id)
		var expressions: Dictionary = character.get("expressions", {})
		for state in expected_states:
			assert_true(expressions.has(state), "%s exports %s" % [character_id, state])
	assert_false(
		_find_by_id(manifest.get("characters", []), "character_id", "aristocrat_commercial")
			.get("expressions", {}).values().any(func(path): return "/line_art/" in String(path)),
		"Flick remains outside this line-art integration",
	)

static func _find_by_id(items: Array, field: String, value: String) -> Dictionary:
	for item_variant in items:
		var item: Dictionary = item_variant
		if String(item.get(field, "")) == value:
			return item
	return {}
