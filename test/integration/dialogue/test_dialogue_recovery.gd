extends GutTest

const EventSystemCls := preload("res://plugins/event_system/event_system_plugin.gd")
const InboxCls := preload("res://plugins/inbox/inbox_plugin.gd")
const DialogueCls := preload("res://plugins/dialogue/dialogue_plugin.gd")
const Fixtures := preload("res://test/unit/dialogue/dialogue_fixtures.gd")

var _saved_map: DataMap
var _events: Node
var _inbox: Node
var _dialogue: Node
var _characters: _StubChars

func before_each() -> void:
	_saved_map = GameState.map
	GameState.map = DataMap.new()
	_characters = _StubChars.new()
	_events = EventSystemCls.new()
	_dialogue = DialogueCls.new()
	_dialogue._event_system = _events
	_dialogue._characters = _characters
	add_child(_events)
	add_child(_dialogue)
	_dialogue._build_ui()
	_dialogue.set_instant_text_for_test(true)
	_inbox = InboxCls.new()
	_inbox._event_system = _events
	_inbox._dialogue = _dialogue
	_inbox._characters = _characters
	add_child(_inbox)
	_inbox._build_ui()
	_events.event_resolved.connect(_inbox._on_event_resolved)

func after_each() -> void:
	for plugin in [_inbox, _dialogue, _events]:
		if is_instance_valid(plugin): plugin.queue_free()
	GameState.map = _saved_map

func test_interrupted_pending_dialogue_redispatches_once_and_commits_exactly_once_after_restart() -> void:
	var record := Fixtures.branching_event("recovery")
	_events.set_events_for_test({"recovery": record})
	_events.fire("recovery")
	assert_eq(GameState.map.pending_dialogue_event_ids, ["recovery"])
	assert_eq(_inbox.pending_event_ids(), ["recovery"])
	_inbox.open_for_test(0)
	assert_true(_dialogue.is_modal_open())
	assert_eq(_inbox.pending_event_ids(), [])
	assert_true(_events.is_dialogue_pending("recovery"), "Inbox is only a projection")
	_dialogue.discard_session_for_test()
	assert_eq(GameState.map.flags, {}, "pre-commit interruption has no effects")

	_inbox._on_map_loaded(GameState.map)
	_events._redispatch_pending_dialogues()
	_events._redispatch_pending_dialogues()
	assert_eq(_inbox.pending_event_ids(), ["recovery"], "duplicate redispatches project once")
	_inbox.open_for_test(0)
	_dialogue.advance_dialogue()
	_dialogue._on_option_pressed(record["payload"]["nodes"][0]["options"][0])
	_dialogue.advance_dialogue()
	assert_true(GameState.map.flags.get("branch_node", false))
	assert_true(GameState.map.flags.get("branch_careful", false))
	assert_true(GameState.map.flags.get("careful_terminal", false))
	assert_false(_events.is_dialogue_pending("recovery"))
	assert_eq(_characters.revealed_ids, [Fixtures.BABA])
	_events._redispatch_pending_dialogues()
	assert_eq(_inbox.pending_event_ids(), [])

class _StubChars extends PluginBase:
	var revealed_ids: Array[String] = []
	var states := {Fixtures.BABA: 1}
	func mark_want_revealed(character_id: String) -> void:
		revealed_ids.append(character_id)
		states[character_id] = 2
	func get_state(character_id: String) -> int: return int(states.get(character_id, 1))
	func get_def(character_id: String) -> Dictionary:
		return {"display_name": character_id, "portrait": ""}
