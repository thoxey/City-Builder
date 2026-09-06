extends GutTest

## Unit tests for DialoguePlugin (post-Inbox refactor).
##
## DialoguePlugin no longer self-queues — Inbox owns the pending list and calls
## open_event() per click. These tests drive the modal directly via the test
## hook `open_event_for_test` and poke internal _on_option_pressed to avoid
## fighting the button tree.

const DialogueCls := preload("res://plugins/dialogue/dialogue_plugin.gd")
const Fixtures := preload("res://test/unit/dialogue/dialogue_fixtures.gd")

var _plugin: Node
var _stub_events: Object
var _stub_chars:  Object
var _saved_map: DataMap

func before_each() -> void:
	_saved_map = GameState.map
	GameState.map = DataMap.new()

	_stub_events = _StubEvents.new()
	_stub_chars  = _StubChars.new()

	_plugin = DialogueCls.new()
	_plugin._event_system = _stub_events
	_plugin._characters   = _stub_chars
	add_child(_plugin)
	_plugin._build_ui()

func after_each() -> void:
	if _plugin and is_instance_valid(_plugin):
		_plugin.queue_free()
	_plugin = null
	GameState.map = _saved_map

# ── Open / close basics ───────────────────────────────────────────────────────

func test_open_event_opens_modal() -> void:
	assert_false(_plugin.is_modal_open())
	_plugin.open_event_for_test(_make_record("a", "character_arrived", "cid_a"))
	assert_true(_plugin.is_modal_open())

func test_open_event_refused_while_modal_open() -> void:
	_plugin.open_event_for_test(_make_record("a", "character_arrived", "cid_a"))
	assert_true(_plugin.is_modal_open())
	# Second call is ignored — first event still active.
	_plugin.open_event_for_test(_make_record("b", "character_arrived", "cid_b"))
	assert_eq(_plugin._current.get("event_id"), "a")

func test_close_hides_modal() -> void:
	_plugin.open_event_for_test(_make_record("x", "character_arrived", "cid"))
	assert_true(_plugin.is_modal_open())
	_plugin._close_current()
	assert_false(_plugin.is_modal_open())

# ── Input suppression ─────────────────────────────────────────────────────────

func test_is_input_suppressed_while_open() -> void:
	assert_false(_plugin.is_input_suppressed())
	_plugin.open_event_for_test(_make_record("x", "character_arrived", "cid"))
	assert_true(_plugin.is_input_suppressed())
	_plugin._close_current()
	assert_false(_plugin.is_input_suppressed())

# ── Tree traversal ────────────────────────────────────────────────────────────

func test_tree_traversal_follows_next_until_close() -> void:
	var rec := _make_record("multi", "character_arrived", "cid_x")
	rec["payload"] = {
		"entry_node_id": "n_start",
		"nodes": [
			{"node_id": "n_start", "body": "start", "options": [
				{"label": "go", "next": "n_middle", "effects": []}
			]},
			{"node_id": "n_middle", "body": "middle", "options": [
				{"label": "end", "next": "", "effects": []}
			]},
		]
	}
	_plugin.open_event_for_test(rec)
	assert_eq(_plugin.current_node_id(), "n_start")

	_reach_choices()
	_plugin._on_option_pressed({"label": "go", "next": "n_middle", "effects": []})
	assert_eq(_plugin.current_node_id(), "n_middle")

	_reach_choices()
	_plugin._on_option_pressed({"label": "end", "next": "", "effects": []})
	assert_false(_plugin.is_modal_open())

# ── Option effects ────────────────────────────────────────────────────────────

func test_option_effects_forwarded_to_event_system() -> void:
	var rec := _make_record("fx", "character_arrived", "cid_x")
	rec["payload"] = {
		"entry_node_id": "n_start",
		"nodes": [
			{"node_id": "n_start", "body": "b", "options": [
				{"label": "do", "next": "", "effects": [{"kind": "set_flag", "target": "f1"}]}
			]},
		]
	}
	_plugin.open_event_for_test(rec)
	_reach_choices()
	_plugin._on_option_pressed({"label": "do", "next": "", "effects": [{"kind": "set_flag", "target": "f1"}]})
	assert_eq(_stub_events.applied_effects.size(), 1)
	assert_eq(_stub_events.applied_effects[0].get("kind"), "set_flag")

