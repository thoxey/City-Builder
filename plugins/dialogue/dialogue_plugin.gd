extends PluginBase

## DialoguePlugin coordinates normalized traversal, deterministic text reveal, input,
## and semantic completion. DialogueThreadView owns only transient presentation.

const DialogueSchema := preload("res://plugins/dialogue/dialogue_schema.gd")
const DialogueThreadView := preload("res://plugins/dialogue/dialogue_thread_view.gd")
const INVALID_DIALOGUE_EVENT := "invalid_dialogue_event"
const PLAYER_ID := "player"
const PLAYER_PRESENTATION_CHARACTER_ID := "ambrose"
const MISSING_PORTRAIT_PATH := "res://sprites/ui/dialogue/missing-portrait.png"

const MODE_REVEALING := "REVEALING"
const MODE_READY := "READY"
const MODE_CHOOSING := "CHOOSING"
const MODE_DONE := "DONE"

const TRANSITION_REVEAL_COMPLETED := "reveal_completed"
const TRANSITION_BEAT_STARTED := "beat_started"
const TRANSITION_CHOICES_SHOWN := "choices_shown"
const TRANSITION_CONVERSATION_COMPLETED := "conversation_completed"
const TRANSITION_IGNORED := "ignored"

var _event_system: PluginBase
var _characters: PluginBase
var _catalog: PluginBase

var _canvas: CanvasLayer
var _view: Control

# Compatibility-only test/read seam while callers migrate from the body renderer.
var _body: RichTextLabel

var _current: Dictionary = {}
var _current_node_id := ""
var _visited := 0
var _visited_node_ids: Array[String] = []
var _node_committed := false
var _ordered_effects: Array = []
var _last_outcome: Dictionary = {}
var _presentation_enabled := true
var _last_diagnostics: Array = []

var _mode := MODE_DONE
var _beat_index := -1
var _revealed_characters := 0
var _reveal_accumulator := 0.0
var _reveal_characters_per_second := 32.0
var _punctuation_delay_seconds := 0.12
var _instant_text := false


func get_plugin_name() -> String:
	return "Dialogue"


func get_dependencies() -> Array[String]:
	return ["EventSystem", "CharacterSystem"]


func inject(deps: Dictionary) -> void:
	_event_system = deps.get("EventSystem")
	_characters = deps.get("CharacterSystem")


func _plugin_ready() -> void:
	_catalog = PluginManager.get_plugin("BuildingCatalog")
	_build_ui()


func set_presentation_enabled(enabled: bool) -> void:
	_presentation_enabled = enabled
	if not enabled and _canvas:
		_canvas.visible = false


func _build_ui() -> void:
	if _canvas:
		return
	_canvas = CanvasLayer.new()
	_canvas.name = "DialogueCanvas"
	_canvas.layer = 20
	_canvas.visible = false
	add_child(_canvas)

	_view = DialogueThreadView.new()
	_canvas.add_child(_view)
	_view.build()
	_view.surface_activated.connect(_on_surface_activated)
	_view.choice_selected.connect(_on_option_pressed)

	_body = RichTextLabel.new()
	_body.name = "LegacyBodyTestSeam"
	_body.visible = false
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(_body)


func open_event(record: Dictionary) -> void:
	if not _presentation_enabled:
		return
	if is_modal_open():
		push_warning("[Dialogue] open_event called while modal already open; ignoring")
		return
	var normalization := DialogueSchema.normalize_event(record)
	_last_diagnostics = normalization.get("diagnostics", []).duplicate(true)
	if not bool(normalization.get("valid", false)):
		push_warning("[Dialogue] invalid_dialogue_event: event_id=%s diagnostics=%s" % [
			String(record.get("event_id", "")), _diagnostic_codes(_last_diagnostics),
		])
		return

	_current = normalization.get("event", {})
	_current_node_id = ""
	_visited = 0
	_visited_node_ids.clear()
	_node_committed = false
	_ordered_effects.clear()
	_last_outcome = _new_outcome(String(_current.get("event_id", "")))
	_mode = MODE_DONE
	_beat_index = -1
	_revealed_characters = 0
	_reveal_accumulator = 0.0
	_view.clear_transcript()
	_populate_header()
	_canvas.visible = true

	var payload: Dictionary = _current.get("payload", {})
	var entry_id := String(payload.get("entry_node_id", ""))
	_enter_node(entry_id)
	print("[Dialogue] modal_opened: event_id=%s node=%s" % [
		String(_current.get("event_id", "")), entry_id,
	])


