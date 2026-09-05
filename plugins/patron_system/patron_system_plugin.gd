extends PluginBase

## PatronSystem — aggregates character progress into patron milestones.
##
## State machine per patron:
##   LOCKED              initial
##   LANDMARK_AVAILABLE  all three of the patron's characters SATISFIED
##   COMPLETED           the patron's landmark building has been placed
##
## Transition triggers:
##   character_satisfied → count this patron's satisfied characters; if all
##                         three, flip LOCKED → LANDMARK_AVAILABLE
##   unique_placed(landmark_building_id) → flip AVAILABLE → COMPLETED,
##                         promote all three characters to
##                         CONTRIBUTES_TO_LANDMARK, and emit
##                         patron_landmark_completed which Phase 7's
##                         BuildableArea plugin will subscribe to.
##
## Non-linear: players may pursue patrons in any order — this plugin holds
## three independent state machines with no shared gate.

enum PatronState {
	LOCKED,
	LANDMARK_AVAILABLE,
	COMPLETED,
}

const DATA_DIR := "res://data/patrons"

var _characters: PluginBase
var _buildable: PluginBase
var _catalog: PluginBase

# patron_id -> Dictionary (parsed JSON def)
var _defs: Dictionary = {}

func get_plugin_name() -> String:
	return "PatronSystem"

func get_dependencies() -> Array[String]:
	return ["CharacterSystem", "BuildableArea", "BuildingCatalog"]

func inject(deps: Dictionary) -> void:
	_characters = deps.get("CharacterSystem")
	_buildable = deps.get("BuildableArea")
	_catalog = deps.get("BuildingCatalog")

func _plugin_ready() -> void:
	_load_defs(DATA_DIR)
	_seed_initial_states()

	GameEvents.character_satisfied.connect(_on_character_satisfied)
	GameEvents.unique_placed.connect(_on_unique_placed)
	GameEvents.map_loaded.connect(_on_map_loaded)

	# Boot-time reconciliation: if a save has wants already placed we'd miss
	# the live character_satisfied signals — recheck now so state is correct.
	_recheck_all_patrons()

	print("[PatronSystem] loaded: count=%d" % _defs.size())

# ── Loading ───────────────────────────────────────────────────────────────────

func _load_defs(dir_path: String) -> void:
	_defs.clear()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[PatronSystem] cannot_open_dir: %s" % dir_path)
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".json"):
			var path := dir_path.path_join(name)
			var def := _parse_one(path)
			if not def.is_empty():
				_defs[def["patron_id"]] = def
		name = dir.get_next()
	dir.list_dir_end()

