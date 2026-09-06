extends GutTest

const DialogueCls := preload("res://plugins/dialogue/dialogue_plugin.gd")
const Fixtures := preload("res://test/unit/dialogue/dialogue_fixtures.gd")

func test_200_beat_reveal_updates_preserve_prior_rows_with_bounded_update_cost() -> void:
	var plugin := DialogueCls.new()
	plugin._event_system = _StubEvents.new()
	plugin._characters = _StubChars.new()
	add_child(plugin)
	plugin._build_ui()
	plugin.set_reveal_rate_for_test(100000.0, 0.0)
	plugin.open_event_for_test(Fixtures.stress_event())
	var first_row: Control = plugin._view.transcript_row_at(0)
	var worst_usec := 0
	for beat_index in range(200):
		var started := Time.get_ticks_usec()
		plugin.step_reveal_for_test(1.0)
		worst_usec = maxi(worst_usec, int(Time.get_ticks_usec() - started))
		if beat_index < 199:
			plugin.advance_dialogue()
	assert_eq(plugin._view.transcript_row_count(), 200)
	assert_same(plugin._view.transcript_row_at(0), first_row)
	assert_eq(plugin._view.row_projection(0)["full_text"], "Player beat 000.")
	assert_lt(worst_usec, 50000, "single reveal update should remain below one 50ms frame")
	print("DIALOGUE_PERFORMANCE beats=200 worst_reveal_update_usec=%d prior_row_identity_unchanged=true" % worst_usec)
	plugin.queue_free()

class _StubEvents extends PluginBase:
	func apply_effects(_effects: Array) -> void: pass
	func acknowledge_dialogue(_event_id: String) -> bool: return true

class _StubChars extends PluginBase:
	func get_state(_character_id: String) -> int: return 1
	func mark_want_revealed(_character_id: String) -> void: pass
	func get_def(character_id: String) -> Dictionary:
		var mapped := "ambrose" if character_id == "player" else character_id
		var path := "res://data/characters/%s.json" % mapped
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		return parsed if parsed is Dictionary else {"display_name":mapped, "portrait":""}
