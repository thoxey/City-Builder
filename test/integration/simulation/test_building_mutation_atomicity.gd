extends "res://test/unit/builder/test_builder_commands.gd"

func test_rejected_placement_changes_no_authority_version_or_change_set() -> void:
	GameState.reset_state_version()
	var changes: Array = []
	var capture := func(change_set): changes.append(change_set)
	GameEvents.authoritative_change_committed.connect(capture)
	land.blocked[Vector2i(4, 4)] = true
	var before_registry := GameState.building_registry.duplicate(true)
	var before_cells := GameState.cell_to_building.duplicate(true)
	var outcome: Dictionary = builder.try_place_building("house", Vector2i(4, 4))
	assert_eq(outcome.status, PlaytestActionResult.STATUS_REJECTED)
	assert_eq(GameState.get_state_version(), 0)
	assert_eq(GameState.building_registry, before_registry)
	assert_eq(GameState.cell_to_building, before_cells)
	assert_eq(changes, [])
	GameEvents.authoritative_change_committed.disconnect(capture)

func test_rejected_replace_preserves_original_building_and_version() -> void:
	GameState.reset_state_version()
	assert_eq(builder.try_place_building("house", Vector2i.ZERO).status,
		PlaytestActionResult.STATUS_APPLIED)
	var committed_version := GameState.get_state_version()
	var before := GameState.building_registry.duplicate(true)
	economy.quote = {"ok":false, "cost":999, "have":0, "reason":"insufficient_cash"}
	var outcome: Dictionary = builder.try_place_building("park", Vector2i.ZERO, 0, true)
	assert_eq(outcome.status, PlaytestActionResult.STATUS_REJECTED)
	assert_eq(GameState.get_state_version(), committed_version)
	assert_eq(GameState.building_registry, before)
