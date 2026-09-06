extends PluginBase

## UniqueRegistry — authority for one-of-a-kind buildings.
##
## Responsibilities:
##   1. At startup, scan BuildingCatalog for every structure carrying a
##      UniqueProfile and index it by building_id → UniqueProfile.
##   2. Track which uniques are currently on the map (listens to
##      GameEvents.structure_placed / structure_demolished).
##   3. Expose is_placed() and is_unlocked() for gating (Palette, selector,
##      dialogue triggers).
##   4. Re-evaluate unlock state whenever demand or placement changes; fire
##      GameEvents.unique_unlocked when a building newly becomes available.

var _catalog: PluginBase
var _demand:  PluginBase
var _characters: PluginBase
var _patrons: PluginBase

# building_id -> UniqueProfile
var _profiles: Dictionary = {}
# building_id -> Vector2i anchor (only buildings currently on the map)
var _placed: Dictionary = {}
# Set of unlocked building_ids from the last re-evaluation; diffed on each refresh
# to emit unique_unlocked exactly once per unlock event.
var _unlocked_cache: Dictionary = {}

func get_plugin_name() -> String:
	return "UniqueRegistry"

func get_dependencies() -> Array[String]:
	return ["BuildingCatalog", "Demand", "CharacterSystem", "PatronSystem"]

func inject(deps: Dictionary) -> void:
	_catalog = deps.get("BuildingCatalog")
	_demand  = deps.get("Demand")
	_characters = deps.get("CharacterSystem")
	_patrons = deps.get("PatronSystem")

func _plugin_ready() -> void:
	_index_uniques()
	_rebuild_from_registry()
	_refresh_unlocks()

	GameEvents.structure_placed.connect(_on_structure_placed)
	GameEvents.structure_demolished.connect(_on_structure_demolished)
	GameEvents.demand_unserved_changed.connect(_on_demand_changed)
	GameEvents.character_state_changed.connect(_on_progression_changed)
	GameEvents.patron_state_changed.connect(_on_progression_changed)
	GameEvents.map_loaded.connect(_on_map_loaded)

	var chains := 0
	var wants := 0
	var landmarks := 0
	for bid in _profiles:
		var p: UniqueProfile = _profiles[bid]
		match p.chain_role:
			"chain":    chains += 1
			"want":     wants += 1
			"landmark": landmarks += 1
	print("[UniqueRegistry] indexed: count=%d chains=%d wants=%d landmarks=%d" % [
		_profiles.size(), chains, wants, landmarks
	])

# ── Indexing ──────────────────────────────────────────────────────────────────

func _index_uniques() -> void:
	_profiles.clear()
	var structures: Array[Structure] = _catalog.get_all()
	var summaries: Array = _catalog.get_summary()
	for i in structures.size():
		var s: Structure = structures[i]
		var u: UniqueProfile = s.find_metadata(UniqueProfile)
		if u == null:
			continue
		var bid: String = summaries[i].get("building_id", "")
		if bid.is_empty():
			continue
		_profiles[bid] = u

func _rebuild_from_registry() -> void:
	_placed.clear()
	if GameState == null or GameState.building_registry == null:
		return
	for entry_id in GameState.building_registry:
		var entry: Dictionary = GameState.building_registry[entry_id]
		var struct_idx: int = entry.get("structure", -1)
		if struct_idx < 0:
			continue
		var bid: String = _catalog.get_id_by_index(struct_idx)
		if bid.is_empty() or not _profiles.has(bid):
			continue
		var anchor: Vector2i = entry.get("anchor", Vector2i.ZERO)
		_placed[bid] = anchor

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_structure_placed(pos: Vector3i, struct_idx: int, _orient: int) -> void:
	var bid: String = _catalog.get_id_by_index(struct_idx)
	if bid.is_empty() or not _profiles.has(bid):
		return
	var anchor := Vector2i(pos.x, pos.z)
	_placed[bid] = anchor
	print("[UniqueRegistry] unique_placed: building_id=%s pos=(%d,%d) count=%d" % [
		bid, pos.x, pos.z, _placed.size()
	])
	GameEvents.unique_placed.emit(bid)
	_refresh_unlocks()

func _on_structure_demolished(pos: Vector3i) -> void:
	# Demolition signal only carries position, not the building_id. Find the
	# placed unique whose anchor matches — O(n) over placed set (small, never
	# more than 39 entries).
	var anchor := Vector2i(pos.x, pos.z)
	var bid_to_remove: String = ""
	for bid in _placed:
		if _placed[bid] == anchor:
			bid_to_remove = bid
			break
	if bid_to_remove.is_empty():
		return
	_placed.erase(bid_to_remove)
	print("[UniqueRegistry] unique_removed: building_id=%s pos=(%d,%d)" % [
		bid_to_remove, pos.x, pos.z
	])
	GameEvents.unique_removed.emit(bid_to_remove)
	_refresh_unlocks()

func _on_demand_changed(_bucket: String, _value: float) -> void:
	_refresh_unlocks()

func _on_progression_changed(_id: String, _state: int) -> void:
	_refresh_unlocks()

func _on_map_loaded(_m: DataMap) -> void:
	_rebuild_from_registry()
	_refresh_unlocks()

# ── Unlock evaluation ─────────────────────────────────────────────────────────

func _refresh_unlocks() -> void:
	var new_unlocked: Dictionary = {}
	for bid in _profiles:
		if _is_unlocked_internal(bid):
			new_unlocked[bid] = true
	# Emit signal for every bid that flipped from locked → unlocked.
	for bid in new_unlocked:
		if not _unlocked_cache.has(bid):
			var p: UniqueProfile = _profiles[bid]
			print("[UniqueRegistry] unlocked: building_id=%s threshold=%d prereqs=%d" % [
				bid, p.prerequisite_threshold, p.prerequisite_ids.size()
			])
			GameEvents.unique_unlocked.emit(bid)
	_unlocked_cache = new_unlocked

