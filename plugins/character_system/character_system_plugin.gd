extends PluginBase

## CharacterSystem — drives the nine-character questline state machine.
##
## States live in GameState.map.character_states (persisted to save).
## Transitions:
##   NOT_ARRIVED → ARRIVED               on demand_changed(bucket >= threshold)
##   ARRIVED     → WANT_REVEALED         on dialogue close (or auto in M3 stub)
##   WANT_REVEALED → SATISFIED           on unique_placed(building_id == want)
##   SATISFIED   → CONTRIBUTES_TO_LANDMARK   on PatronSystem landmark-placed
##
## In M3, dialogue is stubbed — after ARRIVED we auto-advance to WANT_REVEALED
## so satisfaction paths remain reachable. When Phase 5's modal lands, remove
## the auto-advance and have the modal call mark_want_revealed() on close.

enum CharState {
	NOT_ARRIVED,
	ARRIVED,
	WANT_REVEALED,
	SATISFIED,
	CONTRIBUTES_TO_LANDMARK,
}

const DATA_DIR := "res://data/characters"

## With the Phase-5 modal in place, the dialogue close path calls
## mark_want_revealed() itself. Auto-advance is disabled; a character stays
## in ARRIVED until the player closes their arrival modal.
const AUTO_REVEAL_WANT: bool = false

var _demand:  PluginBase
var _uniques: PluginBase

# character_id -> Dictionary (parsed JSON def)
var _defs: Dictionary = {}

func get_plugin_name() -> String:
	return "CharacterSystem"

func get_dependencies() -> Array[String]:
	return ["Demand", "UniqueRegistry"]

func inject(deps: Dictionary) -> void:
	_demand  = deps.get("Demand")
	_uniques = deps.get("UniqueRegistry")

func _plugin_ready() -> void:
	_load_defs(DATA_DIR)
	_seed_initial_states()

	GameEvents.demand_changed.connect(_on_demand_changed)
	GameEvents.unique_placed.connect(_on_unique_placed)
	GameEvents.map_loaded.connect(_on_map_loaded)

	# At boot, reconcile against current demand — any bucket already past a
	# character's threshold (e.g. seeded starter demand of 100) triggers arrival.
	_recheck_all_arrivals()

	print("[CharacterSystem] loaded: count=%d" % _defs.size())

# ── Loading ───────────────────────────────────────────────────────────────────

func _load_defs(dir_path: String) -> void:
	_defs.clear()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[CharacterSystem] cannot_open_dir: %s" % dir_path)
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".json"):
			var path := dir_path.path_join(name)
			var def := _parse_one(path)
			if not def.is_empty():
				_defs[def["character_id"]] = def
		name = dir.get_next()
	dir.list_dir_end()

