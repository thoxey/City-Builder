extends PluginBase

## CharacterSystem — drives the nine-character questline state machine.
##
## States live in GameState.map.character_states (persisted to save).
## Transitions:
##   NOT_ARRIVED → ARRIVED               on fulfilled-demand >= threshold
##   ARRIVED     → WANT_REVEALED         on dialogue close (or auto in M3 stub)
##   WANT_REVEALED → SATISFIED           on unique_placed(building_id == want)
##   SATISFIED   → CONTRIBUTES_TO_LANDMARK   on PatronSystem landmark-placed
##
## Arrival is pegged to FULFILLED demand — a character shows up once the city
## has built enough of their bucket, not when it has unmet need. This keeps
## narrative beats tied to player progress (city scale) rather than to
## demand-pressure spikes that vanish the moment housing/shops are placed.
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

var _demand: PluginBase
var _catalog: PluginBase

# character_id -> Dictionary (parsed JSON def)
var _defs: Dictionary = {}

func get_plugin_name() -> String:
	return "CharacterSystem"

func get_dependencies() -> Array[String]:
	return ["Demand", "BuildingCatalog"]

func inject(deps: Dictionary) -> void:
	_demand = deps.get("Demand")
	_catalog = deps.get("BuildingCatalog")

func _plugin_ready() -> void:
	_load_defs(DATA_DIR)
	_seed_initial_states()

	GameEvents.demand_fulfilled_changed.connect(_on_demand_changed)
	GameEvents.unique_placed.connect(_on_unique_placed)
	GameEvents.structure_placed.connect(_on_structure_changed)
	GameEvents.structure_demolished.connect(_on_structure_demolished)
	GameEvents.map_loaded.connect(_on_map_loaded)

	# At boot, reconcile against current fulfilled demand — any bucket already
	# past a character's threshold (e.g. carry-over from a save) triggers
	# arrival immediately rather than waiting for the next signal.
	_recheck_all_arrivals()

	# Guides arrive on game start (no demand prerequisite). Deferred because
	# DialoguePlugin's _plugin_ready (which connects to character_arrived)
	# hasn't run yet at this point — plugins ready in topo order, but signal
	# connections only catch emissions after they're hooked up.
	call_deferred("_trigger_guide_arrivals")

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
	data["_source_path"] = path
	return data

## Ensure every loaded character that tracks arrival state has an entry in
## the persistence dict so the save format is stable even before any signal
## fires. Patron / narrator types are dialogue-only and never enter the
## state map; "character" and "guide" both go through arrival.
func _seed_initial_states() -> void:
	if GameState == null or GameState.map == null:
		return
	var states: Dictionary = GameState.map.character_states
	for cid in _defs:
		if not _tracks_arrival(cid):
			continue
		if not states.has(cid):
			states[cid] = CharState.NOT_ARRIVED

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_demand_changed(bucket_id: String, value: float) -> void:
	for cid in _sorted_character_ids():
		if not is_quest_character(cid):
			continue
		var def: Dictionary = _defs[cid]
		var def_bucket: String = def.get("associated_bucket", "")
		if _category_to_bucket_id(def_bucket) != bucket_id:
			continue
		_reconcile_character(cid)

func _on_unique_placed(building_id: String) -> void:
	for cid in _sorted_character_ids():
		if not is_quest_character(cid):
			continue
		var def: Dictionary = _defs[cid]
		if String(def.get("want_building_id", "")) != building_id:
			continue
		if get_state(cid) == CharState.WANT_REVEALED:
			_trigger_satisfied(cid, building_id)

func _on_structure_changed(_pos: Vector3i, _struct_idx: int, _orient: int) -> void:
	_recheck_all_arrivals()

func _on_structure_demolished(_pos: Vector3i) -> void:
	_recheck_all_arrivals()

func _on_map_loaded(_m: DataMap) -> void:
	# After load, states come from the save — don't retrigger arrivals that
	# have already fired, but re-connect the demand listener by re-checking
	# any character still in NOT_ARRIVED against current demand values.
	_seed_initial_states()
	_reconcile_all()
	# Same deferred-fire reasoning as in _plugin_ready: dialogue is already
	# connected here, but mapping load events / save restores happen during
	# signal handling and we don't want to fire-while-handling.
	call_deferred("_trigger_guide_arrivals")

# ── Transitions ───────────────────────────────────────────────────────────────

func _trigger_arrival(cid: String, bucket_id: String, value: float) -> void:
	if not _set_state(cid, CharState.ARRIVED):
		return
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
	_reconcile_character(cid)

func _trigger_satisfied(cid: String, want: String) -> void:
	if not _set_state(cid, CharState.SATISFIED):
		return
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

func _set_state(cid: String, new_state: int) -> bool:
	var old: int = get_state(cid)
	if new_state <= old:
		return false
	GameState.map.character_states[cid] = new_state
	print("[CharacterSystem] state: id=%s %s->%s" % [
		cid, _state_name(old), _state_name(new_state)
	])
	GameEvents.character_state_changed.emit(cid, new_state)
	return true

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
		"residential": return "residential"
		"industrial":  return "industrial"
		"commercial":  return "commercial"
		_:             return ""

## Walk all characters and check whether their associated bucket already meets
## arrival threshold. Triggers arrivals for any that do. Idempotent — fires
## only for characters currently NOT_ARRIVED.
func _recheck_all_arrivals() -> void:
	for cid in _sorted_character_ids():
		if not is_quest_character(cid):
			continue
		_reconcile_character(cid)

func _reconcile_all() -> void:
	_recheck_all_arrivals()

