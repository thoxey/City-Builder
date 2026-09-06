extends GutTest

const DialogueCls := preload("res://plugins/dialogue/dialogue_plugin.gd")
const Fixtures := preload("res://test/unit/dialogue/dialogue_fixtures.gd")
const LINE_ART_MANIFEST_PATH := "res://art/ui/dialogue/line-art/manifest.json"
const SEMANTIC_EXPRESSIONS := [
	"neutral", "pleased", "disapproving", "angry", "surprised", "concerned", "thoughtful",
]

var _plugin: Node
var _characters: Object


func before_each() -> void:
	_characters = _StubChars.new()
	_plugin = DialogueCls.new()
	_plugin._event_system = _StubEvents.new()
	_plugin._characters = _characters
	add_child(_plugin)
	_plugin._build_ui()


func after_each() -> void:
	if _plugin and is_instance_valid(_plugin):
		_plugin.queue_free()
	_plugin = null


func test_authored_expression_resolves_before_reveal() -> void:
	var resolved: Dictionary = _plugin.resolve_expression_for_test(Fixtures.BABA, "surprised")
	assert_eq(resolved["presentation_character_id"], Fixtures.BABA)
	assert_eq(resolved["expression"], "surprised")
	assert_eq(resolved["source"], "authored_expression")
	assert_eq(resolved["texture_path"], _StubChars.BABA_PORTRAIT)
	assert_eq(resolved["diagnostics"], [])


func test_unknown_or_missing_expression_uses_declared_default_with_stable_diagnostic() -> void:
	var unknown: Dictionary = _plugin.resolve_expression_for_test(Fixtures.BABA, "furious")
	assert_eq(unknown["expression"], "neutral")
	assert_eq(unknown["source"], "default_expression")
	assert_eq(_codes(unknown), ["unknown_expression"])
	var missing: Dictionary = _plugin.resolve_expression_for_test(Fixtures.BABA, "")
	assert_eq(missing["expression"], "neutral")
	assert_eq(missing["source"], "default_expression")
	assert_eq(_codes(missing), ["missing_dialogue_expression"])


func test_legacy_portrait_is_used_when_expression_metadata_is_absent() -> void:
	var resolved: Dictionary = _plugin.resolve_expression_for_test("legacy_npc", "neutral")
	assert_eq(resolved["source"], "legacy_portrait")
	assert_eq(resolved["texture_path"], _StubChars.BABA_PORTRAIT)
	assert_eq(_codes(resolved), ["unknown_expression", "missing_default_expression"])


func test_missing_art_uses_intentional_fallback_with_stable_diagnostics() -> void:
	var resolved: Dictionary = _plugin.resolve_expression_for_test("missing_npc", "neutral")
	assert_eq(resolved["source"], "missing_art")
	assert_eq(resolved["texture_path"], "res://sprites/ui/dialogue/missing-portrait.png")
	assert_eq(_codes(resolved), ["unknown_expression", "missing_default_expression", "missing_portrait_resource"])
	assert_not_null(resolved["texture"])


func test_semantic_player_maps_to_ambrose_without_authored_ambrose_speaker() -> void:
	var resolved: Dictionary = _plugin.resolve_expression_for_test("player", "thoughtful")
	assert_eq(resolved["semantic_id"], "player")
	assert_eq(resolved["presentation_character_id"], "ambrose")
	assert_eq(resolved["expression"], "thoughtful")
	assert_eq(resolved["source"], "authored_expression")


func test_speaker_portrait_state_is_set_before_first_character_reveals() -> void:
	_plugin.open_event_for_test(Fixtures.two_person_event("portrait_before_reveal"))
	var portrait: Dictionary = _plugin.portrait_projection()
	assert_eq(portrait["player"]["semantic_id"], "player")
	assert_eq(portrait["player"]["expression"], "concerned")
	assert_true(portrait["player"]["active"])
	assert_eq(_plugin.current_row_projection()["visible_characters"], 0)


func test_line_art_manifest_characters_resolve_every_semantic_expression() -> void:
	var manifest := _read_json(LINE_ART_MANIFEST_PATH)
	var characters := _ActualChars.new()
	for entry_variant in manifest.get("characters", []):
		var entry: Dictionary = entry_variant
		characters.definitions[String(entry["character_id"])] = _read_json(String(entry["definition_path"]))
	_plugin._characters = characters

	assert_eq(manifest.get("state_order", []).map(func(state): return state["id"]), SEMANTIC_EXPRESSIONS)
	for entry_variant in manifest.get("characters", []):
		var entry: Dictionary = entry_variant
		var character_id := String(entry["character_id"])
		var semantic_id: String = "player" if character_id == "ambrose" else character_id
		var definition: Dictionary = characters.get_def(character_id)
		assert_eq(definition.get("default_expression"), "neutral", character_id)
		assert_eq(definition.get("expressions"), entry.get("expressions"), character_id)
		for expression in SEMANTIC_EXPRESSIONS:
			var resolved: Dictionary = _plugin.resolve_expression_for_test(semantic_id, expression)
			assert_eq(resolved["expression"], expression, "%s:%s" % [character_id, expression])
			assert_eq(resolved["source"], "authored_expression", "%s:%s" % [character_id, expression])
			assert_eq(resolved["texture_path"], entry["expressions"][expression])
			assert_true(ResourceLoader.exists(String(resolved["texture_path"])))
			assert_eq(resolved["diagnostics"], [])