func _is_unlocked_internal(bid: String) -> bool:
	return bool(evaluate_unlock(bid).get("unlocked", false))

## Unique progression is earned from the monotonic, total-ever demand value.
## Spending demand on ordinary or unique buildings must not move an unlock
## target further away. Placement affordability continues to use unserved
## demand through DemandPlugin.get_value().
func _bucket_total(category: String) -> float:
	if _demand == null:
		return 0.0
	var type_id: String = _demand.bucket_for_category(category)
	if type_id.is_empty():
		return 0.0
	return _demand.get_total(type_id)

# ── Public API ────────────────────────────────────────────────────────────────

func is_unique(building_id: String) -> bool:
	return _profiles.has(building_id)

func is_placed(building_id: String) -> bool:
	return _placed.has(building_id)

func is_unlocked(building_id: String) -> bool:
	return _unlocked_cache.has(building_id)

func get_profile(building_id: String) -> UniqueProfile:
	return _profiles.get(building_id)

func get_all_profiles() -> Dictionary:
	return _profiles

func evaluate_unlock(building_id: String, excluded_building_ids: Array = []) -> Dictionary:
	if not _profiles.has(building_id):
		return {
			"building_id": building_id, "unique": false, "unlocked": true,
			"selectable": true, "placed": false, "reasons": [], "primary_reason": null,
		}
	var profile: UniqueProfile = _profiles[building_id]
	var missing: Array[String] = []
	for prerequisite in profile.prerequisite_ids:
		if not _is_effectively_placed(String(prerequisite), excluded_building_ids):
			missing.append(String(prerequisite))
	var reasons: Array[String] = []
	var placed := _is_effectively_placed(building_id, excluded_building_ids)
	if placed:
		reasons.append(PlaytestActionResult.UNIQUE_ALREADY_PLACED)
	var character_evidence: Variant = null
	if not profile.character_id.is_empty():
		var character_state := 0
		var character_name := profile.character_id
		if _characters != null:
			character_state = int(_characters.get_state(profile.character_id))
			var character_def: Dictionary = _characters.get_def(profile.character_id)
			character_name = String(character_def.get("display_name", profile.character_id))
		character_evidence = {
			"id": profile.character_id,
			"display_name": character_name,
			"state": character_state,
			"state_name": _character_state_name(character_state),
		}
		if profile.chain_role == "want" and character_state < 2:
			reasons.append(PlaytestActionResult.WANT_NOT_REVEALED)
	var patron_evidence: Variant = null
	if not profile.patron_id.is_empty():
		var patron_state := 0
		var patron_name := profile.patron_id
		if _patrons != null:
			patron_state = int(_patrons.get_state(profile.patron_id))
			var patron_def: Dictionary = _patrons.get_def(profile.patron_id)
			patron_name = String(patron_def.get("display_name", profile.patron_id))
		patron_evidence = {
			"id": profile.patron_id,
			"display_name": patron_name,
			"state": patron_state,
			"state_name": _patron_state_name(patron_state),
		}
		if profile.chain_role == "landmark" and patron_state < 1:
			reasons.append(PlaytestActionResult.PATRON_NOT_READY)
	if not missing.is_empty(): reasons.append(PlaytestActionResult.UNMET_PREREQUISITE)
	var current := _bucket_total(profile.bucket)
	if current < profile.prerequisite_threshold:
		reasons.append(PlaytestActionResult.BELOW_DEMAND_THRESHOLD)
	var bucket_id: String = String(_demand.bucket_for_category(profile.bucket)) if _demand and _demand.has_method("bucket_for_category") else profile.bucket
	var bucket_label := String(bucket_id).capitalize()
	if _demand and _demand.has_method("bucket_display_name"):
		bucket_label = _demand.bucket_display_name(bucket_id)
	var display_name := building_id
	if _catalog != null:
		display_name = String(_catalog.get_summary_by_id(building_id).get("display_name", building_id))
	return {
		"building_id": building_id,
		"display_name": display_name,
		"unique": true,
		"role": profile.chain_role,
		"unlocked": reasons.is_empty(),
		"selectable": reasons.is_empty(),
		"placed": placed,
		"threshold": profile.prerequisite_threshold,
		"bucket": bucket_label,
		"current": current,
		"prerequisites": Array(profile.prerequisite_ids),
		"missing_prerequisites": missing,
		"character": character_evidence,
		"patron": patron_evidence,
		"reasons": reasons,
		"primary_reason": reasons[0] if not reasons.is_empty() else null,
	}

func _is_effectively_placed(building_id: String, excluded_building_ids: Array) -> bool:
	return _placed.has(building_id) and building_id not in excluded_building_ids

static func _character_state_name(state: int) -> String:
	match state:
		0: return "NOT_ARRIVED"
		1: return "ARRIVED"
		2: return "WANT_REVEALED"
		3: return "SATISFIED"
		4: return "CONTRIBUTES_TO_LANDMARK"
		_: return "UNKNOWN(%d)" % state

static func _patron_state_name(state: int) -> String:
	match state:
		0: return "LOCKED"
		1: return "LANDMARK_AVAILABLE"
		2: return "COMPLETED"
		_: return "UNKNOWN(%d)" % state

func placed_count() -> int:
	return _placed.size()

func unlocked_count() -> int:
	return _unlocked_cache.size()