func _enter_node(node_id: String) -> bool:
	if _visited >= DialogueSchema.MAX_TRAVERSED_NODES:
		_last_diagnostics = [{
			"code": "dialogue_cycle_limit",
			"path": "traversal",
			"detail": str(DialogueSchema.MAX_TRAVERSED_NODES),
		}]
		_last_outcome["diagnostic"] = "dialogue_cycle_limit"
		_last_outcome["visited_node_ids"] = _visited_node_ids.duplicate()
		_last_outcome["ordered_effects"] = _ordered_effects.duplicate(true)
		discard_session_for_test()
		return false
	var node := _find_node(_current.get("payload", {}), node_id)
	if node.is_empty():
		_last_diagnostics = [{"code": "missing_dialogue_node", "path": "session.node_id", "detail": node_id}]
		_last_outcome["diagnostic"] = "missing_dialogue_node"
		push_warning("[Dialogue] node_not_found: event_id=%s node=%s" % [
			_current.get("event_id", ""), node_id,
		])
		discard_session_for_test()
		return false

	_current_node_id = node_id
	_visited += 1
	_visited_node_ids.append(node_id)
	_last_outcome["visited_node_ids"] = _visited_node_ids.duplicate()
	_node_committed = false
	_beat_index = -1
	_revealed_characters = 0
	_reveal_accumulator = 0.0
	_view.clear_choices()

	_start_next_beat()
	print("[Dialogue] node_entered: node=%s" % node_id)
	return true


func _start_next_beat() -> bool:
	var node := _current_node()
	var beats: Array = node.get("beats", [])
	if _beat_index + 1 >= beats.size():
		return false
	_beat_index += 1
	_revealed_characters = 0
	_reveal_accumulator = 0.0
	var beat: Dictionary = beats[_beat_index]
	var full_text := String(beat.get("text", ""))
	_body.text = full_text

	if String(beat.get("type", "")) == "speech":
		var speaker := String(beat.get("speaker", ""))
		var resolved := _resolve_expression(speaker, String(beat.get("expression", "")))
		_last_diagnostics.append_array(resolved.get("diagnostics", []))
		var side := "left" if speaker == PLAYER_ID else "right"
		var display_name := String(resolved.get("display_name", _display_name_for(speaker)))
		if speaker == PLAYER_ID:
			_view.set_player_portrait(
				speaker, display_name, resolved.get("texture"), String(resolved.get("expression", "")), true
			)
			_view.set_counterpart_active(false)
		else:
			_view.set_player_active(false)
			_view.set_counterpart_portrait(
				speaker, display_name, resolved.get("texture"), String(resolved.get("expression", "")), true
			)
		_view.append_speech_row(speaker, display_name, side, full_text, _instant_text)
	else:
		_view.deactivate_portraits()
		_view.append_narration_row(full_text, _instant_text)

	if _instant_text:
		_revealed_characters = full_text.length()
		_mode = MODE_READY
	else:
		_mode = MODE_REVEALING
	return true


func _process(delta: float) -> void:
	step_reveal(delta)


func step_reveal(delta: float) -> Dictionary:
	if _mode != MODE_REVEALING or delta <= 0.0:
		return _transition_projection(false, TRANSITION_IGNORED)
	var text := _current_beat_text()
	if text.is_empty():
		_complete_reveal()
		return _transition_projection(true, TRANSITION_REVEAL_COMPLETED)

	_reveal_accumulator += delta
	var advanced := false
	while _revealed_characters < text.length():
		var next_character := text.substr(_revealed_characters, 1)
		var cost := 1.0 / maxf(_reveal_characters_per_second, 0.001)
		if next_character in [".", ",", ";", ":", "!", "?"]:
			cost += _punctuation_delay_seconds
		if _reveal_accumulator + 0.000001 < cost:
			break
		_reveal_accumulator -= cost
		_revealed_characters += 1
		advanced = true
		_view.set_current_row_visible_characters(_revealed_characters)

	if _revealed_characters >= text.length():
		_complete_reveal()
		return _transition_projection(true, TRANSITION_REVEAL_COMPLETED)
	return _transition_projection(advanced, TRANSITION_IGNORED)


