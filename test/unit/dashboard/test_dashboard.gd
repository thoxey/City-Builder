extends GutTest

## Unit tests for DashboardPlugin.
##
## These exercise pure logic: the `compute_hint()` priority ladder and the
## `snapshot()` shape. We stub CharacterSystem + PatronSystem + Demand to
## inject state without running the real plugins; the plugin itself is
## constructed but `_plugin_ready()` is skipped (it would build Control
## nodes and connect to GameEvents — out of scope for unit tests).

const DashboardCls := preload("res://plugins/dashboard/dashboard_plugin.gd")

var _plugin: Node
var _stub_chars: Object
var _stub_patrons: Object
var _stub_demand: Object
var _stub_catalog: Object


func before_each() -> void:
	_stub_chars   = _StubCharacters.new()
	_stub_patrons = _StubPatrons.new()
	_stub_demand  = _StubDemand.new()
	_stub_catalog = _StubCatalog.new()

	_plugin = DashboardCls.new()
	_plugin._characters = _stub_chars
	_plugin._patrons    = _stub_patrons
	_plugin._demand     = _stub_demand
	_plugin._catalog    = _stub_catalog
	add_child(_plugin)


func after_each() -> void:
	if _plugin and is_instance_valid(_plugin):
		_plugin.queue_free()
	_plugin = null


# ── Snapshot ──────────────────────────────────────────────────────────────

func test_snapshot_collects_patrons_and_first_arrived() -> void:
	# Two characters ARRIVED, one WANT_REVEALED, one landmark AVAILABLE.
	_stub_patrons.set_state("aristocrat", 1) # LANDMARK_AVAILABLE
	_stub_chars.set_state("aristocrat_commercial", 1)   # ARRIVED
	_stub_chars.set_state("aristocrat_industrial", 2)   # WANT_REVEALED
	_stub_chars.set_state("aristocrat_residential", 0)  # NOT_ARRIVED

	var snap: Object = _plugin.snapshot()
	assert_eq(snap.patrons.size(), 2, "both stubbed patrons surface")
	assert_eq(snap.first_arrived, "aristocrat_commercial", "first ARRIVED cid")
	assert_eq(snap.first_want_revealed, "aristocrat_industrial", "first WANT_REVEALED cid")
	assert_eq(snap.first_landmark_available, "aristocrat", "first LANDMARK_AVAILABLE pid")


# ── Hint priority ─────────────────────────────────────────────────────────

func test_hint_priority_talk_first() -> void:
	# One ARRIVED + one WANT_REVEALED → hint should be Talk to ….
	_stub_chars.set_state("aristocrat_commercial", 1) # ARRIVED
	_stub_chars.set_state("aristocrat_industrial", 2) # WANT_REVEALED
	var hint: String = _plugin.compute_hint(_plugin.snapshot())
	assert_string_starts_with(hint, "Talk to", "talking beats building")
	assert_true(hint.contains("Lord Ashworth"), "uses the character's display_name")

func test_hint_priority_build_over_landmark() -> void:
	_stub_chars.set_state("aristocrat_industrial", 2) # WANT_REVEALED
	_stub_patrons.set_state("aristocrat", 1)          # LANDMARK_AVAILABLE
	var hint: String = _plugin.compute_hint(_plugin.snapshot())
	assert_string_starts_with(hint, "Build a", "building beats landmark")
	assert_true(hint.contains("Crazy Golf"), "uses the want building display_name")

func test_hint_landmark_when_no_char_work_pending() -> void:
	# All satisfied → patron in LANDMARK_AVAILABLE.
	_stub_chars.set_state("aristocrat_commercial", 3)
	_stub_chars.set_state("aristocrat_industrial", 3)
	_stub_chars.set_state("aristocrat_residential", 3)
	_stub_patrons.set_state("aristocrat", 1)
	var hint: String = _plugin.compute_hint(_plugin.snapshot())
	assert_string_starts_with(hint, "Place the", "landmark hint")
	assert_true(hint.contains("Theatre"), "uses the landmark building display_name")

