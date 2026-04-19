extends GutTest

## Unit tests for the PatronSystem plugin.
##
## Stubs CharacterSystem — tests inject satisfied states per character_id
## and fire GameEvents directly. Patron defs are seeded in-memory so the
## test doesn't depend on data/patrons/*.json.

const PatronSysCls := preload("res://plugins/patron_system/patron_system_plugin.gd")

var _plugin: Node
var _stub_chars: Object
var _saved_map: DataMap

func before_each() -> void:
	_saved_map = GameState.map
	GameState.map = DataMap.new()

	_stub_chars = _StubCharacters.new()
	_plugin = PatronSysCls.new()
	_plugin._characters = _stub_chars
	add_child(_plugin)

	_plugin._defs = {
		"aristocrat": {
			"patron_id": "aristocrat",
			"character_ids": [
				"aristocrat_commercial",
				"aristocrat_industrial",
				"aristocrat_residential",
			],
			"landmark_building_id": "building_theatre",
		},
		"businessman": {
			"patron_id": "businessman",
			"character_ids": [
				"businessman_residential",
				"businessman_industrial",
				"businessman_commercial",
			],
			"landmark_building_id": "building_sports_centre",
		},
	}
	_plugin._seed_initial_states()
	# Skip _plugin_ready (it walks the disk for data/patrons/*.json); wire the
	# signal handlers manually so the plugin still reacts during the test.
	GameEvents.character_satisfied.connect(_plugin._on_character_satisfied)
	GameEvents.unique_placed.connect(_plugin._on_unique_placed)
	GameEvents.map_loaded.connect(_plugin._on_map_loaded)

func after_each() -> void:
	if _plugin and is_instance_valid(_plugin):
		for sname in ["character_satisfied", "unique_placed", "map_loaded"]:
			var cb: Callable
			match sname:
				"character_satisfied": cb = _plugin._on_character_satisfied
				"unique_placed":       cb = _plugin._on_unique_placed
				"map_loaded":          cb = _plugin._on_map_loaded
			if GameEvents[sname].is_connected(cb):
				GameEvents[sname].disconnect(cb)
		_plugin.queue_free()
	_plugin = null
	GameState.map = _saved_map

const CHAR_SATISFIED := 3  # matches CharacterSystem.CharState.SATISFIED

# ── Locking ───────────────────────────────────────────────────────────────────

func test_starts_locked() -> void:
	assert_eq(_plugin.get_state("aristocrat"), PatronSysCls.PatronState.LOCKED)

func test_locked_while_incomplete() -> void:
	_stub_chars.satisfy("aristocrat_commercial")
	_stub_chars.satisfy("aristocrat_industrial")

	GameEvents.character_satisfied.emit("aristocrat_industrial")

	assert_eq(_plugin.get_state("aristocrat"), PatronSysCls.PatronState.LOCKED,
		"2/3 satisfied is not enough")

# ── Flip to LANDMARK_AVAILABLE ────────────────────────────────────────────────

func test_landmark_available_on_third_satisfied() -> void:
	_stub_chars.satisfy("aristocrat_commercial")
	_stub_chars.satisfy("aristocrat_industrial")
	_stub_chars.satisfy("aristocrat_residential")

	watch_signals(GameEvents)
	GameEvents.character_satisfied.emit("aristocrat_residential")

	assert_eq(_plugin.get_state("aristocrat"), PatronSysCls.PatronState.LANDMARK_AVAILABLE)
	assert_signal_emitted_with_parameters(GameEvents, "patron_landmark_ready", ["aristocrat"])

func test_only_affected_patron_flips() -> void:
	_stub_chars.satisfy("aristocrat_commercial")
	_stub_chars.satisfy("aristocrat_industrial")
	_stub_chars.satisfy("aristocrat_residential")
	GameEvents.character_satisfied.emit("aristocrat_residential")

	assert_eq(_plugin.get_state("aristocrat"), PatronSysCls.PatronState.LANDMARK_AVAILABLE)
	assert_eq(_plugin.get_state("businessman"), PatronSysCls.PatronState.LOCKED,
		"businessman untouched")