func _parse_one(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("[CharacterSystem] unreadable: path=%s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("[CharacterSystem] invalid_json: path=%s" % path)
		return {}
	var data: Dictionary = parsed
	if String(data.get("character_id", "")).is_empty():
		push_error("[CharacterSystem] missing_character_id: path=%s" % path)
		return {}
	return data

## Ensure every loaded character has an entry in the persistence dict so the
## save format is stable even before any signal fires.
func _seed_initial_states() -> void:
	if GameState == null or GameState.map == null:
		return
	var states: Dictionary = GameState.map.character_states
	for cid in _defs:
		if not states.has(cid):
			states[cid] = CharState.NOT_ARRIVED

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_demand_changed(bucket_id: String, value: float) -> void:
	for cid in _defs:
		var def: Dictionary = _defs[cid]
		var def_bucket: String = def.get("associated_bucket", "")
		if _category_to_bucket_id(def_bucket) != bucket_id:
			continue
		if get_state(cid) != CharState.NOT_ARRIVED:
			continue
		var threshold: float = float(def.get("arrival_threshold", 0))
		if value >= threshold:
			_trigger_arrival(cid, bucket_id, value)

func _on_unique_placed(building_id: String) -> void:
	for cid in _defs:
		var def: Dictionary = _defs[cid]
		if String(def.get("want_building_id", "")) != building_id:
			continue
		var s: int = get_state(cid)
		if s == CharState.WANT_REVEALED or s == CharState.ARRIVED:
			_trigger_satisfied(cid, building_id)

func _on_map_loaded(_m: DataMap) -> void:
	# After load, states come from the save — don't retrigger arrivals that
	# have already fired, but re-connect the demand listener by re-checking
	# any character still in NOT_ARRIVED against current demand values.
	_seed_initial_states()
	_recheck_all_arrivals()

# ── Transitions ───────────────────────────────────────────────────────────────

func _trigger_arrival(cid: String, bucket_id: String, value: float) -> void:
	_set_state(cid, CharState.ARRIVED)
	var def: Dictionary = _defs[cid]
	print("[CharacterSystem] character_arrived: id=%s bucket=%s threshold=%d demand=%.1f" % [
		cid, bucket_id, int(def.get("arrival_threshold", 0)), value
	])
	GameEvents.character_arrived.emit(cid)

	if AUTO_REVEAL_WANT:
		# Stub for M3 — the real dialogue close will call mark_want_revealed().
		mark_want_revealed(cid)

func mark_want_revealed(cid: String) -> void:
	if get_state(cid) != CharState.ARRIVED:
		return
	_set_state(cid, CharState.WANT_REVEALED)
	print("[CharacterSystem] want_revealed: id=%s want=%s" % [
		cid, _defs[cid].get("want_building_id", "")
	])
	GameEvents.character_want_revealed.emit(cid)

func _trigger_satisfied(cid: String, want: String) -> void:
	_set_state(cid, CharState.SATISFIED)
	print("[CharacterSystem] character_satisfied: id=%s want=%s" % [cid, want])
	GameEvents.character_satisfied.emit(cid)

## Called by PatronSystem (Phase 6) once the patron's landmark is placed.
## Purely bookkeeping — no dialogue, no event fire beyond the state-changed
## signal.
func promote_to_contributes(cid: String) -> void:
	if get_state(cid) != CharState.SATISFIED:
		return
	_set_state(cid, CharState.CONTRIBUTES_TO_LANDMARK)
	print("[CharacterSystem] state: id=%s SATISFIED->CONTRIBUTES_TO_LANDMARK" % cid)

# ── State read/write ──────────────────────────────────────────────────────────

func get_state(cid: String) -> int:
	if GameState == null or GameState.map == null:
		return CharState.NOT_ARRIVED
	return int(GameState.map.character_states.get(cid, CharState.NOT_ARRIVED))

func _set_state(cid: String, new_state: int) -> void:
	var old: int = get_state(cid)
	if old == new_state:
		return
	GameState.map.character_states[cid] = new_state
	print("[CharacterSystem] state: id=%s %s->%s" % [
		cid, _state_name(old), _state_name(new_state)
	])
	GameEvents.character_state_changed.emit(cid, new_state)

static func _state_name(s: int) -> String:
	match s:
		CharState.NOT_ARRIVED:              return "NOT_ARRIVED"
		CharState.ARRIVED:                  return "ARRIVED"
		CharState.WANT_REVEALED:            return "WANT_REVEALED"
		CharState.SATISFIED:                return "SATISFIED"
		CharState.CONTRIBUTES_TO_LANDMARK:  return "CONTRIBUTES_TO_LANDMARK"
		_:                                  return "UNKNOWN(%d)" % s

# ── Helpers ───────────────────────────────────────────────────────────────────

## Character JSON stores the human-readable category ("residential" /
## "industrial" / "commercial"). Demand addresses buckets by type_id. Translate
## once, not every check.
static func _category_to_bucket_id(category: String) -> String:
	match category:
		"residential": return "housing_demand"
		"industrial":  return "industrial_demand"
		"commercial":  return "commercial_demand"
		_:             return ""

## Walk all characters and check whether their associated bucket already meets
## arrival threshold. Triggers arrivals for any that do. Idempotent — fires
## only for characters currently NOT_ARRIVED.
func _recheck_all_arrivals() -> void:
	if _demand == null:
		return
	for cid in _defs:
		if get_state(cid) != CharState.NOT_ARRIVED:
			continue
		var def: Dictionary = _defs[cid]
		var bucket_id: String = _category_to_bucket_id(def.get("associated_bucket", ""))
		if bucket_id.is_empty():
			continue
		var v: float = _demand.get_value(bucket_id)
		if v >= float(def.get("arrival_threshold", 0)):
			_trigger_arrival(cid, bucket_id, v)

# ── Public accessors ──────────────────────────────────────────────────────────

func get_def(cid: String) -> Dictionary:
	return _defs.get(cid, {})

func all_character_ids() -> Array:
	return _defs.keys()

func count_in_state(s: int) -> int:
	var n := 0
	for cid in _defs:
		if get_state(cid) == s:
			n += 1
	return n
