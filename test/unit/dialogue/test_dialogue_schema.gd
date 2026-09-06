extends GutTest

const DialogueSchema := preload("res://plugins/dialogue/dialogue_schema.gd")
const Fixtures := preload("res://test/unit/dialogue/dialogue_fixtures.gd")


func test_normalizes_participants_and_ordered_speech_narration_beats() -> void:
	var source := Fixtures.valid_event()
	var result: Dictionary = DialogueSchema.normalize_event(source)
	assert_true(result["valid"])
	assert_eq(result["diagnostics"], [])
	assert_eq(result["event"]["payload"]["participants"], [Fixtures.PLAYER, Fixtures.BABA])
	var beats: Array = result["event"]["payload"]["nodes_by_id"]["n_start"]["beats"]
	assert_eq(beats.map(func(beat): return beat["type"]), ["speech", "speech", "narration"])
	assert_eq(beats[0]["speaker"], Fixtures.PLAYER)
	assert_eq(beats[1]["speaker"], Fixtures.BABA)
	assert_false(beats[2].has("speaker"))


func test_legacy_body_projects_to_one_narration_beat_and_infers_participants() -> void:
	var result: Dictionary = DialogueSchema.normalize_event(Fixtures.legacy_event())
	assert_true(result["valid"])
	assert_eq(result["event"]["payload"]["participants"], [Fixtures.PLAYER, Fixtures.BABA])
	assert_eq(result["event"]["payload"]["nodes_by_id"]["n_start"]["beats"], [
		{"type": "narration", "text": "A legacy body-only node."},
	])


func test_participant_contract_reports_stable_ordered_diagnostics() -> void:
	var source := Fixtures.valid_event()
	source["payload"]["participants"] = [Fixtures.BABA, Fixtures.BABA, ""]
	var result: Dictionary = DialogueSchema.normalize_event(source)
	assert_false(result["valid"])
	assert_eq(_codes(result), [
		"duplicate_dialogue_participant",
		"empty_dialogue_participant",
		"missing_player_participant",
	])


func test_missing_new_format_participants_is_rejected() -> void:
	var source := Fixtures.valid_event()
	source["payload"].erase("participants")
	var result: Dictionary = DialogueSchema.normalize_event(source)
	assert_false(result["valid"])
	assert_eq(_codes(result), ["missing_dialogue_participants"])


func test_unknown_type_speaker_and_empty_text_are_diagnosed() -> void:
	var source := Fixtures.valid_event()
	source["payload"]["nodes"][0]["beats"] = [
		{"type": "aside", "text": "Wrong tag."},
		{"type": "speech", "speaker": "stranger", "expression": "neutral", "text": "Hello."},
		{"type": "speech", "speaker": Fixtures.PLAYER, "expression": "neutral", "text": ""},
		{"type": "narration", "text": ""},
	]
	var result: Dictionary = DialogueSchema.normalize_event(source)
	assert_false(result["valid"])
	assert_eq(_codes(result), [
		"unknown_dialogue_beat_type",
		"unknown_dialogue_speaker",
		"empty_dialogue_beat_text",
		"empty_dialogue_beat_text",
	])


func test_missing_or_non_string_speech_fields_are_diagnosed() -> void:
	var source := Fixtures.valid_event()
	source["payload"]["nodes"][0]["beats"] = [
		{"type": "speech", "text": "No speaker or expression."},
		{"type": "speech", "speaker": Fixtures.BABA, "expression": 4, "text": "Bad expression."},
	]
	var result: Dictionary = DialogueSchema.normalize_event(source)
	assert_false(result["valid"])
	assert_eq(_codes(result), [
		"missing_dialogue_speaker",
		"missing_dialogue_expression",
		"invalid_dialogue_expression",
	])


func test_duplicate_and_missing_node_ids_are_diagnosed_without_overwriting_first_node() -> void:
	var source := Fixtures.valid_event()
	source["payload"]["nodes"] = [
		{"node_id": "n_start", "body": "First.", "options": []},
		{"node_id": "n_start", "body": "Duplicate.", "options": []},
		{"node_id": "", "body": "Missing.", "options": []},
	]
	var result: Dictionary = DialogueSchema.normalize_event(source)
	assert_false(result["valid"])
	assert_eq(_codes(result), ["duplicate_dialogue_node", "missing_dialogue_node_id"])
	assert_eq(result["event"]["payload"]["nodes_by_id"]["n_start"]["beats"][0]["text"], "First.")


func test_empty_node_missing_entry_and_missing_destinations_are_diagnosed() -> void:
	var source := Fixtures.valid_event()
	source["payload"]["entry_node_id"] = "gone"
	source["payload"]["nodes"] = [{
		"node_id": "n_start",
		"beats": [],
		"options": [{"label": "Nowhere", "next": "gone", "effects": []}],
	}]
	var result: Dictionary = DialogueSchema.normalize_event(source)
	assert_false(result["valid"])
	assert_eq(_codes(result), [
		"empty_dialogue_node",
		"missing_dialogue_node",
		"missing_dialogue_destination",
	])


func test_options_require_non_empty_labels_and_array_effects() -> void:
	var source := Fixtures.valid_event()
	source["payload"]["nodes"][0]["options"] = [
		{"label": "", "next": "n_end", "effects": {}},
	]
	var result: Dictionary = DialogueSchema.normalize_event(source)
	assert_false(result["valid"])
	assert_eq(_codes(result), ["empty_dialogue_option_label", "invalid_dialogue_effects"])


func test_normalized_output_is_detached_from_authored_source() -> void:
	var source := Fixtures.valid_event()
	var result: Dictionary = DialogueSchema.normalize_event(source)
	result["event"]["payload"]["participants"][0] = "changed"
	result["event"]["payload"]["nodes"][0]["beats"][0]["text"] = "Changed."
	assert_eq(source["payload"]["participants"][0], Fixtures.PLAYER)
	assert_ne(source["payload"]["nodes"][0]["beats"][0]["text"], "Changed.")


func test_first_option_path_reports_cycle_limit_after_exactly_128_nodes() -> void:
	var normalized: Dictionary = DialogueSchema.normalize_event(Fixtures.cyclic_event())["event"]
	var traversal: Dictionary = DialogueSchema.first_option_path(normalized)
	assert_false(traversal["valid"])
	assert_eq(traversal["visited_node_ids"].size(), DialogueSchema.MAX_TRAVERSED_NODES)
	assert_eq(traversal["visited_node_ids"].slice(0, 4), ["n_a", "n_b", "n_a", "n_b"])
	assert_eq(_codes(traversal), ["dialogue_cycle_limit"])


func test_first_option_path_reports_missing_node_without_fabricating_terminal_success() -> void:
	var normalized: Dictionary = DialogueSchema.normalize_event(Fixtures.valid_event())["event"]
	normalized["payload"]["nodes_by_id"].erase("n_end")
	var traversal: Dictionary = DialogueSchema.first_option_path(normalized)
	assert_false(traversal["valid"])
	assert_eq(traversal["visited_node_ids"], ["n_start"])
	assert_eq(_codes(traversal), ["missing_dialogue_node"])


static func _codes(result: Dictionary) -> Array:
	return result.get("diagnostics", []).map(func(diagnostic): return diagnostic.get("code", ""))
