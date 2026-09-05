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
		_plugin.queue_free()
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
