extends GutTest

## Unit tests for InboxPlugin.
##
## Inbox intercepts dialogue events from EventSystem and stages them in a
## pending list. Clicking an item hands the record to Dialogue.open_event().
## Tests use stubs for EventSystem + Dialogue + CharacterSystem; UI tree is
## built but never interacted with via real buttons.

const InboxCls := preload("res://plugins/inbox/inbox_plugin.gd")

var _plugin: Node
var _stub_events:    Object
var _stub_dialogue:  Object
var _stub_chars:     Object
var _stub_patrons:   Object

func before_each() -> void:
	_stub_events   = _StubEvents.new()
	_stub_dialogue = _StubDialogue.new()
	_stub_chars    = _StubChars.new()
	_stub_patrons  = _StubPatrons.new()

	_plugin = InboxCls.new()
	_plugin._event_system = _stub_events
	_plugin._dialogue     = _stub_dialogue
	_plugin._characters   = _stub_chars
	_plugin._patrons      = _stub_patrons
	add_child(_plugin)
	_plugin._build_ui()

func after_each() -> void:
	if _plugin and is_instance_valid(_plugin):
		_plugin.queue_free()
	_plugin = null

# ── Queuing ───────────────────────────────────────────────────────────────────

func test_dialogue_event_queues() -> void:
	assert_eq(_plugin.pending_size(), 0)
	_plugin.push_for_test(_make_record("a", "dialogue", "cid_a"))
	assert_eq(_plugin.pending_size(), 1)
	assert_eq(_plugin.pending_event_ids(), ["a"])

func test_three_events_preserve_order() -> void:
	_plugin.push_for_test(_make_record("a", "dialogue", "cid_a"))
	_plugin.push_for_test(_make_record("b", "dialogue", "cid_b"))
	_plugin.push_for_test(_make_record("c", "dialogue", "cid_c"))
	assert_eq(_plugin.pending_event_ids(), ["a", "b", "c"])

func test_duplicate_event_id_is_not_queued_twice() -> void:
	_plugin.push_for_test(_make_record("a", "dialogue", "cid_a"))
	_plugin.push_for_test(_make_record("a", "dialogue", "cid_a"))
	assert_eq(_plugin.pending_event_ids(), ["a"])

func test_presentation_disabled_still_tracks_semantic_pending_queue() -> void:
	_plugin.set_presentation_enabled(false)
	_plugin.push_for_test(_make_record("a", "dialogue", "cid_a"))
	assert_eq(_plugin.pending_event_ids(), ["a"])

func test_non_dialogue_events_ignored() -> void:
	_plugin.push_for_test(_make_record("n1", "newspaper", ""))
	_plugin.push_for_test(_make_record("t1", "notification", ""))
	assert_eq(_plugin.pending_size(), 0)

# ── Click → open ──────────────────────────────────────────────────────────────

func test_open_item_removes_from_pending_and_calls_dialogue() -> void:
	_plugin.push_for_test(_make_record("a", "dialogue", "cid_a"))
	_plugin.push_for_test(_make_record("b", "dialogue", "cid_b"))
	_plugin.open_for_test(0)
	assert_eq(_plugin.pending_size(), 1)
	assert_eq(_plugin.pending_event_ids(), ["b"])
	assert_eq(_stub_dialogue.opened_ids, ["a"])

func test_open_item_only_removes_inbox_projection_not_event_system_pending_truth() -> void:
	_stub_events.pending["a"] = true
	_plugin.push_for_test(_make_record("a", "dialogue", "cid_a"))
	_plugin.open_for_test(0)
	assert_eq(_plugin.pending_event_ids(), [])
	assert_true(_stub_events.is_dialogue_pending("a"))

func test_open_item_out_of_range_is_no_op() -> void:
	_plugin.push_for_test(_make_record("a", "dialogue", "cid_a"))
	_plugin.open_for_test(5)
	assert_eq(_plugin.pending_size(), 1)
	assert_eq(_stub_dialogue.opened_ids, [])

func test_open_second_item_then_first() -> void:
	_plugin.push_for_test(_make_record("a", "dialogue", "cid_a"))
	_plugin.push_for_test(_make_record("b", "dialogue", "cid_b"))
	_plugin.push_for_test(_make_record("c", "dialogue", "cid_c"))
	# Player picks the middle one first.
	_plugin.open_for_test(1)
	assert_eq(_plugin.pending_event_ids(), ["a", "c"])
	assert_eq(_stub_dialogue.opened_ids, ["b"])
	# Then the first remaining.
	_plugin.open_for_test(0)
	assert_eq(_plugin.pending_event_ids(), ["c"])
	assert_eq(_stub_dialogue.opened_ids, ["b", "a"])

# ── Badge visibility ──────────────────────────────────────────────────────────

func test_badge_hidden_when_empty_visible_when_pending() -> void:
	assert_false(_plugin._badge.visible)
	_plugin.push_for_test(_make_record("a", "dialogue", "cid_a"))
	assert_true(_plugin._badge.visible)
	assert_eq(_plugin._badge.text, "1")
	_plugin.push_for_test(_make_record("b", "dialogue", "cid_b"))
	assert_eq(_plugin._badge.text, "2")
	_plugin.open_for_test(0)
	assert_eq(_plugin._badge.text, "1")
	_plugin.open_for_test(0)
	assert_false(_plugin._badge.visible)

# ── Display helpers ───────────────────────────────────────────────────────────

func test_display_name_falls_back_through_character_patron_event_id() -> void:
	# Character lookup first.
	var r := _make_record("e1", "dialogue", "cid_known")
	assert_eq(_plugin._display_name_for(r), "Known Character")

	# Falls back to patron when no character match.
	var r2 := _make_record("e2", "dialogue", "")
	r2["trigger"]["patron_id"] = "pid_known"
	assert_eq(_plugin._display_name_for(r2), "Known Patron")

	# Falls back to event_id when nothing matches.
	var r3 := _make_record("e3_orphan", "dialogue", "")
	assert_eq(_plugin._display_name_for(r3), "e3_orphan")

# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_record(eid: String, etype: String, cid: String) -> Dictionary:
	return {
		"event_id": eid,
		"event_type": etype,
		"trigger": {"event": "character_arrived", "character_id": cid, "patron_id": ""},
		"payload": {
			"entry_node_id": "n_start",
			"nodes": [{"node_id": "n_start", "body": "hi", "options": []}]
		}
	}

class _StubEvents:
	extends PluginBase
	signal event_resolved(record: Dictionary)
	var pending: Dictionary = {}
	func get_plugin_name() -> String: return "_StubEvents"
	func is_dialogue_pending(event_id: String) -> bool: return pending.get(event_id, false)

class _StubDialogue:
	extends PluginBase
	var opened_ids: Array[String] = []
	func get_plugin_name() -> String: return "_StubDialogue"
	func open_event(record: Dictionary) -> void:
		opened_ids.append(String(record.get("event_id", "")))

class _StubChars:
	extends PluginBase
	func get_plugin_name() -> String: return "_StubChars"
	func get_def(cid: String) -> Dictionary:
		if cid == "cid_known":
			return {"display_name": "Known Character", "bio": "", "portrait": ""}
		return {}

class _StubPatrons:
	extends PluginBase
	func get_plugin_name() -> String: return "_StubPatrons"
	func get_def(pid: String) -> Dictionary:
		if pid == "pid_known":
			return {"display_name": "Known Patron", "bio": "", "portrait": ""}
		return {}