# ── Arrival tree → mark_want_revealed ────────────────────────────────────────

func test_arrival_close_calls_mark_want_revealed() -> void:
	var rec := _make_record("arr", "character_arrived", "cid_alice")
	_plugin.open_event_for_test(rec)
	_plugin._close_current()
	assert_eq(_stub_chars.revealed_ids, ["cid_alice"])
	assert_eq(_stub_events.acknowledged_ids, ["arr"])

func test_non_arrival_close_does_not_mark_want_revealed() -> void:
	var rec := _make_record("patron_ready", "patron_landmark_ready", "")
	rec["trigger"]["patron_id"] = "pid_zed"
	_plugin.open_event_for_test(rec)
	_plugin._close_current()
	assert_eq(_stub_chars.revealed_ids, [], "non-arrival trees don't trigger reveal")

func test_headless_resolution_matches_effect_reveal_and_ack_semantics() -> void:
	var record := _make_record("headless", "character_arrived", "cid_alice")
	record["payload"]["nodes"][0]["effects"] = []
	record["payload"]["nodes"][0]["options"][0]["effects"] = [{"kind":"set_flag", "target":"met_alice"}]
	_stub_events.records["headless"] = record
	_stub_events.pending["headless"] = true
	var outcome: Dictionary = _plugin.resolve_pending_event("headless")
	assert_eq(outcome["status"], PlaytestActionResult.STATUS_APPLIED)
	assert_eq(_stub_events.applied_effects, [{"kind":"set_flag", "target":"met_alice"}])
	assert_eq(_stub_chars.revealed_ids, ["cid_alice"])
	assert_eq(_stub_events.acknowledged_ids, ["headless"])
	assert_eq(outcome["details"]["before_state"], "ARRIVED")
	assert_eq(outcome["details"]["after_state"], "WANT_REVEALED")

func test_headless_resolution_rejects_unknown_and_non_pending_events() -> void:
	assert_eq(_plugin.resolve_pending_event("missing")["reason"], PlaytestActionResult.UNKNOWN_DIALOGUE_EVENT)
	var record := _make_record("known", "character_arrived", "cid_alice")
	_stub_events.records["known"] = record
	assert_eq(_plugin.resolve_pending_event("known")["reason"], PlaytestActionResult.DIALOGUE_NOT_PENDING)

func test_visible_entry_rejects_invalid_normalized_record_without_effects_or_acknowledgement() -> void:
	var record := _invalid_new_record("invalid_visible")
	_plugin.open_event_for_test(record)
	assert_false(_plugin.is_modal_open())
	assert_eq(_stub_events.applied_effects, [])
	assert_eq(_stub_events.acknowledged_ids, [])
	assert_eq(_plugin.last_diagnostic_codes(), ["unknown_dialogue_beat_type"])

func test_headless_entry_rejects_invalid_normalized_record_without_effects_or_acknowledgement() -> void:
	var record := _invalid_new_record("invalid_headless")
	_stub_events.records["invalid_headless"] = record
	_stub_events.pending["invalid_headless"] = true
	var outcome: Dictionary = _plugin.resolve_pending_event("invalid_headless")
	assert_eq(outcome["status"], PlaytestActionResult.STATUS_REJECTED)
	assert_eq(outcome["reason"], "invalid_dialogue_event")
	assert_eq(outcome["details"]["diagnostics"][0]["code"], "unknown_dialogue_beat_type")
	assert_eq(_stub_events.applied_effects, [])
	assert_eq(_stub_events.acknowledged_ids, [])