func test_all_line_art_characters_fall_back_to_neutral_and_keep_legacy_media() -> void:
	var manifest := _read_json(LINE_ART_MANIFEST_PATH)
	var characters := _ActualChars.new()
	for entry_variant in manifest.get("characters", []):
		var entry: Dictionary = entry_variant
		characters.definitions[String(entry["character_id"])] = _read_json(String(entry["definition_path"]))
	_plugin._characters = characters
	var expected_media := {
		"ambrose": {
			"portrait": "res://data/characters/ambrose/portrait.png",
			"talking_videos": [
				"res://data/characters/ambrose/talking_1.ogv",
				"res://data/characters/ambrose/talking_2.ogv",
				"res://data/characters/ambrose/talking_3.ogv",
				"res://data/characters/ambrose/talking_4.ogv",
			],
		},
		"aristocrat_residential": {
			"portrait": "res://data/characters/aristocrat_residential/portrait.png",
			"talking_videos": [
				"res://data/characters/aristocrat_residential/talking_1.ogv",
				"res://data/characters/aristocrat_residential/talking_2.ogv",
				"res://data/characters/aristocrat_residential/talking_3.ogv",
				"res://data/characters/aristocrat_residential/talking_4.ogv",
			],
		},
		"aristocrat_patron": {
			"portrait": "res://data/characters/william/portrait.png",
			"talking_videos": [
				"res://data/characters/william/talking_1.ogv",
				"res://data/characters/william/talking_2.ogv",
				"res://data/characters/william/talking_3.ogv",
				"res://data/characters/william/talking_4.ogv",
			],
		},
	}
	for character_id in expected_media:
		var definition: Dictionary = characters.get_def(character_id)
		assert_eq(definition.get("portrait"), expected_media[character_id]["portrait"])
		assert_eq(definition.get("talking_videos"), expected_media[character_id]["talking_videos"])
		var semantic_id: String = "player" if character_id == "ambrose" else character_id
		var resolved: Dictionary = _plugin.resolve_expression_for_test(semantic_id, "not_a_semantic_state")
		assert_eq(resolved["expression"], "neutral")
		assert_eq(resolved["texture_path"], definition["expressions"]["neutral"])
		assert_eq(_codes(resolved), ["unknown_expression"])


func test_portrait_view_preserves_alpha_over_a_light_medallion() -> void:
	var texture: TextureRect = _plugin._view.control_for_test("player_texture")
	var medallion: ColorRect = _plugin._view.control_for_test("player_medallion")
	assert_eq(texture.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	assert_eq(texture.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_not_null(texture.material)
	assert_not_null(medallion)
	assert_eq(medallion.color, Color("#e7d3ad"))
	assert_not_null(medallion.material)


static func _codes(result: Dictionary) -> Array:
	return result.get("diagnostics", []).map(func(diagnostic): return diagnostic.get("code", ""))


static func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


class _StubEvents:
	extends PluginBase
	func get_plugin_name() -> String: return "_ExpressionEvents"
	func apply_effects(_effects: Array) -> void: pass
	func acknowledge_dialogue(_event_id: String) -> bool: return true


class _StubChars:
	extends PluginBase
	const BABA_PORTRAIT := "res://data/characters/aristocrat_residential/portrait.png"
	const AMBROSE_PORTRAIT := "res://data/characters/ambrose/portrait.png"
	func get_plugin_name() -> String: return "_ExpressionChars"
	func get_def(cid: String) -> Dictionary:
		match cid:
			"ambrose":
				return {
					"character_id": cid,
					"display_name": "Ambrose",
					"portrait": AMBROSE_PORTRAIT,
					"default_expression": "neutral",
					"expressions": {
						"neutral": AMBROSE_PORTRAIT,
						"thoughtful": AMBROSE_PORTRAIT,
						"concerned": AMBROSE_PORTRAIT,
					},
				}
			Fixtures.BABA:
				return {
					"character_id": cid,
					"display_name": "Baba Soyink",
					"portrait": BABA_PORTRAIT,
					"default_expression": "neutral",
					"expressions": {
						"neutral": BABA_PORTRAIT,
						"surprised": BABA_PORTRAIT,
						"pleased": BABA_PORTRAIT,
					},
				}
			Fixtures.FLICK:
				return {
					"character_id": cid,
					"display_name": "Flick",
					"portrait": "res://data/characters/aristocrat_commercial/portrait.png",
					"default_expression": "neutral",
					"expressions": {"neutral": "res://data/characters/aristocrat_commercial/portrait.png"},
				}
			"legacy_npc":
				return {"character_id": cid, "display_name": "Legacy", "portrait": BABA_PORTRAIT}
			"missing_npc":
				return {"character_id": cid, "display_name": "Missing", "portrait": "res://missing/portrait.png"}
			_:
				return {"character_id": cid, "display_name": cid, "portrait": ""}
	func mark_want_revealed(_cid: String) -> void: pass
	func get_state(_cid: String) -> int: return 1


class _ActualChars:
	extends PluginBase
	var definitions: Dictionary = {}
	func get_plugin_name() -> String: return "_ActualExpressionChars"
	func get_def(cid: String) -> Dictionary: return definitions.get(cid, {})
	func mark_want_revealed(_cid: String) -> void: pass
	func get_state(_cid: String) -> int: return 1
