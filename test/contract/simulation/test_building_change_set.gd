extends "res://test/unit/builder/test_builder_commands.gd"

var _captured_changes: Array = []

func before_each() -> void:
	super.before_each()
	_captured_changes.clear()
	GameState.reset_state_version()
	GameEvents.authoritative_change_committed.connect(_capture_change)

func after_each() -> void:
	if GameEvents.authoritative_change_committed.is_connected(_capture_change):
		GameEvents.authoritative_change_committed.disconnect(_capture_change)
	super.after_each()

func _capture_change(change_set: Variant) -> void:
	_captured_changes.append(change_set)

func test_place_publishes_one_precise_canonical_change_set() -> void:
	assert_eq(builder.try_place_building("house", Vector2i(2, 3)).status,
		PlaytestActionResult.STATUS_APPLIED)
	assert_eq(_captured_changes.size(), 1)
	var change = _captured_changes[0]
	assert_eq(change.source_kind, &"building_mutation")
	assert_eq(change.source_id, "place")
	assert_eq(change.pre_state_version, 0)
	assert_eq(change.post_state_version, 1)
	assert_eq(change.get_entity_keys().topology, ["2,3"])
	assert_has(change.get_domains(), &"structures")
	assert_has(change.get_domains(), &"community")

func test_replace_and_demolish_keep_sorted_affected_cells_and_ids() -> void:
	assert_eq(builder.try_place_building("factory", Vector2i.ZERO).status,
		PlaytestActionResult.STATUS_APPLIED)
	_captured_changes.clear()
	assert_eq(builder.try_place_building("park", Vector2i(1, 0), 0, true).status,
		PlaytestActionResult.STATUS_APPLIED)
	assert_eq(_captured_changes.size(), 1)
	assert_eq(_captured_changes[0].source_id, "replace")
	assert_eq(_captured_changes[0].get_entity_keys().topology, ["0,0", "1,0"])
	_captured_changes.clear()
	assert_eq(builder.try_demolish_cell(Vector2i(1, 0)).status,
		PlaytestActionResult.STATUS_APPLIED)
	assert_eq(_captured_changes[0].source_id, "demolish")
