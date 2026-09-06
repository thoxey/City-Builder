extends GutTest

## Unit tests for BuildableArea + LandDonationPayload.
##
## Stubs PatronSystem.get_def to feed synthetic donation_area dicts and
## fires signals directly. Saved DataMap is snapshot/restored so tests
## don't mutate the live game map.

const BuildableAreaCls := preload("res://plugins/buildable_area/buildable_area_plugin.gd")

var _plugin: Node
var _saved_map: DataMap

func before_each() -> void:
	_saved_map = GameState.map
	GameState.map = DataMap.new()
	GameState.map.rooted_town_rules = false
	_plugin = BuildableAreaCls.new()
	add_child(_plugin)
	# Exercise the real boot path — seed from STARTER_RECT.
	_plugin._load_or_seed()
	GameEvents.map_loaded.connect(_plugin._on_map_loaded)

func after_each() -> void:
	if _plugin and is_instance_valid(_plugin):
		if GameEvents.map_loaded.is_connected(_plugin._on_map_loaded):
			GameEvents.map_loaded.disconnect(_plugin._on_map_loaded)
		remove_child(_plugin)
		_plugin.free()
	_plugin = null
	GameState.map = _saved_map

# ── Starter plot ──────────────────────────────────────────────────────────────

func test_starter_plot_has_64_cells() -> void:
	# Rect2i(-4, -4, 8, 8) is 64 cells.
	assert_eq(_plugin.allowed_count(), 64)

func test_starter_plot_contains_center() -> void:
	assert_true(_plugin.is_allowed(Vector2i(0, 0)))
	assert_true(_plugin.is_allowed(Vector2i(-4, -4)), "inclusive at lower bound")
	assert_true(_plugin.is_allowed(Vector2i(3, 3)), "inclusive at upper - 1")

func test_starter_plot_excludes_outside() -> void:
	assert_false(_plugin.is_allowed(Vector2i(4, 0)), "one past the right edge")
	assert_false(_plugin.is_allowed(Vector2i(-5, 0)), "one past the left edge")
	assert_false(_plugin.is_allowed(Vector2i(100, 100)))

func test_rooted_starter_plot_is_16_by_16_centred_on_origin() -> void:
	GameState.map = DataMap.new()
	GameState.map.rooted_town_rules = true
	_plugin._load_or_seed()

	assert_eq(_plugin.allowed_count(), 256)
	assert_true(_plugin.is_allowed(Vector2i(-8, -8)))
	assert_true(_plugin.is_allowed(Vector2i(7, 7)))
	assert_false(_plugin.is_allowed(Vector2i(-9, 0)))
	assert_false(_plugin.is_allowed(Vector2i(8, 0)))

func test_rooted_starter_presentation_clears_buildable_cells_and_veils_the_rest() -> void:
	GameState.map = DataMap.new()
	GameState.map.rooted_town_rules = true
	_plugin._load_or_seed()
	_plugin._setup_presentation()

	var snapshot: Dictionary = _plugin.get_presentation_snapshot()
	assert_eq(snapshot["buildable_clear_cell_count"], 256)
	assert_eq(snapshot["non_buildable_cell_count"], (512 * 512) - 256)
	assert_almost_eq(float(snapshot["perceptual_opacity"]), 0.05, 0.0001)
	assert_almost_eq(float(snapshot["overlay_alpha"]), 0.0125, 0.0001)
	assert_eq(snapshot["overlay_rgb"], {"r": 1.0, "g": 1.0, "b": 1.0})
	assert_false(snapshot["emphasized"])
	assert_true(snapshot["visible"])

func test_build_modes_emphasize_the_same_authoritative_boundary() -> void:
	_plugin._setup_presentation()
	var normal: Dictionary = _plugin.get_presentation_snapshot()
	_plugin._on_player_input_mode_changed("radial")
	var radial: Dictionary = _plugin.get_presentation_snapshot()
	_plugin._on_player_input_mode_changed("placement")
	var placement: Dictionary = _plugin.get_presentation_snapshot()

	assert_true(radial["emphasized"])
	assert_true(placement["emphasized"])
	assert_gt(float(radial["overlay_alpha"]), float(normal["overlay_alpha"]))
	assert_eq(radial["buildable_clear_cell_count"], normal["buildable_clear_cell_count"])
	assert_eq(radial["non_buildable_cell_count"], normal["non_buildable_cell_count"])

func test_presentation_rebuilds_from_loaded_and_expanded_authority() -> void:
	_plugin._setup_presentation()
	GameState.map.allowed_cells = [Vector2i.ZERO, Vector2i(1, 0)]
	_plugin._on_map_loaded(GameState.map)
	var loaded: Dictionary = _plugin.get_presentation_snapshot()
	assert_eq(loaded["buildable_clear_cell_count"], 2)
	assert_eq(loaded["non_buildable_cell_count"], (512 * 512) - 2)

	_plugin.expand_rect(Rect2i(0, 1, 2, 1), "presentation-test")
	var expanded: Dictionary = _plugin.get_presentation_snapshot()
	assert_eq(expanded["buildable_clear_cell_count"], 4)
	assert_eq(expanded["non_buildable_cell_count"], (512 * 512) - 4)
	assert_gt(int(expanded["revision"]), int(loaded["revision"]))

# ── Expansion via patron landmark ─────────────────────────────────────────────

