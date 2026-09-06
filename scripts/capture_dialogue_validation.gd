extends SceneTree

const OUTPUT := "res://specs/011-quest-dialogue-foundation/validation/screenshots"
const VIEWPORTS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3840, 2160)]

var _dialogue: Node
var _events := _CaptureEvents.new()
var _characters := _CaptureCharacters.new()
var _manifest: Array = []

func _initialize() -> void:
	call_deferred("_capture_matrix")

func _capture_matrix() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_build_background()
	var dialogue_script: GDScript = load("res://plugins/dialogue/dialogue_plugin.gd")
	_dialogue = dialogue_script.new()
	_dialogue._event_system = _events
	_dialogue._characters = _characters
	root.add_child(_dialogue)
	_dialogue._build_ui()
	_dialogue.set_instant_text_for_test(true)
	for viewport_size in VIEWPORTS:
		root.size = viewport_size
		DisplayServer.window_set_size(viewport_size)
		await _frames(4)
		await _capture_states(viewport_size)
	_write_manifest()
	print("DIALOGUE_CAPTURE success=true files=%d viewports=%d" % [_manifest.size(), VIEWPORTS.size()])
	quit()

func _capture_states(viewport_size: Vector2i) -> void:
	var arrival := _read_json("res://data/events/characters/aristocrat_residential/arrival.json")
	_events.pending[String(arrival.get("event_id", ""))] = true
	_dialogue.open_event_for_test(arrival)
	await _shot(viewport_size, "player-active")
	_dialogue.advance_dialogue()
	await _shot(viewport_size, "npc-active")
	_dialogue.advance_dialogue()
	await _shot(viewport_size, "narration")
	_dialogue.advance_dialogue()
	_dialogue.advance_dialogue()
	await _shot(viewport_size, "choices")
	_dialogue.discard_session_for_test()

	var three_way := _read_json("res://test/scenarios/dialogue/three_way_conversation.json")
	_events.pending[String(three_way.get("event_id", ""))] = true
	_dialogue.open_event_for_test(three_way)
	_dialogue.advance_dialogue()
	await _shot(viewport_size, "three-way-swap")
	_dialogue.discard_session_for_test()

	var long_event := _long_event()
	_events.pending[String(long_event.get("event_id", ""))] = true
	_dialogue.open_event_for_test(long_event)
	for index in range(15):
		_dialogue.advance_dialogue()
	_dialogue._view.set_scroll_state_for_test(120.0, 900.0)
	await _shot(viewport_size, "long-text-scrollback")
	_dialogue.discard_session_for_test()

	var fallback := _fallback_event()
	_events.pending[String(fallback.get("event_id", ""))] = true
	_dialogue.open_event_for_test(fallback)
	await _shot(viewport_size, "missing-art-fallback")
	_dialogue.discard_session_for_test()

func _shot(viewport_size: Vector2i, state: String) -> void:
	await _frames(3)
	var image := root.get_texture().get_image()
	var name := "%dx%d-%s.png" % [viewport_size.x, viewport_size.y, state]
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(name)))
	if error != OK:
		push_error("dialogue_capture_failed: %s error=%s" % [name, error])
		quit(1)
		return
	_manifest.append({"file":name, "viewport":[viewport_size.x, viewport_size.y], "state":state})

func _write_manifest() -> void:
	var file := FileAccess.open(OUTPUT.path_join("manifest.json"), FileAccess.WRITE)
	if file == null:
		push_error("dialogue_capture_manifest_failed")
		quit(1)
		return
	file.store_string(JSON.stringify({
		"feature":"011-quest-dialogue-foundation",
		"instant_text":true,
		"renderer":"normal",
		"captures":_manifest,
	}, "  "))
	file.close()

func _build_background() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#397f73")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	for index in range(16):
		var block := ColorRect.new()
		block.position = Vector2(80 + (index % 8) * 220, 80 + (index / 8) * 580)
		block.size = Vector2(130 + (index % 3) * 24, 90 + (index % 4) * 18)
		block.color = Color("#6f6651") if index % 2 == 0 else Color("#4d5964")
		block.rotation = deg_to_rad(-4.0 + float(index % 5) * 2.0)
		background.add_child(block)

static func _long_event() -> Dictionary:
	var beats: Array = []
	for index in range(18):
		beats.append({
			"type":"speech" if index % 3 != 2 else "narration",
			"speaker":"player" if index % 2 == 0 else "aristocrat_residential",
			"expression":"thoughtful" if index % 2 == 0 else "neutral",
			"text":"Transcript beat %02d carries enough words to wrap neatly while the older conversation remains available above." % index,
		})
		if index % 3 == 2:
			beats[-1].erase("speaker")
			beats[-1].erase("expression")
	return {
		"event_id":"capture_long", "event_type":"dialogue",
		"trigger":{"event":"manual", "character_id":"aristocrat_residential"},
		"payload":{"participants":["player", "aristocrat_residential"], "entry_node_id":"n_start", "nodes":[
			{"node_id":"n_start", "beats":beats, "on_enter":[], "options":[]},
		]},
	}

static func _fallback_event() -> Dictionary:
	return {
		"event_id":"capture_fallback", "event_type":"dialogue",
		"trigger":{"event":"manual", "character_id":"missing_artist"},
		"payload":{"participants":["player", "missing_artist"], "entry_node_id":"n_start", "nodes":[{
			"node_id":"n_start", "beats":[
				{"type":"speech", "speaker":"missing_artist", "expression":"astonished", "text":"The fallback remains deliberate and readable."},
			], "on_enter":[], "options":[],
		}]},
	}

static func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _frames(count: int) -> void:
	for index in count:
		await process_frame

class _CaptureEvents extends PluginBase:
	var pending: Dictionary = {}
	func apply_effects(_effects: Array) -> void: pass
	func acknowledge_dialogue(event_id: String) -> bool:
		if not pending.get(event_id, false): return false
		pending.erase(event_id)
		return true

class _CaptureCharacters extends PluginBase:
	func get_state(_character_id: String) -> int: return 1
	func mark_want_revealed(_character_id: String) -> void: pass
	func get_def(character_id: String) -> Dictionary:
		match character_id:
			"ambrose": return _read_character("res://data/characters/ambrose.json")
			"aristocrat_residential": return _read_character("res://data/characters/aristocrat_residential.json")
			"aristocrat_commercial": return _read_character("res://data/characters/aristocrat_commercial.json")
			"missing_artist": return {"display_name":"Missing Artist", "portrait":"", "expressions":{}, "default_expression":""}
			_: return {}
	func _read_character(path: String) -> Dictionary:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		return parsed if parsed is Dictionary else {}
