extends GutTest

## Unit tests for BuildableArea + LandDonationPayload.
##
## Stubs PatronSystem.get_def to feed synthetic donation_area dicts and
## fires signals directly. Saved DataMap is snapshot/restored so tests
## don't mutate the live game map.

const BuildableAreaCls := preload("res://plugins/buildable_area/buildable_area_plugin.gd")

var _plugin: Node
var _stub_patrons: Object
var _saved_map: DataMap

func before_each() -> void:
	_saved_map = GameState.map
	GameState.map = DataMap.new()
	_stub_patrons = _StubPatrons.new()
	_plugin = BuildableAreaCls.new()
	_plugin._patrons = _stub_patrons
	add_child(_plugin)
	# Exercise the real boot path — seed from STARTER_RECT.
	_plugin._load_or_seed()
	# Wire the signal listeners that _plugin_ready would have done.
	GameEvents.patron_landmark_completed.connect(_plugin._on_patron_landmark_completed)
	GameEvents.map_loaded.connect(_plugin._on_map_loaded)

func after_each() -> void:
	if _plugin and is_instance_valid(_plugin):
		if GameEvents.patron_landmark_completed.is_connected(_plugin._on_patron_landmark_completed):
			GameEvents.patron_landmark_completed.disconnect(_plugin._on_patron_landmark_completed)
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
	_stub_patrons.set_def("aristocrat", {
		"patron_id": "aristocrat",
		"donation_area": {"shape": "rect", "rect": [10, -2, 4, 4]},
	})

	watch_signals(GameEvents)
	GameEvents.patron_landmark_completed.emit("aristocrat")

	# 4×4 = 16 cells added, nothing overlaps starter.
	assert_eq(_plugin.allowed_count(), 64 + 16)
	assert_true(_plugin.is_allowed(Vector2i(10, -2)))
	assert_true(_plugin.is_allowed(Vector2i(13, 1)))
	assert_signal_emitted(GameEvents, "buildable_area_expanded")

func test_expansion_overlapping_starter_dedupes() -> void:
	_stub_patrons.set_def("farmer", {
		"patron_id": "farmer",
		"donation_area": {"shape": "rect", "rect": [0, 0, 8, 8]},
	})

	# Overlaps starter (which holds 0..3 × 0..3 = 16 cells of this new rect)
	GameEvents.patron_landmark_completed.emit("farmer")

	# 64 starter cells already; new rect is 8×8 = 64 cells; overlap = 16 cells
	# so added = 48 new cells.
	assert_eq(_plugin.allowed_count(), 64 + 48)

func test_expansion_with_missing_donation_area_is_noop() -> void:
	_stub_patrons.set_def("aristocrat", {
		"patron_id": "aristocrat",
		# no donation_area
	})
	GameEvents.patron_landmark_completed.emit("aristocrat")
	assert_eq(_plugin.allowed_count(), 64, "still just the starter")

# ── Polygon payload ───────────────────────────────────────────────────────────

func test_polygon_payload_expands_specific_cells() -> void:
	_stub_patrons.set_def("farmer", {
		"patron_id": "farmer",
		"donation_area": {
			"shape": "polygon",
			"polygon": [[10, 10], [11, 10], [10, 11]],
		},
	})

	GameEvents.patron_landmark_completed.emit("farmer")

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
	fresh._patrons = _stub_patrons
	add_child(fresh)
	fresh._load_or_seed()

	assert_eq(fresh.allowed_count(), count_before, "reseed picks up persisted cells")
	assert_true(fresh.is_allowed(Vector2i(50, 50)))
	fresh.queue_free()

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

# ── Stub ──────────────────────────────────────────────────────────────────────

class _StubPatrons extends PluginBase:
	var _defs: Dictionary = {}
	func get_plugin_name() -> String: return "_StubPatrons"
	func set_def(pid: String, def: Dictionary) -> void: _defs[pid] = def
	func get_def(pid: String) -> Dictionary: return _defs.get(pid, {})