func _reconcile_character(cid: String) -> void:
	if not is_quest_character(cid):
		return
	var state := get_state(cid)
	if state == CharState.NOT_ARRIVED:
		var gate := evaluate_character_gate(cid)
		if gate.get("arrival_ready", false):
			_trigger_arrival(cid, gate.get("bucket", ""), gate.get("fulfilled", 0.0))
	elif state == CharState.WANT_REVEALED:
		var want_id := String(_defs[cid].get("want_building_id", ""))
		if not want_id.is_empty() and _is_building_placed(want_id):
			_trigger_satisfied(cid, want_id)

func _is_building_placed(building_id: String) -> bool:
	if _catalog == null or GameState == null:
		return false
	var index := int(_catalog.get_item_index(building_id))
	if index < 0:
		return false
	for internal_id in GameState.building_registry:
		if int(GameState.building_registry[internal_id].get("structure", -1)) == index:
			return true
	return false

func _sorted_character_ids() -> Array[String]:
	var ids: Array[String] = []
	for cid in _defs:
		ids.append(String(cid))
	ids.sort()
	return ids

# ── Public accessors ──────────────────────────────────────────────────────────

func get_def(cid: String) -> Dictionary:
	return _defs.get(cid, {})

func evaluate_character_gate(cid: String) -> Dictionary:
	var def: Dictionary = _defs.get(cid, {})
	if def.is_empty():
		return {"character_id": cid, "arrival_ready": false, "reasons": [PlaytestActionResult.UNKNOWN_CHARACTER]}
	var bucket_id := _category_to_bucket_id(String(def.get("associated_bucket", "")))
	var fulfilled := float(_demand.get_fulfilled(bucket_id)) if _demand != null and not bucket_id.is_empty() else 0.0
	var required_fulfilled := float(def.get("arrival_threshold", 0.0))
	var tier_snapshot := {"attained_tier": 0, "tier_evidence": []}
	if _catalog != null and _catalog.has_method("get_bucket_tier_snapshot"):
		tier_snapshot = _catalog.get_bucket_tier_snapshot(bucket_id)
	var attained_tier := int(tier_snapshot.get("attained_tier", 0))
	var required_tier := int(def.get("arrival_requires_tier", 0))
	var demand_met := fulfilled >= required_fulfilled
	var tier_met := attained_tier >= required_tier
	var reasons: Array[String] = []
	if not demand_met:
		reasons.append(PlaytestActionResult.FULFILLED_DEMAND_NOT_REACHED)
	if not tier_met:
		reasons.append(PlaytestActionResult.REQUIRED_TIER_NOT_REACHED)
	var want_id := String(def.get("want_building_id", ""))
	var want_name := want_id
	if _catalog != null:
		want_name = String(_catalog.get_summary_by_id(want_id).get("display_name", want_id))
	var bucket_label := bucket_id.capitalize()
	if _demand != null and _demand.has_method("bucket_display_name"):
		bucket_label = _demand.bucket_display_name(bucket_id)
	return {
		"character_id": cid,
		"display_name": String(def.get("display_name", cid)),
		"state": get_state(cid),
		"state_name": _state_name(get_state(cid)),
		"bucket": bucket_id,
		"bucket_label": bucket_label,
		"fulfilled": fulfilled,
		"required_fulfilled": required_fulfilled,
		"attained_tier": attained_tier,
		"required_tier": required_tier,
		"tier_evidence": tier_snapshot.get("tier_evidence", []).duplicate(true),
		"demand_met": demand_met,
		"tier_met": tier_met,
		"arrival_ready": reasons.is_empty(),
		"want_building_id": want_id,
		"want_display_name": want_name,
		"source_path": String(def.get("_source_path", "")),
		"reasons": reasons,
	}

func all_character_ids() -> Array:
	return _defs.keys()

func count_in_state(s: int) -> int:
	var n := 0
	for cid in _defs:
		if not is_quest_character(cid):
			continue
		if get_state(cid) == s:
			n += 1
	return n

## "character" is the only type that participates in the arrival/want/satisfied
## state machine. "guide" only goes through arrival (NOT_ARRIVED → ARRIVED on
## game start). patron / narrator are dialogue-only — loaded so DialoguePlugin
## can resolve the speaker but never enter the state map. Missing field
## defaults to "character" for back-compat with files authored before this
## field existed.
func is_quest_character(cid: String) -> bool:
	var def: Dictionary = _defs.get(cid, {})
	if def.is_empty():
		return false
	return String(def.get("character_type", "character")) == "character"

func get_character_type(cid: String) -> String:
	return String(_defs.get(cid, {}).get("character_type", "character"))

## True for types that go through the arrival event — quest characters and
## guides. Patron / narrator types are dialogue-only and are not seeded into
## the state map.
func _tracks_arrival(cid: String) -> bool:
	var t := get_character_type(cid)
	return t == "character" or t == "guide"

## Guides arrive on game start (or first map load if added mid-run). One-shot
## per save: characters already at ARRIVED or beyond aren't re-fired. Deferred
## from _plugin_ready / _on_map_loaded so DialoguePlugin's signal connection
## is in place when we emit.
func _trigger_guide_arrivals() -> void:
	for cid in _defs:
		if get_character_type(cid) != "guide":
			continue
		if get_state(cid) != CharState.NOT_ARRIVED:
			continue
		_set_state(cid, CharState.ARRIVED)
		print("[CharacterSystem] guide_arrived: id=%s" % cid)
		GameEvents.character_arrived.emit(cid)

func get_talking_videos(cid: String) -> Array:
	var raw: Variant = _defs.get(cid, {}).get("talking_videos", [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	var out: Array = []
	for v in (raw as Array):
		out.append(String(v))
	return out