func _complete_reveal() -> void:
	var text := _current_beat_text()
	_revealed_characters = text.length()
	_reveal_accumulator = 0.0
	_view.set_current_row_visible_characters(_revealed_characters)
	_mode = MODE_READY


func advance_dialogue() -> Dictionary:
	if _current.is_empty() or not is_modal_open():
		return _transition_projection(false, TRANSITION_IGNORED)
	match _mode:
		MODE_REVEALING:
			_complete_reveal()
			return _transition_projection(true, TRANSITION_REVEAL_COMPLETED)
		MODE_READY:
			var node := _current_node()
			var beats: Array = node.get("beats", [])
			if _beat_index + 1 < beats.size():
				_start_next_beat()
				return _transition_projection(true, TRANSITION_BEAT_STARTED)
			var options: Array = node.get("options", [])
			if not options.is_empty():
				_view.show_choices(options)
				_mode = MODE_CHOOSING
				return _transition_projection(true, TRANSITION_CHOICES_SHOWN)
			var event_id := String(_current.get("event_id", ""))
			var node_id := _current_node_id
			var beat_index := _beat_index
			if not _commit_current_node({}):
				return _transition_projection(false, TRANSITION_IGNORED)
			_close_current()
			return _transition_projection_with_ids(
				true, TRANSITION_CONVERSATION_COMPLETED, event_id, node_id, beat_index
			)
		MODE_CHOOSING, MODE_DONE:
			return _transition_projection(false, TRANSITION_IGNORED)
		_:
			return _transition_projection(false, TRANSITION_IGNORED)


func _on_option_pressed(option: Dictionary) -> void:
	if _mode != MODE_CHOOSING or _current.is_empty():
		return
	var label := String(option.get("label", ""))
	var next_id := String(option.get("next", ""))
	_view.clear_choices()
	_view.set_player_active(true)
	_view.set_counterpart_active(false)
	_view.append_speech_row(PLAYER_ID, _display_name_for(PLAYER_ID), "left", label, true)
	if not _commit_current_node(option):
		return
	print("[Dialogue] option_selected: event_id=%s label=\"%s\" next=%s" % [
		String(_current.get("event_id", "")), label, next_id,
	])
	if next_id.is_empty():
		_close_current()
	else:
		_enter_node(next_id)


func _close_current() -> void:
	if _current.is_empty():
		return
	var record := _current
	var event_id := String(record.get("event_id", ""))
	print("[Dialogue] modal_closed: event_id=%s nodes_visited=%d" % [event_id, _visited])
	var completion := _complete_semantics(record)
	_last_outcome["event_id"] = event_id
	_last_outcome["visited_node_ids"] = _visited_node_ids.duplicate()
	_last_outcome["ordered_effects"] = _ordered_effects.duplicate(true)
	_last_outcome["arrival_transition"] = completion.get("arrival_transition", {})
	_last_outcome["acknowledged"] = completion.get("acknowledged", false)
	_current = {}
	_current_node_id = ""
	_beat_index = -1
	_revealed_characters = 0
	_reveal_accumulator = 0.0
	_mode = MODE_DONE
	_node_committed = false
	_canvas.visible = false


func discard_session_for_test() -> void:
	_current = {}
	_current_node_id = ""
	_beat_index = -1
	_revealed_characters = 0
	_reveal_accumulator = 0.0
	_mode = MODE_DONE
	_node_committed = false
	if _canvas:
		_canvas.visible = false
	if _view:
		_view.clear_transcript()