func _parse_one(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("[PatronSystem] unreadable: path=%s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("[PatronSystem] invalid_json: path=%s" % path)
		return {}
	var data: Dictionary = parsed
	if String(data.get("patron_id", "")).is_empty():
		push_error("[PatronSystem] missing_patron_id: path=%s" % path)
		return {}
	data["_source_path"] = path
	return data

func _seed_initial_states() -> void:
	if GameState == null or GameState.map == null:
		return
	var states: Dictionary = GameState.map.patron_states
	for pid in _defs:
		if not states.has(pid):
			states[pid] = PatronState.LOCKED

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_character_satisfied(_cid: String) -> void:
	# Character could belong to any patron — recheck all to avoid coupling
	# to the patron_id each signal carries. O(3) patrons, trivial.
	_recheck_all_patrons()

func _on_unique_placed(building_id: String) -> void:
	for pid in _defs:
		var def: Dictionary = _defs[pid]
		if String(def.get("landmark_building_id", "")) != building_id:
			continue
		if get_state(pid) != PatronState.LANDMARK_AVAILABLE:
			# Shouldn't happen — UniqueRegistry's prereq chain gates placement.
			# Guard anyway so a stray build can't fast-forward to COMPLETED.
			push_warning("[PatronSystem] landmark_placed_but_not_available: patron=%s" % pid)
			continue
		_flip_to_completed(pid, building_id)

func _on_map_loaded(_m: DataMap) -> void:
	_seed_initial_states()
	_recheck_all_patrons()

# ── Transitions ───────────────────────────────────────────────────────────────

func _recheck_all_patrons() -> void:
	for pid in _defs:
		_recheck(pid)

func _recheck(pid: String) -> void:
	var state := get_state(pid)
	var def: Dictionary = _defs[pid]
	if state == PatronState.LOCKED:
		var cids: Array = def.get("character_ids", [])
		var satisfied: int = 0
		for cid in cids:
			if _character_is_satisfied_or_contributed(String(cid)):
				satisfied += 1
		if satisfied >= cids.size() and cids.size() > 0:
			_flip_to_available(pid, def.get("landmark_building_id", ""))
			state = PatronState.LANDMARK_AVAILABLE
	if state == PatronState.LANDMARK_AVAILABLE and _is_landmark_placed(String(def.get("landmark_building_id", ""))):
		_flip_to_completed(pid, String(def.get("landmark_building_id", "")))
	elif state == PatronState.COMPLETED:
		_repair_completion(pid)

## Accept both SATISFIED and CONTRIBUTES_TO_LANDMARK — once a landmark is
## placed, its contributors leave SATISFIED, but they've still "counted" for
## the patron's unlock in a resumed-game scenario.
func _character_is_satisfied_or_contributed(cid: String) -> bool:
	if _characters == null:
		return false
	var s: int = _characters.get_state(cid)
	# Use integer comparison so we don't import the CharState enum here.
	return s == 3 or s == 4  # SATISFIED or CONTRIBUTES_TO_LANDMARK

func _flip_to_available(pid: String, landmark_id: String) -> void:
	_set_state(pid, PatronState.LANDMARK_AVAILABLE)
	print("[PatronSystem] landmark_ready: patron=%s landmark=%s" % [pid, landmark_id])
	GameEvents.patron_landmark_ready.emit(pid)

func _flip_to_completed(pid: String, landmark_id: String) -> void:
	_apply_donation(pid)
	_set_state(pid, PatronState.COMPLETED)
	print("[PatronSystem] landmark_completed: patron=%s landmark=%s" % [pid, landmark_id])

	# Bookkeeping: promote each of the patron's characters.
	if _characters and _characters.has_method("promote_to_contributes"):
		for cid in _defs[pid].get("character_ids", []):
			_characters.promote_to_contributes(String(cid))

	GameEvents.patron_landmark_completed.emit(pid)

func _repair_completion(pid: String) -> void:
	_apply_donation(pid)
	if _characters and _characters.has_method("promote_to_contributes"):
		for cid in _defs[pid].get("character_ids", []):
			_characters.promote_to_contributes(String(cid))

func _apply_donation(pid: String) -> Dictionary:
	if _buildable == null or not _buildable.has_method("apply_donation"):
		return {"applied": false, "reason": "buildable_area_unavailable"}
	return _buildable.apply_donation(pid, _defs[pid].get("donation_area", {}))

func _is_landmark_placed(building_id: String) -> bool:
	if _catalog == null or building_id.is_empty():
		return false
	var index := int(_catalog.get_item_index(building_id))
	if index < 0:
		return false
	for internal_id in GameState.building_registry:
		if int(GameState.building_registry[internal_id].get("structure", -1)) == index:
			return true
	return false

# ── State read/write ──────────────────────────────────────────────────────────

func get_state(pid: String) -> int:
	if GameState == null or GameState.map == null:
		return PatronState.LOCKED
	return int(GameState.map.patron_states.get(pid, PatronState.LOCKED))

func _set_state(pid: String, new_state: int) -> void:
	var old: int = get_state(pid)
	if new_state <= old:
		return
	GameState.map.patron_states[pid] = new_state
	print("[PatronSystem] state: patron=%s %s->%s" % [
		pid, _state_name(old), _state_name(new_state)
	])
	GameEvents.patron_state_changed.emit(pid, new_state)

static func _state_name(s: int) -> String:
	match s:
		PatronState.LOCKED:             return "LOCKED"
		PatronState.LANDMARK_AVAILABLE: return "LANDMARK_AVAILABLE"
		PatronState.COMPLETED:          return "COMPLETED"
		_:                              return "UNKNOWN(%d)" % s

# ── Public accessors ──────────────────────────────────────────────────────────

func get_def(pid: String) -> Dictionary:
	return _defs.get(pid, {})

func get_progression_snapshot(pid: String) -> Dictionary:
	var def: Dictionary = _defs.get(pid, {})
	if def.is_empty():
		return {}
	var characters: Array = []
	var satisfied := 0
	for cid_v in def.get("character_ids", []):
		var cid := String(cid_v)
		var state := int(_characters.get_state(cid)) if _characters != null else 0
		if state >= 3:
			satisfied += 1
		characters.append({"character_id": cid, "state": state, "state_name": _character_state_name(state)})
	var landmark_id := String(def.get("landmark_building_id", ""))
	var landmark_name := landmark_id
	if _catalog != null:
		landmark_name = String(_catalog.get_summary_by_id(landmark_id).get("display_name", landmark_id))
	return {
		"patron_id": pid,
		"display_name": String(def.get("display_name", pid)),
		"state": get_state(pid),
		"state_name": _state_name(get_state(pid)),
		"characters": characters,
		"required_count": characters.size(),
		"satisfied_count": satisfied,
		"landmark_building_id": landmark_id,
		"landmark_display_name": landmark_name,
		"donation_applied": _buildable.has_donation(pid) if _buildable != null and _buildable.has_method("has_donation") else false,
		"source_path": String(def.get("_source_path", "")),
	}

func all_patron_ids() -> Array:
	return _defs.keys()

static func _character_state_name(state: int) -> String:
	return ["NOT_ARRIVED", "ARRIVED", "WANT_REVEALED", "SATISFIED", "CONTRIBUTES_TO_LANDMARK"][state] if state >= 0 and state <= 4 else "UNKNOWN(%d)" % state

func is_landmark_available(pid: String) -> bool:
	return get_state(pid) == PatronState.LANDMARK_AVAILABLE

func is_completed(pid: String) -> bool:
	return get_state(pid) == PatronState.COMPLETED
