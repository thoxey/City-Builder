class_name DialogueSchema
extends RefCounted

## Pure authored-data normalization for visible and headless dialogue traversal.
## The returned event is always detached from the EventSystem-owned source record.

const MAX_TRAVERSED_NODES := 128
const PLAYER_ID := "player"


static func normalize_event(source: Dictionary) -> Dictionary:
	var diagnostics: Array = []
	var normalized: Dictionary = source.duplicate(true)
	var source_payload: Dictionary = source.get("payload", {}) if source.get("payload", {}) is Dictionary else {}
	var payload: Dictionary = source_payload.duplicate(true)
	normalized["payload"] = payload

	var source_nodes: Array = source_payload.get("nodes", []) if source_payload.get("nodes", []) is Array else []
	var is_legacy := _is_legacy_graph(source_nodes)
	var participants: Array = _normalize_participants(source, source_payload, is_legacy, diagnostics)
	payload["participants"] = participants

	var normalized_nodes: Array = []
	var nodes_by_id: Dictionary = {}
	var option_destinations: Array = []
	for node_index in range(source_nodes.size()):
		var source_node_variant: Variant = source_nodes[node_index]
		if not source_node_variant is Dictionary:
			_add_diagnostic(diagnostics, "invalid_dialogue_node", "payload.nodes[%d]" % node_index)
			continue
		var node: Dictionary = _normalize_node(
			source_node_variant as Dictionary,
			node_index,
			participants,
			diagnostics,
			option_destinations
		)
		normalized_nodes.append(node)
		var node_id := String(node.get("node_id", ""))
		if node_id.is_empty():
			_add_diagnostic(diagnostics, "missing_dialogue_node_id", "payload.nodes[%d].node_id" % node_index)
		elif nodes_by_id.has(node_id):
			_add_diagnostic(diagnostics, "duplicate_dialogue_node", "payload.nodes[%d].node_id" % node_index, node_id)
		else:
			nodes_by_id[node_id] = node

	payload["nodes"] = normalized_nodes
	payload["nodes_by_id"] = nodes_by_id

	var entry_node_id := String(source_payload.get("entry_node_id", ""))
	payload["entry_node_id"] = entry_node_id
	if entry_node_id.is_empty() or not nodes_by_id.has(entry_node_id):
		_add_diagnostic(diagnostics, "missing_dialogue_node", "payload.entry_node_id", entry_node_id)

	for destination in option_destinations:
		var next_id := String(destination.get("next", ""))
		if not next_id.is_empty() and not nodes_by_id.has(next_id):
			_add_diagnostic(
				diagnostics,
				"missing_dialogue_destination",
				String(destination.get("path", "")),
				next_id
			)

	return {
		"valid": diagnostics.is_empty(),
		"event": normalized,
		"diagnostics": diagnostics,
	}


static func first_option_path(normalized_event: Dictionary, max_nodes: int = MAX_TRAVERSED_NODES) -> Dictionary:
	var diagnostics: Array = []
	var visited_node_ids: Array = []
	var payload: Dictionary = normalized_event.get("payload", {})
	var node_id := String(payload.get("entry_node_id", ""))
	var nodes_by_id: Dictionary = payload.get("nodes_by_id", {})
	var limit := maxi(1, max_nodes)

	while not node_id.is_empty() and visited_node_ids.size() < limit:
		if not nodes_by_id.has(node_id):
			_add_diagnostic(diagnostics, "missing_dialogue_node", "traversal.node_id", node_id)
			break
		visited_node_ids.append(node_id)
		var node: Dictionary = nodes_by_id[node_id]
		var options: Array = node.get("options", [])
		if options.is_empty():
			node_id = ""
			break
		var option: Dictionary = options[0]
		node_id = String(option.get("next", ""))

	if not node_id.is_empty() and diagnostics.is_empty() and visited_node_ids.size() >= limit:
		_add_diagnostic(diagnostics, "dialogue_cycle_limit", "traversal", str(limit))

	return {
		"valid": diagnostics.is_empty(),
		"visited_node_ids": visited_node_ids,
		"terminal_node_id": visited_node_ids[-1] if node_id.is_empty() and not visited_node_ids.is_empty() else "",
		"diagnostics": diagnostics,
	}


static func find_node(normalized_event: Dictionary, node_id: String) -> Dictionary:
	var payload: Dictionary = normalized_event.get("payload", {})
	return payload.get("nodes_by_id", {}).get(node_id, {})


static func _normalize_participants(
	source: Dictionary,
	payload: Dictionary,
	is_legacy: bool,
	diagnostics: Array
) -> Array:
	var participants: Array = []
	var has_authored_participants := payload.has("participants")
	if has_authored_participants and payload.get("participants") is Array:
		participants = (payload.get("participants") as Array).duplicate()
	else:
		participants = _inferred_legacy_participants(source)
		if not is_legacy:
			_add_diagnostic(diagnostics, "missing_dialogue_participants", "payload.participants")
		return participants

	var seen: Dictionary = {}
	var has_player := false
	for index in range(participants.size()):
		var participant := String(participants[index])
		participants[index] = participant
		if participant.is_empty():
			_add_diagnostic(diagnostics, "empty_dialogue_participant", "payload.participants[%d]" % index)
			continue
		if seen.has(participant):
			_add_diagnostic(diagnostics, "duplicate_dialogue_participant", "payload.participants[%d]" % index, participant)
		else:
			seen[participant] = true
		if participant == PLAYER_ID:
			has_player = true
	if not has_player:
		_add_diagnostic(diagnostics, "missing_player_participant", "payload.participants")
	if participants.size() < 2 or participants.size() > 3:
		_add_diagnostic(diagnostics, "dialogue_participant_count", "payload.participants", str(participants.size()))
	return participants