func test_legacy_body_only_visible_and_headless_paths_preserve_semantics_after_normalization() -> void:
	var record := Fixtures.legacy_event("legacy_compat")
	_plugin.open_event_for_test(record)
	assert_eq(_plugin.current_node_id(), "n_start")
	assert_eq(_plugin._body.text, "A legacy body-only node.")
	_reach_choices()
	_plugin._on_option_pressed(record["payload"]["nodes"][0]["options"][0])
	assert_eq(_plugin.current_node_id(), "n_end")
	assert_eq(_plugin._body.text, "The legacy conversation ends.")
	_plugin.advance_dialogue()
	_plugin.advance_dialogue()
	assert_eq(_stub_events.applied_effects.map(func(effect): return effect["target"]), [
		"legacy_node", "legacy_choice", "legacy_terminal",
	])
	assert_eq(_stub_events.acknowledged_ids, ["legacy_compat"])
	assert_eq(_stub_chars.revealed_ids, [Fixtures.BABA])

	_stub_events.applied_effects.clear()
	_stub_events.acknowledged_ids.clear()
	_stub_chars.revealed_ids.clear()
	_stub_events.records["legacy_compat"] = record
	_stub_events.pending["legacy_compat"] = true
	var outcome: Dictionary = _plugin.resolve_pending_event("legacy_compat")
	assert_eq(outcome["status"], PlaytestActionResult.STATUS_APPLIED)
	assert_eq(outcome["details"]["nodes_visited"], 2)
	assert_eq(_stub_events.applied_effects.map(func(effect): return effect["target"]), [
		"legacy_node", "legacy_choice", "legacy_terminal",
	])
	assert_eq(_stub_events.acknowledged_ids, ["legacy_compat"])
	assert_eq(_stub_chars.revealed_ids, [Fixtures.BABA])

func test_choice_is_gated_and_commits_node_then_option_effects_only_when_selected() -> void:
	var record := Fixtures.branching_event("choice_commit")
	_stub_events.pending["choice_commit"] = true
	_plugin.set_instant_text_for_test(true)
	_plugin.open_event_for_test(record)
	assert_eq(_stub_events.applied_effects, [], "opening and reading do not commit")
	assert_eq(_plugin.advance_dialogue()["transition"], "choices_shown")
	assert_eq(_plugin.advance_dialogue()["transition"], "ignored", "surface advance is blocked while choosing")
	_plugin._on_option_pressed(record["payload"]["nodes"][0]["options"][1])
	assert_eq(_stub_events.applied_effects.map(func(effect): return effect["target"]), [
		"branch_node", "branch_bold",
	])
	assert_eq(_plugin.current_node_id(), "n_bold")

func test_selected_reply_appends_as_player_left_before_destination_navigation() -> void:
	var record := Fixtures.branching_event("reply_row")
	_plugin.set_instant_text_for_test(true)
	_plugin.open_event_for_test(record)
	_plugin.advance_dialogue()
	_plugin._on_option_pressed(record["payload"]["nodes"][0]["options"][0])
	var rows: Array = _plugin.transcript_projection()
	assert_eq(rows[1]["kind"], "speech")
	assert_eq(rows[1]["speaker"], "player")
	assert_eq(rows[1]["side"], "left")
	assert_eq(rows[1]["full_text"], "Use the careful plan.")

func test_duplicate_choice_and_duplicate_terminal_completion_are_rejected() -> void:
	var record := Fixtures.branching_event("exactly_once")
	_stub_events.pending["exactly_once"] = true
	_plugin.set_instant_text_for_test(true)
	_plugin.open_event_for_test(record)
	_plugin.advance_dialogue()
	var option: Dictionary = record["payload"]["nodes"][0]["options"][0]
	_plugin._on_option_pressed(option)
	_plugin._on_option_pressed(option)
	assert_eq(_stub_events.applied_effects.map(func(effect): return effect["target"]), [
		"branch_node", "branch_careful",
	])
	var completed: Dictionary = _plugin.advance_dialogue()
	var duplicate: Dictionary = _plugin.advance_dialogue()
	assert_eq(completed["transition"], "conversation_completed")
	assert_eq(duplicate["transition"], "ignored")
	assert_eq(_stub_events.applied_effects.map(func(effect): return effect["target"]), [
		"branch_node", "branch_careful", "careful_terminal",
	])
	assert_eq(_stub_events.acknowledged_ids, ["exactly_once"])

