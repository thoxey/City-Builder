class_name DialogueTestFixtures
extends RefCounted

const PLAYER := "player"
const BABA := "aristocrat_residential"
const FLICK := "aristocrat_commercial"


static func valid_event(event_id: String = "dialogue_valid") -> Dictionary:
	return two_person_event(event_id)


static func legacy_event(event_id: String = "dialogue_legacy") -> Dictionary:
	return _event(event_id, [PLAYER, BABA], [
		{
			"node_id": "n_start",
			"body": "A legacy body-only node.",
			"on_enter": [{"kind": "set_flag", "target": "legacy_node"}],
			"options": [{
				"label": "Continue the legacy path.",
				"next": "n_end",
				"effects": [{"kind": "set_flag", "target": "legacy_choice"}],
			}],
		},
		{
			"node_id": "n_end",
			"body": "The legacy conversation ends.",
			"on_enter": [{"kind": "set_flag", "target": "legacy_terminal"}],
			"options": [],
		},
	])


static func malformed_event(event_id: String = "dialogue_malformed") -> Dictionary:
	return {
		"event_id": event_id,
		"event_type": "dialogue",
		"trigger": {"event": "character_arrived", "character_id": BABA},
		"payload": {
			"participants": [PLAYER, BABA, BABA],
			"entry_node_id": "missing_entry",
			"nodes": [
				{
					"node_id": "duplicate",
					"beats": [
						{"type": "speech", "speaker": "unknown", "expression": 7, "text": ""},
						{"type": "aside", "text": "Unknown beat."},
					],
					"options": [{"label": "", "next": "missing_destination", "effects": []}],
				},
				{"node_id": "duplicate", "beats": [], "options": []},
			],
		},
	}


static func two_person_event(event_id: String = "dialogue_two_person") -> Dictionary:
	return _event(event_id, [PLAYER, BABA], [
		{
			"node_id": "n_start",
			"beats": [
				_speech(PLAYER, "concerned", "That radio mast was not here yesterday."),
				_speech(BABA, "surprised", "It arrived under its own steam."),
				{"type": "narration", "text": "A valve warms with a soft orange glow."},
			],
			"on_enter": [],
			"options": [{"label": "Let us find it a frequency.", "next": "n_end", "effects": []}],
		},
		{
			"node_id": "n_end",
			"beats": [_speech(BABA, "pleased", "Now you are talking my language.")],
			"on_enter": [],
			"options": [],
		},
	])


static func three_person_event(event_id: String = "dialogue_three_person") -> Dictionary:
	return _event(event_id, [PLAYER, BABA, FLICK], [
		{
			"node_id": "n_start",
			"beats": [
				_speech(BABA, "neutral", "The transmitter is mine."),
				_speech(FLICK, "concerned", "The frequency is not."),
				_speech(PLAYER, "thoughtful", "Then we shall settle both questions."),
				_speech(BABA, "pleased", "A practical administration at last."),
			],
			"on_enter": [],
			"options": [],
		},
	])


static func branching_event(event_id: String = "dialogue_branching") -> Dictionary:
	return _event(event_id, [PLAYER, BABA], [
		{
			"node_id": "n_start",
			"beats": [_speech(BABA, "neutral", "Which plan shall we use?")],
			"on_enter": [{"kind": "set_flag", "target": "branch_node"}],
			"options": [
				{
					"label": "Use the careful plan.",
					"next": "n_careful",
					"effects": [{"kind": "set_flag", "target": "branch_careful"}],
				},
				{
					"label": "Use the bold plan.",
					"next": "n_bold",
					"effects": [{"kind": "set_flag", "target": "branch_bold"}],
				},
			],
		},
		_terminal_node("n_careful", "The careful plan succeeds.", "careful_terminal"),
		_terminal_node("n_bold", "The bold plan makes excellent radio.", "bold_terminal"),
	])


static func cyclic_event(event_id: String = "dialogue_cyclic") -> Dictionary:
	return _event(event_id, [PLAYER, BABA], [
		{
			"node_id": "n_a",
			"beats": [{"type": "narration", "text": "Cycle A."}],
			"on_enter": [],
			"options": [{"label": "To B", "next": "n_b", "effects": []}],
		},
		{
			"node_id": "n_b",
			"beats": [{"type": "narration", "text": "Cycle B."}],
			"on_enter": [],
			"options": [{"label": "To A", "next": "n_a", "effects": []}],
		},
	], "n_a")


static func long_text_event(event_id: String = "dialogue_long_text") -> Dictionary:
	var sentence := "The transmitter crackles, pauses, and resumes across the valley. "
	return _event(event_id, [PLAYER, BABA], [
		{
			"node_id": "n_start",
			"beats": [_speech(BABA, "neutral", sentence.repeat(24).strip_edges())],
			"on_enter": [],
			"options": [],
		},
	])


static func stress_event(beat_count: int = 200, event_id: String = "dialogue_stress") -> Dictionary:
	var beats: Array = []
	for index in range(beat_count):
		if index % 5 == 4:
			beats.append({"type": "narration", "text": "Narration beat %03d." % index})
		elif index % 2 == 0:
			beats.append(_speech(PLAYER, "neutral", "Player beat %03d." % index))
		else:
			beats.append(_speech(BABA, "neutral", "Counterpart beat %03d." % index))
	return _event(event_id, [PLAYER, BABA], [
		{"node_id": "n_start", "beats": beats, "on_enter": [], "options": []},
	])


static func _event(event_id: String, participants: Array, nodes: Array, entry_node_id: String = "n_start") -> Dictionary:
	return {
		"event_id": event_id,
		"event_type": "dialogue",
		"trigger": {"event": "character_arrived", "character_id": BABA},
		"enabled_if": "",
		"payload": {
			"participants": participants.duplicate(),
			"entry_node_id": entry_node_id,
			"nodes": nodes.duplicate(true),
		},
	}


static func _speech(speaker: String, expression: String, text: String) -> Dictionary:
	return {"type": "speech", "speaker": speaker, "expression": expression, "text": text}


static func _terminal_node(node_id: String, text: String, effect_target: String) -> Dictionary:
	return {
		"node_id": node_id,
		"beats": [{"type": "narration", "text": text}],
		"on_enter": [{"kind": "set_flag", "target": effect_target}],
		"options": [],
	}