func resolve_pending_event(event_id: String) -> Dictionary:
	if _event_system == null:
		return PlaytestActionResult.rejected(PlaytestActionResult.UNKNOWN_DIALOGUE_EVENT)
	var record: Dictionary = _event_system.get_event(event_id)
	if record.is_empty() or String(record.get("event_type", "")) != "dialogue":
		return PlaytestActionResult.rejected(
			PlaytestActionResult.UNKNOWN_DIALOGUE_EVENT, {"event_id": event_id}
		)
	if not _event_system.is_dialogue_pending(event_id):
		return PlaytestActionResult.rejected(
			PlaytestActionResult.DIALOGUE_NOT_PENDING, {"event_id": event_id}
		)
	var normalization := DialogueSchema.normalize_event(record)
	_last_diagnostics = normalization.get("diagnostics", []).duplicate(true)
	if not bool(normalization.get("valid", false)):
		return PlaytestActionResult.rejected(INVALID_DIALOGUE_EVENT, {
			"event_id": event_id,
			"diagnostics": _last_diagnostics.duplicate(true),
		})
	record = normalization.get("event", {})

	var trigger: Dictionary = record.get("trigger", {})
	var character_id := String(trigger.get("character_id", ""))
	var before_state := int(_characters.get_state(character_id)) if _characters != null and not character_id.is_empty() else -1
	var traversal := DialogueSchema.first_option_path(record)
	var visited_node_ids: Array = traversal.get("visited_node_ids", [])
	var ordered_effects: Array = []
	for node_id_variant in visited_node_ids:
		var node := DialogueSchema.find_node(record, String(node_id_variant))
		var options: Array = node.get("options", [])
		var option: Dictionary = options[0] if not options.is_empty() else {}
		_apply_ordered_effects(node.get("on_enter", []), option.get("effects", []), ordered_effects)
	if not bool(traversal.get("valid", false)):
		return PlaytestActionResult.rejected(INVALID_DIALOGUE_EVENT, {
			"event_id": event_id,
			"diagnostics": traversal.get("diagnostics", []).duplicate(true),
			"visited_node_ids": visited_node_ids.duplicate(),
			"ordered_effects": ordered_effects.duplicate(true),
			"acknowledged": false,
		})

	var completion := _complete_semantics(record)
	var after_state := int(_characters.get_state(character_id)) if _characters != null and not character_id.is_empty() else -1
	return PlaytestActionResult.applied({
		"event_id": event_id,
		"character_id": character_id,
		"before_state": _character_state_name(before_state),
		"after_state": _character_state_name(after_state),
		"nodes_visited": visited_node_ids.size(),
		"visited_node_ids": visited_node_ids.duplicate(),
		"ordered_effects": ordered_effects.duplicate(true),
		"arrival_transition": completion.get("arrival_transition", {}),
		"acknowledged": completion.get("acknowledged", false),
	})


func _complete_semantics(record: Dictionary) -> Dictionary:
	var trigger: Dictionary = record.get("trigger", {})
	var character_id := String(trigger.get("character_id", ""))
	var before_state := int(_characters.get_state(character_id)) if _characters != null and not character_id.is_empty() else -1
	if String(trigger.get("event", "")) == "character_arrived":
		if not character_id.is_empty() and _characters and _characters.has_method("mark_want_revealed"):
			_characters.mark_want_revealed(character_id)
	var acknowledged := false
	if _event_system and _event_system.has_method("acknowledge_dialogue"):
		acknowledged = bool(_event_system.acknowledge_dialogue(String(record.get("event_id", ""))))
	var after_state := int(_characters.get_state(character_id)) if _characters != null and not character_id.is_empty() else -1
	return {
		"arrival_transition": {
			"character_id": character_id,
			"before_state": _character_state_name(before_state),
			"after_state": _character_state_name(after_state),
		},
		"acknowledged": acknowledged,
	}


func _commit_current_node(option: Dictionary) -> bool:
	if _current.is_empty() or _node_committed:
		return false
	var node := _current_node()
	if node.is_empty():
		return false
	_apply_ordered_effects(node.get("on_enter", []), option.get("effects", []), _ordered_effects)
	_node_committed = true
	_last_outcome["ordered_effects"] = _ordered_effects.duplicate(true)
	return true


func _apply_ordered_effects(node_effects: Array, option_effects: Array, ordered_effects: Array) -> void:
	for effects in [node_effects, option_effects]:
		for effect_variant in effects:
			if not effect_variant is Dictionary:
				continue
			var effect: Dictionary = (effect_variant as Dictionary).duplicate(true)
			ordered_effects.append(effect)
			if _event_system:
				_event_system.apply_effects([effect])


static func _new_outcome(event_id: String) -> Dictionary:
	return {
		"event_id": event_id,
		"visited_node_ids": [],
		"ordered_effects": [],
		"arrival_transition": {},
		"acknowledged": false,
		"diagnostic": "",
	}