func test_patron_landmark_completes_expands_mask() -> void:
	watch_signals(GameEvents)
	var outcome: Dictionary = _plugin.apply_donation("aristocrat", {"shape": "rect", "rect": [10, -2, 4, 4]})

	# 4×4 = 16 cells added, nothing overlaps starter.
	assert_eq(_plugin.allowed_count(), 64 + 16)
	assert_true(_plugin.is_allowed(Vector2i(10, -2)))
	assert_true(_plugin.is_allowed(Vector2i(13, 1)))
	assert_signal_emitted(GameEvents, "buildable_area_expanded")
	assert_true(outcome["applied"])
	assert_true(_plugin.has_donation("aristocrat"))

func test_expansion_overlapping_starter_dedupes() -> void:
	# Overlaps starter (which holds 0..3 × 0..3 = 16 cells of this new rect)
	_plugin.apply_donation("farmer", {"shape": "rect", "rect": [0, 0, 8, 8]})

	# 64 starter cells already; new rect is 8×8 = 64 cells; overlap = 16 cells
	# so added = 48 new cells.
	assert_eq(_plugin.allowed_count(), 64 + 48)

func test_rooted_patron_donation_adds_192_unique_cells_once() -> void:
	GameState.map = DataMap.new()
	GameState.map.rooted_town_rules = true
	_plugin._load_or_seed()
	var area := {"shape": "rect", "rect": [8, -8, 12, 16]}

	var first: Dictionary = _plugin.apply_donation("aristocrat", area)
	var second: Dictionary = _plugin.apply_donation("aristocrat", area)

	assert_eq(first["added_cells"].size(), 192)
	assert_eq(_plugin.allowed_count(), 448)
	assert_true(second["already_applied"])
	assert_eq(second["added_cells"].size(), 0)

func test_expansion_with_missing_donation_area_is_noop() -> void:
	var outcome: Dictionary = _plugin.apply_donation("aristocrat", {})
	assert_eq(_plugin.allowed_count(), 64, "still just the starter")
	assert_false(outcome["applied"])

# ── Polygon payload ───────────────────────────────────────────────────────────

func test_polygon_payload_expands_specific_cells() -> void:
	_plugin.apply_donation("farmer", {
		"shape": "polygon", "polygon": [[10, 10], [11, 10], [10, 11]],
	})

	assert_true(_plugin.is_allowed(Vector2i(10, 10)))
	assert_true(_plugin.is_allowed(Vector2i(11, 10)))
	assert_true(_plugin.is_allowed(Vector2i(10, 11)))
	assert_false(_plugin.is_allowed(Vector2i(11, 11)), "polygon only adds explicit cells")

# ── expand_rect direct entry point ────────────────────────────────────────────

func test_expand_rect_adds_cells_and_fires_signal() -> void:
	watch_signals(GameEvents)
	_plugin.expand_rect(Rect2i(20, 20, 2, 2), "test")

	assert_eq(_plugin.allowed_count(), 64 + 4)
	assert_signal_emitted(GameEvents, "buildable_area_expanded")

func test_expand_idempotent_on_second_call() -> void:
	_plugin.expand_rect(Rect2i(20, 20, 2, 2), "test")
	var after_first: int = _plugin.allowed_count()

	watch_signals(GameEvents)
	_plugin.expand_rect(Rect2i(20, 20, 2, 2), "test")

	assert_eq(_plugin.allowed_count(), after_first, "duplicate expand adds nothing")
	assert_signal_not_emitted(GameEvents, "buildable_area_expanded",
		"signal shouldn't fire if no new cells were added")

# ── Persistence round-trip ────────────────────────────────────────────────────

func test_mask_persists_via_datamap_allowed_cells() -> void:
	_plugin.expand_rect(Rect2i(50, 50, 2, 2), "persistence")
	var count_before: int = _plugin.allowed_count()

	# Simulate save → load: build a fresh plugin bound to the same DataMap.
	var fresh := BuildableAreaCls.new()
	add_child(fresh)
	fresh._load_or_seed()

	assert_eq(fresh.allowed_count(), count_before, "reseed picks up persisted cells")
	assert_true(fresh.is_allowed(Vector2i(50, 50)))
	fresh.queue_free()

func test_donation_receipt_makes_duplicate_a_noop() -> void:
	var area := {"shape": "rect", "rect": [10, -2, 4, 4]}
	var first: Dictionary = _plugin.apply_donation("aristocrat", area)
	var count_after_first: int = _plugin.allowed_count()
	var second: Dictionary = _plugin.apply_donation("aristocrat", area)
	assert_true(first["applied"])
	assert_true(second["already_applied"])
	assert_eq(_plugin.allowed_count(), count_after_first)

# ── LandDonationPayload static parsing ────────────────────────────────────────

func test_payload_cells_from_rect_dict() -> void:
	var cells: Array[Vector2i] = LandDonationPayload.cells_from_dict({
		"shape": "rect", "rect": [0, 0, 2, 3],
	})
	# 2×3 = 6 cells.
	assert_eq(cells.size(), 6)
	assert_true(Vector2i(0, 0) in cells)
	assert_true(Vector2i(1, 2) in cells)

func test_payload_cells_from_polygon_dict() -> void:
	var cells: Array[Vector2i] = LandDonationPayload.cells_from_dict({
		"shape": "polygon", "polygon": [[5, 5], [6, 6]],
	})
	assert_eq(cells.size(), 2)
	assert_true(Vector2i(5, 5) in cells)

func test_payload_invalid_shape_returns_empty() -> void:
	var cells: Array[Vector2i] = LandDonationPayload.cells_from_dict({
		"shape": "bogus",
	})
	assert_eq(cells.size(), 0)