# ── Flip to COMPLETED ─────────────────────────────────────────────────────────

func test_completed_on_landmark_placement() -> void:
	_make_aristocrat_available()

	watch_signals(GameEvents)
	GameEvents.unique_placed.emit("building_theatre")

	assert_eq(_plugin.get_state("aristocrat"), PatronSysCls.PatronState.COMPLETED)
	assert_signal_emitted_with_parameters(GameEvents, "patron_landmark_completed", ["aristocrat"])

func test_completed_promotes_contributing_characters() -> void:
	_make_aristocrat_available()

	GameEvents.unique_placed.emit("building_theatre")

	for cid in ["aristocrat_commercial", "aristocrat_industrial", "aristocrat_residential"]:
		assert_eq(_stub_chars.promoted_ids.get(cid, 0), 1,
			"%s should be promoted once" % cid)

func test_landmark_placed_early_is_guarded() -> void:
	# Nothing satisfied yet — so state is LOCKED — but unique_placed fires
	# somehow. The guard should keep us off COMPLETED.
	GameEvents.unique_placed.emit("building_theatre")

	assert_eq(_plugin.get_state("aristocrat"), PatronSysCls.PatronState.LOCKED,
		"stray placement must not promote state")

func test_unrelated_unique_placement_ignored() -> void:
	_make_aristocrat_available()

	GameEvents.unique_placed.emit("building_pub")

	assert_eq(_plugin.get_state("aristocrat"), PatronSysCls.PatronState.LANDMARK_AVAILABLE,
		"non-landmark placements don't complete")

# ── Non-linear pursuit ────────────────────────────────────────────────────────

func test_two_patrons_progress_independently() -> void:
	# Complete businessman while aristocrat still 0/3
	for cid in _plugin._defs["businessman"]["character_ids"]:
		_stub_chars.satisfy(cid)
	GameEvents.character_satisfied.emit("businessman_commercial")
	GameEvents.unique_placed.emit("building_sports_centre")

	assert_eq(_plugin.get_state("businessman"), PatronSysCls.PatronState.COMPLETED)
	assert_eq(_plugin.get_state("aristocrat"), PatronSysCls.PatronState.LOCKED)

# ── Boot-time recheck (save resume) ───────────────────────────────────────────

func test_recheck_reconstructs_state_on_load() -> void:
	# Simulate a save where all 3 aristocrat characters are already satisfied.
	_stub_chars.satisfy("aristocrat_commercial")
	_stub_chars.satisfy("aristocrat_industrial")
	_stub_chars.satisfy("aristocrat_residential")

	# No character_satisfied signal fires after load — only map_loaded.
	watch_signals(GameEvents)
	GameEvents.map_loaded.emit(GameState.map)

	assert_eq(_plugin.get_state("aristocrat"), PatronSysCls.PatronState.LANDMARK_AVAILABLE)
	assert_signal_emitted(GameEvents, "patron_landmark_ready")

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_aristocrat_available() -> void:
	for cid in _plugin._defs["aristocrat"]["character_ids"]:
		_stub_chars.satisfy(cid)
	GameEvents.character_satisfied.emit("aristocrat_residential")
	assert_eq(_plugin.get_state("aristocrat"), PatronSysCls.PatronState.LANDMARK_AVAILABLE)

# ── Stubs ─────────────────────────────────────────────────────────────────────

class _StubCharacters extends PluginBase:
	var states: Dictionary = {}  # character_id -> state int
	var promoted_ids: Dictionary = {}  # character_id -> promotion count

	func get_plugin_name() -> String: return "_StubCharacters"

	func satisfy(cid: String) -> void:
		states[cid] = 3  # CharState.SATISFIED

	func get_state(cid: String) -> int:
		return states.get(cid, 0)

	func promote_to_contributes(cid: String) -> void:
		promoted_ids[cid] = int(promoted_ids.get(cid, 0)) + 1
		states[cid] = 4  # CharState.CONTRIBUTES_TO_LANDMARK