func _populate_header() -> void:
	var trigger: Dictionary = _current.get("trigger", {})
	var counterpart := String(trigger.get("character_id", ""))
	if counterpart.is_empty():
		counterpart = String(trigger.get("patron_id", ""))
	var title := _display_name_for(counterpart)
	if title.is_empty():
		title = String(_current.get("event_id", "Conversation"))
	_view.set_header(title, "Conversation")


func _display_name_for(semantic_id: String) -> String:
	if semantic_id == PLAYER_ID:
		var player_definition: Dictionary = _characters.get_def(PLAYER_PRESENTATION_CHARACTER_ID) if _characters else {}
		return String(player_definition.get("display_name", "Player"))
	if not semantic_id.is_empty() and _characters:
		var definition: Dictionary = _characters.get_def(semantic_id)
		var display_name := String(definition.get("display_name", ""))
		if not display_name.is_empty():
			return display_name
	return semantic_id


func _resolve_expression(semantic_id: String, authored_expression: String) -> Dictionary:
	var diagnostics: Array = []
	var character_id := PLAYER_PRESENTATION_CHARACTER_ID if semantic_id == PLAYER_ID else semantic_id
	var definition: Dictionary = _characters.get_def(character_id) if _characters else {}
	var display_name := String(definition.get("display_name", character_id))
	var expressions: Dictionary = definition.get("expressions", {}) if definition.get("expressions", {}) is Dictionary else {}
	var chosen_expression := authored_expression
	var texture_path := ""
	var source := ""

	if authored_expression.is_empty():
		diagnostics.append({"code": "missing_dialogue_expression", "participant": semantic_id})
	elif expressions.has(authored_expression):
		var authored_path := String(expressions.get(authored_expression, ""))
		if _resource_texture_exists(authored_path):
			texture_path = authored_path
			source = "authored_expression"
	else:
		diagnostics.append({"code": "unknown_expression", "participant": semantic_id, "expression": authored_expression})

	if texture_path.is_empty():
		var default_expression := String(definition.get("default_expression", ""))
		var default_path := String(expressions.get(default_expression, "")) if not default_expression.is_empty() else ""
		if not default_expression.is_empty() and _resource_texture_exists(default_path):
			chosen_expression = default_expression
			texture_path = default_path
			source = "default_expression"
		else:
			diagnostics.append({"code": "missing_default_expression", "participant": semantic_id})

	if texture_path.is_empty():
		var portrait_path := String(definition.get("portrait", ""))
		if _resource_texture_exists(portrait_path):
			texture_path = portrait_path
			source = "legacy_portrait"
		else:
			diagnostics.append({"code": "missing_portrait_resource", "participant": semantic_id})
			texture_path = MISSING_PORTRAIT_PATH
			source = "missing_art"

	return {
		"semantic_id": semantic_id,
		"presentation_character_id": character_id,
		"display_name": display_name,
		"expression": chosen_expression,
		"texture_path": texture_path,
		"texture": _load_texture_or_placeholder(texture_path),
		"source": source,
		"diagnostics": diagnostics,
	}


func _load_texture_or_placeholder(path: String) -> Texture2D:
	if _resource_texture_exists(path):
		var texture: Texture2D = load(path)
		if texture:
			return texture
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.28, 0.24, 0.3, 1.0))
	for index in range(64):
		image.set_pixel(index, index, Color(0.9, 0.65, 0.3, 1.0))
		image.set_pixel(63 - index, index, Color(0.9, 0.65, 0.3, 1.0))
	return ImageTexture.create_from_image(image)


static func _resource_texture_exists(path: String) -> bool:
	return not path.is_empty() and ResourceLoader.exists(path)


func _current_node() -> Dictionary:
	return _find_node(_current.get("payload", {}), _current_node_id)


func _current_beat_text() -> String:
	var beats: Array = _current_node().get("beats", [])
	if _beat_index < 0 or _beat_index >= beats.size():
		return ""
	return String((beats[_beat_index] as Dictionary).get("text", ""))


func _find_node(payload: Dictionary, node_id: String) -> Dictionary:
	var nodes_by_id: Variant = payload.get("nodes_by_id", {})
	if nodes_by_id is Dictionary and (nodes_by_id as Dictionary).has(node_id):
		return (nodes_by_id as Dictionary).get(node_id, {})
	for node_variant in payload.get("nodes", []):
		if node_variant is Dictionary and String((node_variant as Dictionary).get("node_id", "")) == node_id:
			return node_variant
	return {}