static func _normalize_node(
	source_node: Dictionary,
	node_index: int,
	participants: Array,
	diagnostics: Array,
	option_destinations: Array
) -> Dictionary:
	var node: Dictionary = source_node.duplicate(true)
	var node_path := "payload.nodes[%d]" % node_index
	var beats: Array = []
	if source_node.has("beats"):
		if source_node.get("beats") is Array:
			var source_beats: Array = source_node.get("beats")
			for beat_index in range(source_beats.size()):
				var beat_variant: Variant = source_beats[beat_index]
				if not beat_variant is Dictionary:
					_add_diagnostic(diagnostics, "invalid_dialogue_beat", "%s.beats[%d]" % [node_path, beat_index])
					continue
				beats.append(_normalize_beat(
					beat_variant as Dictionary,
					"%s.beats[%d]" % [node_path, beat_index],
					participants,
					diagnostics
				))
		else:
			_add_diagnostic(diagnostics, "invalid_dialogue_beats", "%s.beats" % node_path)
	else:
		var body: Variant = source_node.get("body", "")
		if body is String and not String(body).strip_edges().is_empty():
			beats.append({"type": "narration", "text": String(body)})

	if beats.is_empty():
		_add_diagnostic(diagnostics, "empty_dialogue_node", node_path)
	node["beats"] = beats

	var effects: Variant = source_node.get("on_enter", [])
	if not effects is Array:
		_add_diagnostic(diagnostics, "invalid_dialogue_effects", "%s.on_enter" % node_path)
		effects = []
	node["on_enter"] = (effects as Array).duplicate(true)

	var options: Array = []
	var source_options_variant: Variant = source_node.get("options", [])
	if source_options_variant is Array:
		var source_options: Array = source_options_variant
		for option_index in range(source_options.size()):
			var option_variant: Variant = source_options[option_index]
			if not option_variant is Dictionary:
				_add_diagnostic(diagnostics, "invalid_dialogue_option", "%s.options[%d]" % [node_path, option_index])
				continue
			var option: Dictionary = _normalize_option(
				option_variant as Dictionary,
				"%s.options[%d]" % [node_path, option_index],
				diagnostics
			)
			options.append(option)
			option_destinations.append({
				"next": option.get("next", ""),
				"path": "%s.options[%d].next" % [node_path, option_index],
			})
	else:
		_add_diagnostic(diagnostics, "invalid_dialogue_options", "%s.options" % node_path)
	node["options"] = options
	return node


static func _normalize_beat(source_beat: Dictionary, path: String, participants: Array, diagnostics: Array) -> Dictionary:
	var beat_type := String(source_beat.get("type", ""))
	match beat_type:
		"speech":
			var speaker := String(source_beat.get("speaker", ""))
			if speaker.is_empty():
				_add_diagnostic(diagnostics, "missing_dialogue_speaker", "%s.speaker" % path)
			elif speaker != PLAYER_ID and not participants.has(speaker):
				_add_diagnostic(diagnostics, "unknown_dialogue_speaker", "%s.speaker" % path, speaker)
			var expression_variant: Variant = source_beat.get("expression", null)
			var expression := ""
			if expression_variant == null or (expression_variant is String and String(expression_variant).is_empty()):
				_add_diagnostic(diagnostics, "missing_dialogue_expression", "%s.expression" % path)
			elif not expression_variant is String:
				_add_diagnostic(diagnostics, "invalid_dialogue_expression", "%s.expression" % path)
			else:
				expression = String(expression_variant)
			var text := _normalized_text(source_beat, path, diagnostics)
			return {"type": "speech", "speaker": speaker, "expression": expression, "text": text}
		"narration":
			return {"type": "narration", "text": _normalized_text(source_beat, path, diagnostics)}
		_:
			_add_diagnostic(diagnostics, "unknown_dialogue_beat_type", "%s.type" % path, beat_type)
			return source_beat.duplicate(true)


static func _normalize_option(source_option: Dictionary, path: String, diagnostics: Array) -> Dictionary:
	var label := String(source_option.get("label", ""))
	if label.strip_edges().is_empty():
		_add_diagnostic(diagnostics, "empty_dialogue_option_label", "%s.label" % path)
	var effects: Variant = source_option.get("effects", [])
	if not effects is Array:
		_add_diagnostic(diagnostics, "invalid_dialogue_effects", "%s.effects" % path)
		effects = []
	return {
		"label": label,
		"next": String(source_option.get("next", "")),
		"effects": (effects as Array).duplicate(true),
	}


static func _normalized_text(source: Dictionary, path: String, diagnostics: Array) -> String:
	var value: Variant = source.get("text", "")
	var text := String(value) if value is String else ""
	if text.strip_edges().is_empty():
		_add_diagnostic(diagnostics, "empty_dialogue_beat_text", "%s.text" % path)
	return text


static func _inferred_legacy_participants(source: Dictionary) -> Array:
	var trigger: Dictionary = source.get("trigger", {})
	var counterpart := String(trigger.get("character_id", ""))
	if counterpart.is_empty():
		counterpart = String(trigger.get("patron_id", ""))
	if counterpart.is_empty():
		counterpart = String(source.get("event_id", "dialogue"))
	return [PLAYER_ID, counterpart]


static func _is_legacy_graph(nodes: Array) -> bool:
	if nodes.is_empty():
		return false
	for node in nodes:
		if node is Dictionary and (node as Dictionary).has("beats"):
			return false
	return true


static func _add_diagnostic(diagnostics: Array, code: String, path: String, detail: String = "") -> void:
	var diagnostic := {"code": code, "path": path}
	if not detail.is_empty():
		diagnostic["detail"] = detail
	diagnostics.append(diagnostic)