func test_hint_fallback_when_all_idle() -> void:
	# All characters NOT_ARRIVED (default), all patrons LOCKED (default).
	var hint: String = _plugin.compute_hint(_plugin.snapshot())
	assert_eq(hint, "Grow your town")

# ── State icons ──────────────────────────────────────────────────────────

func test_state_icon_table_covers_every_state() -> void:
	for s in range(0, 5):
		assert_true(DashboardCls.STATE_ICON.has(s), "icon for state %d" % s)

# ── Collapse persists through GameState.map ──────────────────────────────

func test_set_collapsed_writes_to_map_flag() -> void:
	var saved := GameState.map
	GameState.map = DataMap.new()
	# Need UI refs so set_collapsed doesn't early-return.
	_plugin._build_ui()
	_plugin.set_collapsed(true)
	assert_true(GameState.map.dashboard_collapsed, "true flushed to map")
	_plugin.set_collapsed(false)
	assert_false(GameState.map.dashboard_collapsed, "false flushed to map")
	GameState.map = saved


# ── Stubs ────────────────────────────────────────────────────────────────

class _StubCharacters:
	extends PluginBase
	var states: Dictionary = {}
	var defs: Dictionary = {
		"aristocrat_commercial": {
			"character_id": "aristocrat_commercial",
			"display_name": "Lord Ashworth",
			"associated_bucket": "commercial",
			"arrival_threshold": 10,
			"want_building_id": "building_members_club",
		},
		"aristocrat_industrial": {
			"character_id": "aristocrat_industrial",
			"display_name": "Industrialist Lord",
			"associated_bucket": "industrial",
			"arrival_threshold": 10,
			"want_building_id": "building_crazy_golf",
		},
		"aristocrat_residential": {
			"character_id": "aristocrat_residential",
			"display_name": "Residential Lord",
			"associated_bucket": "residential",
			"arrival_threshold": 10,
			"want_building_id": "building_members_club",
		},
		"farmer_industrial": {
			"character_id": "farmer_industrial",
			"display_name": "Farmer Frank",
			"associated_bucket": "industrial",
			"arrival_threshold": 10,
			"want_building_id": "",
		},
	}
	func get_plugin_name() -> String: return "CharacterSystem"
	func set_state(cid: String, s: int) -> void: states[cid] = s
	func get_state(cid: String) -> int: return int(states.get(cid, 0))
	func get_def(cid: String) -> Dictionary: return defs.get(cid, {})
	func all_character_ids() -> Array: return defs.keys()

class _StubPatrons:
	extends PluginBase
	var states: Dictionary = {}
	var defs: Dictionary = {
		"aristocrat": {
			"patron_id": "aristocrat",
			"display_name": "Lord Ashworth's Circle",
			"character_ids": ["aristocrat_commercial", "aristocrat_industrial", "aristocrat_residential"],
			"landmark_building_id": "building_theatre",
		},
		"farmer": {
			"patron_id": "farmer",
			"display_name": "The Farmers",
			"character_ids": ["farmer_industrial"],
			"landmark_building_id": "building_windmill",
		},
	}
	func get_plugin_name() -> String: return "PatronSystem"
	func set_state(pid: String, s: int) -> void: states[pid] = s
	func get_state(pid: String) -> int: return int(states.get(pid, 0))
	func get_def(pid: String) -> Dictionary: return defs.get(pid, {})
	func all_patron_ids() -> Array: return defs.keys()

class _StubDemand:
	extends PluginBase
	func get_plugin_name() -> String: return "Demand"

class _StubCatalog:
	extends PluginBase
	var names: Dictionary = {
		"building_members_club": "Members Club",
		"building_crazy_golf":   "Crazy Golf",
		"building_theatre":      "The Theatre",
		"building_windmill":     "Windmill",
	}
	func get_plugin_name() -> String: return "BuildingCatalog"
	func get_summary_by_id(bid: String) -> Dictionary:
		if names.has(bid):
			return {"display_name": names[bid]}
		return {}