func _input(event: InputEvent) -> void:
	if not is_modal_open() or not _is_advance_key_or_action(event):
		return
	var result := advance_dialogue()
	if bool(result.get("accepted", false)):
		get_viewport().set_input_as_handled()


func _on_surface_activated(event: InputEvent) -> void:
	if not is_modal_open() or not _is_surface_pointer_press(event):
		return
	var result := advance_dialogue()
	if bool(result.get("accepted", false)):
		get_viewport().set_input_as_handled()


func accept_input_event_for_test(event: InputEvent, target: String, already_handled: bool = false) -> Dictionary:
	if already_handled:
		return _input_projection(_transition_projection(false, TRANSITION_IGNORED), false)
	if target in ["choice", "scrollbar", "return_latest", "interactive"]:
		return _input_projection(_transition_projection(false, TRANSITION_IGNORED), true)
	var accepted_source := _is_surface_pointer_press(event) or _is_advance_key_or_action(event)
	if not accepted_source:
		return _input_projection(_transition_projection(false, TRANSITION_IGNORED), false)
	return _input_projection(advance_dialogue(), true)


func is_modal_open() -> bool:
	return _canvas != null and _canvas.visible


func is_input_suppressed() -> bool:
	return _presentation_enabled and is_modal_open()


func open_event_for_test(record: Dictionary) -> void:
	open_event(record)


func current_node_id() -> String:
	return _current_node_id


func current_beat_index() -> int:
	return _beat_index


func dialogue_mode() -> String:
	return _mode


func transcript_projection() -> Array:
	return _view.transcript_projection() if _view else []


func current_row_projection() -> Dictionary:
	var rows := transcript_projection()
	return rows[-1] if not rows.is_empty() else {}


func dialogue_button_texts() -> Array:
	return _view.button_texts() if _view else []


func portrait_projection() -> Dictionary:
	return _view.portrait_projection() if _view else {}


func resolve_expression_for_test(semantic_id: String, authored_expression: String) -> Dictionary:
	return _resolve_expression(semantic_id, authored_expression)


func last_diagnostic_codes() -> Array:
	return _diagnostic_codes(_last_diagnostics)


func last_outcome_for_test() -> Dictionary:
	return _last_outcome.duplicate(true)


func set_instant_text_for_test(enabled: bool) -> void:
	_instant_text = enabled


func set_reveal_rate_for_test(characters_per_second: float, punctuation_delay: float = 0.12) -> void:
	_reveal_characters_per_second = maxf(characters_per_second, 0.001)
	_punctuation_delay_seconds = maxf(punctuation_delay, 0.0)


func step_reveal_for_test(delta: float) -> Dictionary:
	return step_reveal(delta)


func _transition_projection(accepted: bool, transition: String) -> Dictionary:
	return _transition_projection_with_ids(
		accepted,
		transition,
		String(_current.get("event_id", "")),
		_current_node_id,
		_beat_index
	)


func _transition_projection_with_ids(
	accepted: bool,
	transition: String,
	event_id: String,
	node_id: String,
	beat_index: int
) -> Dictionary:
	return {
		"accepted": accepted,
		"transition": transition,
		"event_id": event_id,
		"node_id": node_id,
		"beat_index": beat_index,
		"mode": _mode,
	}


static func _input_projection(transition: Dictionary, consumed: bool) -> Dictionary:
	var result := transition.duplicate(true)
	result["consumed"] = consumed
	return result


static func _is_surface_pointer_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return event.pressed
	return false


static func _is_advance_key_or_action(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
	if event is InputEventAction and event.pressed and event.action == &"dialogue_advance":
		return true
	return event.is_action_pressed(&"dialogue_advance", false, true)


static func _diagnostic_codes(diagnostics: Array) -> Array:
	return diagnostics.map(func(diagnostic): return diagnostic.get("code", ""))


static func _character_state_name(state: int) -> String:
	match state:
		0: return "NOT_ARRIVED"
		1: return "ARRIVED"
		2: return "WANT_REVEALED"
		3: return "SATISFIED"
		4: return "CONTRIBUTES_TO_LANDMARK"
		_: return "UNKNOWN(%d)" % state