func test_terminal_ready_surface_commit_is_late_and_uses_shared_ordering() -> void:
	var record := Fixtures.valid_event("terminal_commit")
	record["payload"]["nodes"] = [{
		"node_id": "n_start",
		"beats": [{"type":"narration", "text":"A terminal line."}],
		"on_enter": [
			{"kind":"set_flag", "target":"terminal_first"},
			{"kind":"set_flag", "target":"terminal_second"},
		],
		"options": [],
	}]
	_stub_events.pending["terminal_commit"] = true
	_plugin.set_instant_text_for_test(true)
	_plugin.open_event_for_test(record)
	assert_eq(_stub_events.applied_effects, [])
	assert_eq(_plugin.advance_dialogue()["transition"], "conversation_completed")
	assert_eq(_stub_events.applied_effects.map(func(effect): return effect["target"]), [
		"terminal_first", "terminal_second",
	])
	assert_eq(_stub_events.acknowledged_ids, ["terminal_commit"])

# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_record(eid: String, sig: String, cid: String) -> Dictionary:
	return {
		"event_id": eid,
		"event_type": "dialogue",
		"trigger": {"event": sig, "character_id": cid},
		"payload": {
			"entry_node_id": "n_start",
			"nodes": [
				{"node_id": "n_start", "body": "hello", "options": [
					{"label": "Close", "next": "", "effects": []}
				]}
			]
		}
	}

static func _invalid_new_record(eid: String) -> Dictionary:
	return {
		"event_id": eid,
		"event_type": "dialogue",
		"trigger": {"event": "character_arrived", "character_id": "cid_alice"},
		"payload": {
			"participants": ["player", "cid_alice"],
			"entry_node_id": "n_start",
			"nodes": [{
				"node_id": "n_start",
				"beats": [{"type": "aside", "text": "Invalid."}],
				"on_enter": [{"kind": "set_flag", "target": "must_not_apply"}],
				"options": [],
			}],
		},
	}

func _reach_choices() -> void:
	if _plugin.dialogue_mode() == "REVEALING":
		_plugin.advance_dialogue()
	if _plugin.dialogue_mode() == "READY":
		_plugin.advance_dialogue()

class _StubEvents:
	extends PluginBase
	signal event_resolved(record: Dictionary)
	var applied_effects: Array = []
	var records: Dictionary = {}
	var pending: Dictionary = {}
	var acknowledged_ids: Array[String] = []
	func get_plugin_name() -> String: return "_StubEvents"
	func apply_effects(effects: Array) -> void:
		for e in effects: applied_effects.append(e)
	func apply_effect(e: Dictionary) -> bool:
		applied_effects.append(e); return true
	func get_event(event_id: String) -> Dictionary: return records.get(event_id, {}).duplicate(true)
	func is_dialogue_pending(event_id: String) -> bool: return pending.get(event_id, false)
	func acknowledge_dialogue(event_id: String) -> bool:
		if not pending.get(event_id, true): return false
		pending.erase(event_id)
		acknowledged_ids.append(event_id)
		return true

class _StubChars:
	extends PluginBase
	var revealed_ids: Array[String] = []
	var states: Dictionary = {"cid_alice": 1}
	func get_plugin_name() -> String: return "_StubChars"
	func mark_want_revealed(cid: String) -> void:
		revealed_ids.append(cid)
		states[cid] = 2
	func get_state(cid: String) -> int: return int(states.get(cid, 1))
	func get_def(_cid: String) -> Dictionary:
		return {"display_name": "Test", "bio": "", "portrait": ""}
