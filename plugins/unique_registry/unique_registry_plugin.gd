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
	return ["BuildingCatalog", "Demand"]

func inject(deps: Dictionary) -> void:
	_catalog = deps.get("BuildingCatalog")
	_demand  = deps.get("Demand")

func _plugin_ready() -> void:
	_index_uniques()
	_rebuild_from_registry()
	_refresh_unlocks()

	GameEvents.structure_placed.connect(_on_structure_placed)
	GameEvents.structure_demolished.connect(_on_structure_demolished)
	GameEvents.demand_unserved_changed.connect(_on_demand_changed)
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
	var p: UniqueProfile = _profiles.get(bid)
	if p == null:
		return false
	# Already placed → not available (one-of-a-kind guard).
	if _placed.has(bid):
		return false
	# Prerequisite buildings must be on the map.
	for prereq_v in p.prerequisite_ids:
		if not _placed.has(String(prereq_v)):
			return false
	# Demand bucket must meet threshold.
	if p.prerequisite_threshold > 0:
		var v: float = _bucket_value(p.bucket)
		if v < float(p.prerequisite_threshold):
			return false
	return true

## UniqueProfile.bucket is a category ("residential" / "industrial" /
## "commercial"). Demand addresses buckets by type_id ("housing_demand" /
## "industrial_demand" / "commercial_demand"), so translate before lookup.
func _bucket_value(category: String) -> float:
	if _demand == null:
		return 0.0
	var type_id: String = _demand.bucket_for_category(category)
	if type_id.is_empty():
		return 0.0
	return _demand.get_value(type_id)

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

func placed_count() -> int:
	return _placed.size()

func unlocked_count() -> int:
	return _unlocked_cache.size()
