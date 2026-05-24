extends GutTest

## Unit tests for DialoguePlugin (post-Inbox refactor).
##
## DialoguePlugin no longer self-queues — Inbox owns the pending list and calls
## open_event() per click. These tests drive the modal directly via the test
## hook `open_event_for_test` and poke internal _on_option_pressed to avoid
## fighting the button tree.

const DialogueCls := preload("res://plugins/dialogue/dialogue_plugin.gd")

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

	_plugin._on_option_pressed({"label": "go", "next": "n_middle", "effects": []})
	assert_eq(_plugin.current_node_id(), "n_middle")

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
	_plugin._on_option_pressed({"label": "do", "next": "", "effects": [{"kind": "set_flag", "target": "f1"}]})
	assert_eq(_stub_events.applied_effects.size(), 1)
	assert_eq(_stub_events.applied_effects[0].get("kind"), "set_flag")

# ── Arrival tree → mark_want_revealed ────────────────────────────────────────

func test_arrival_close_calls_mark_want_revealed() -> void:
	var rec := _make_record("arr", "character_arrived", "cid_alice")
	_plugin.open_event_for_test(rec)
	_plugin._close_current()
	assert_eq(_stub_chars.revealed_ids, ["cid_alice"])

func test_non_arrival_close_does_not_mark_want_revealed() -> void:
	var rec := _make_record("patron_ready", "patron_landmark_ready", "")
	rec["trigger"]["patron_id"] = "pid_zed"
	_plugin.open_event_for_test(rec)
	_plugin._close_current()
	assert_eq(_stub_chars.revealed_ids, [], "non-arrival trees don't trigger reveal")

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

class _StubEvents:
	extends PluginBase
	signal event_resolved(record: Dictionary)
	var applied_effects: Array = []
	func get_plugin_name() -> String: return "_StubEvents"
	func apply_effects(effects: Array) -> void:
		for e in effects: applied_effects.append(e)
	func apply_effect(e: Dictionary) -> bool:
		applied_effects.append(e); return true

class _StubChars:
	extends PluginBase
	var revealed_ids: Array[String] = []
	func get_plugin_name() -> String: return "_StubChars"
	func mark_want_revealed(cid: String) -> void:
		revealed_ids.append(cid)
	func get_def(_cid: String) -> Dictionary:
		return {"display_name": "Test", "bio": "", "portrait": ""}
