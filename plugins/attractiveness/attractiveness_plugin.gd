extends PluginBase

## Attractiveness — per-tile score driven by AttractivenessProfile metadata
## on placed buildings. See spec_attractiveness.md.
##
## Model: every buildable tile has ONE attractiveness number. A radiator's
## profile has 4 directional fields acting as a lookup table keyed by the
## RECEIVER tile's category — when a building radiates to a neighbour, the
## neighbour's category picks which field of the radiator's profile applies.
## Empty / non-categorised tiles (landmarks, roads, pavement) receive 0.
##
## Spatial: Chebyshev (Moore) radius for adjacency; linear inverse Euclidean
## falloff per contribution. Each radiator's `base` lands only on its own tile.
##
## Outputs:
##   • CityStatSource "attractiveness" — city-wide sum (drives residential demand).
##   • GameEvents.tile_attractiveness_changed(pos, score) — per-tile signal.
##   • GameEvents.city_attractiveness_changed(value) — city-wide signal.
##
## Implementation: full-rebuild on every placement / demolish / map_load /
## buildable_area_expand. O(emitters × buildable_tiles) — fine at current
## scale (30 buildings × 64 tiles). Optimise to incremental if it bites.

func get_plugin_name() -> String: return "Attractiveness"
func get_dependencies() -> Array[String]: return ["BuildingCatalog", "BuildableArea", "CityStats", "PerformanceMonitor"]

var _catalog:    PluginBase
var _buildable:  PluginBase
var _city_stats: PluginBase
var _performance_monitor: PluginBase

func inject(deps: Dictionary) -> void:
	_catalog    = deps.get("BuildingCatalog")
	_buildable  = deps.get("BuildableArea")
	_city_stats = deps.get("CityStats")
	_performance_monitor = deps.get("PerformanceMonitor")

# ── State ─────────────────────────────────────────────────────────────────────

var _scores:    Dictionary = {}   # Vector2i -> int (per-tile attractiveness)
var _emitters:  Dictionary = {}   # Vector2i -> _Emitter
var _city_total: int = 0
var _compat_events_to_ignore := 0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	GameEvents.authoritative_change_committed.connect(_on_authoritative_change)
	GameEvents.structure_placed.connect(_on_placed)
	GameEvents.structure_demolished.connect(_on_demolished)
	GameEvents.map_loaded.connect(_on_map_loaded)
	GameEvents.buildable_area_expanded.connect(func(_cells): _recompute())
	if _city_stats:
		_city_stats.register_source(_AttrSource.new(self))
	_recompute_emitters_from_registry()
	_recompute()
	print("[Attractiveness] indexed: emitters=%d tiles=%d" % [_emitters.size(), _scores.size()])

# ── Event handlers ────────────────────────────────────────────────────────────

func _on_placed(pos: Vector3i, idx: int, _orient: int) -> void:
	if _consume_compat_event(): return
	var anchor := Vector2i(pos.x, pos.z)
	var em := _build_emitter(anchor, idx)
	if em != null:
		_emitters[anchor] = em
	_recompute()

func _on_demolished(pos: Vector3i) -> void:
	if _consume_compat_event(): return
	_emitters.erase(Vector2i(pos.x, pos.z))
	_recompute()

func _on_map_loaded(_map) -> void:
	if _consume_compat_event(): return
	_recompute_emitters_from_registry()
	_recompute()

func _consume_compat_event() -> bool:
	if _compat_events_to_ignore <= 0: return false
	_compat_events_to_ignore -= 1
	return true

func _on_authoritative_change(change_set: Variant) -> void:
	if not (&"structures" in change_set.get_domains()): return
	match change_set.source_kind:
		&"map_load", &"map_clear":
			_compat_events_to_ignore = 1
			_recompute_emitters_from_registry()
			_recompute()
		&"building_mutation":
			_compat_events_to_ignore = 2 if change_set.source_id == "replace" else 1
			_recompute_incremental(change_set.get_entity_keys().get("topology", []))

# ── Emitter index ─────────────────────────────────────────────────────────────

func _recompute_emitters_from_registry() -> void:
	_emitters.clear()
	if not GameState or not GameState.building_registry:
		return
	for bid in GameState.building_registry:
		var entry: Dictionary = GameState.building_registry[bid]
		var sid: int = int(entry.get("structure", -1))
		var anchor: Vector2i = entry.get("anchor", Vector2i.ZERO)
		var em := _build_emitter(anchor, sid)
		if em != null:
			_emitters[anchor] = em

func _build_emitter(anchor: Vector2i, sid: int) -> _Emitter:
	if sid < 0 or sid >= GameState.structures.size():
		return null
	var s: Structure = GameState.structures[sid]
	var attr := s.find_metadata(AttractivenessProfile) as AttractivenessProfile
	if attr == null:
		return null
	var em := _Emitter.new()
	em.anchor = anchor
	em.radius = max(0, attr.radius)
	em.base = attr.base
	em.residential = attr.residential
	em.commercial = attr.commercial
	em.industrial = attr.industrial
	em.nature = attr.nature
	return em

# ── Recompute ─────────────────────────────────────────────────────────────────

func _recompute() -> void:
	var started := Time.get_ticks_usec()
	var cells: Array = _buildable.allowed_cells() if _buildable and _buildable.has_method("allowed_cells") else []
	var new_scores: Dictionary = {}
	var receiver_categories := _receiver_categories_from_registry()
	for cell_v in cells:
		var T: Vector2i = cell_v
		var score: int = _compute_tile_from(T, _emitters, receiver_categories)
		new_scores[T] = score
		var prev: int = int(_scores.get(T, 0))
		if prev != score:
			GameEvents.tile_attractiveness_changed.emit(T, score)
	# Find tiles that disappeared from buildable (reset their score to 0).
	for old_T in _scores:
		if not new_scores.has(old_T):
			GameEvents.tile_attractiveness_changed.emit(old_T, 0)
	_scores = new_scores
	var new_total: int = _sum_scores()
	if new_total != _city_total:
		_city_total = new_total
		GameEvents.city_attractiveness_changed.emit(_city_total)
	_record_index_timing(started, new_scores.size())

func _recompute_incremental(cell_keys: Array) -> void:
	var started := Time.get_ticks_usec()
	var affected := {}
	for key_raw in cell_keys:
		var parts := String(key_raw).split(",")
		if parts.size() == 2: affected[Vector2i(int(parts[0]), int(parts[1]))] = true
	var old_emitters := _emitters.duplicate()
	_recompute_emitters_from_registry()
	for emitter_map in [old_emitters, _emitters]:
		for anchor in emitter_map:
			var emitter: _Emitter = emitter_map[anchor]
			# Only emitters added, removed, or whose footprint is part of the
			# committed mutation can change their surrounding scores.
			if old_emitters.has(anchor) and _emitters.has(anchor) and not affected.has(anchor):
				continue
			for x in range(anchor.x - emitter.radius, anchor.x + emitter.radius + 1):
				for y in range(anchor.y - emitter.radius, anchor.y + emitter.radius + 1):
					affected[Vector2i(x, y)] = true
	var allowed_lookup := {}
	if _buildable and _buildable.has_method("allowed_cells"):
		for cell in _buildable.allowed_cells(): allowed_lookup[cell] = true
	var receiver_categories := _receiver_categories_from_registry()
	var total_delta := 0
	for cell: Vector2i in affected:
		if not allowed_lookup.is_empty() and not allowed_lookup.has(cell): continue
		var previous := int(_scores.get(cell, 0))
		var score := _compute_tile_from(cell, _emitters, receiver_categories)
		if score == previous: continue
		_scores[cell] = score
		total_delta += score - previous
		GameEvents.tile_attractiveness_changed.emit(cell, score)
	if total_delta != 0:
		_city_total += total_delta
		GameEvents.city_attractiveness_changed.emit(_city_total)
	_record_index_timing(started, affected.size())

func _record_index_timing(started: int, affected_cells: int) -> void:
	if _performance_monitor:
		_performance_monitor.record(&"building.index_update", Time.get_ticks_usec() - started,
			{"index":"attractiveness", "affected_cells":affected_cells,
			"emitters":_emitters.size(), "scored_cells":_scores.size()})

func _compute_tile(T: Vector2i) -> int:
	return _compute_tile_from(T, _emitters, {T: _receiver_category_at(T)})

## Canonical tile formula with explicit read-only inputs. Committed recomputes
## and hypothetical placement quotes both delegate here.
func _compute_tile_from(T: Vector2i, emitters: Dictionary, receiver_categories: Dictionary) -> int:
	var receiver_cat := String(receiver_categories.get(T, ""))
	var score: int = 0
	for anchor in emitters:
		var em: _Emitter = emitters[anchor]
		if anchor == T:
			# Own-tile self-contribution.
			score += em.base
			continue
		var dx: int = absi(anchor.x - T.x)
		var dy: int = absi(anchor.y - T.y)
		var cheb: int = maxi(dx, dy)
		if cheb > em.radius:
			continue
		var raw: int = em.contribution_for(receiver_cat)
		if raw == 0:
			continue
		var euclid: float = sqrt(float(dx * dx + dy * dy))
		score += floori(float(raw) / max(euclid, 0.001))
	return score

func _receiver_category_at(T: Vector2i) -> String:
	if not GameState or not GameState.cell_to_building:
		return ""
	var bid: int = GameState.cell_to_building.get(T, -1)
	if bid < 0:
		return ""
	var entry: Dictionary = GameState.building_registry.get(bid, {})
	var sid: int = int(entry.get("structure", -1))
	if sid < 0 or sid >= GameState.structures.size():
		return ""
	return _receiver_category_for_sid(sid)

func _receiver_category_for_sid(sid: int) -> String:
	if sid < 0 or sid >= GameState.structures.size():
		return ""
	var s: Structure = GameState.structures[sid]
	var profile := s.find_metadata(BuildingProfile) as BuildingProfile
	if profile and profile.category in ["residential", "industrial", "commercial"]:
		return profile.category
	# Fall back to catalog top-level category for nature.
	if _catalog and _catalog.has_method("get_summary_by_index"):
		var summary: Dictionary = _catalog.get_summary_by_index(sid)
		if summary.get("category", "") == "nature":
			return "nature"
	return ""

func _receiver_categories_from_registry(excluded_internal_ids: Dictionary = {}) -> Dictionary:
	var result := {}
	for raw_id in GameState.building_registry:
		var internal_id := int(raw_id)
		if excluded_internal_ids.has(internal_id):
			continue
		var entry: Dictionary = GameState.building_registry[raw_id]
		var category := _receiver_category_for_sid(int(entry.get("structure", -1)))
		if category.is_empty():
			continue
		for cell in entry.get("cells", []):
			result[cell] = category
	return result

func _sum_scores() -> int:
	var t: int = 0
	for v in _scores.values():
		t += int(v)
	return t

# ── Public API ────────────────────────────────────────────────────────────────

func get_score(pos: Vector2i) -> int:
	return int(_scores.get(pos, 0))

func city_score() -> int:
	return _city_total

func score_snapshot() -> Dictionary:
	return _scores.duplicate(true)

## Detached quote for the complete committed Attractiveness rule. The result is
## bounded for presentation while retaining total changed-tile count.
func quote_placement_consequences(structure_index: int, anchor: Vector2i,
		footprint: Array, removed_internal_ids: Array = []) -> Dictionary:
	if structure_index < 0 or structure_index >= GameState.structures.size():
		return {"city_delta": 0, "affected_tile_count": 0, "changed_tiles": [],
			"certainty": "uncertain", "uncertainties": ["unknown_structure"]}
	var removed := {}
	for raw_id in removed_internal_ids:
		removed[int(raw_id)] = true
	var before_emitters := _emitters.duplicate()
	var after_emitters := _emitters.duplicate()
	for raw_id in removed:
		var entry: Dictionary = GameState.building_registry.get(raw_id, {})
		after_emitters.erase(entry.get("anchor", Vector2i.ZERO))
	var candidate := _build_emitter(anchor, structure_index)
	if candidate != null:
		after_emitters[anchor] = candidate
	var before_categories := _receiver_categories_from_registry()
	var after_categories := _receiver_categories_from_registry(removed)
	var candidate_category := _receiver_category_for_sid(structure_index)
	if not candidate_category.is_empty():
		for cell in footprint:
			after_categories[cell] = candidate_category
	var cells: Array = _buildable.allowed_cells() if _buildable and _buildable.has_method("allowed_cells") else _scores.keys()
	var seen := {}
	for cell in cells:
		seen[cell] = true
	for cell in footprint:
		if not seen.has(cell):
			cells.append(cell)
			seen[cell] = true
	var city_delta := 0
	var changed: Array = []
	for cell_raw in cells:
		var cell: Vector2i = cell_raw
		var before_score := _compute_tile_from(cell, before_emitters, before_categories)
		var after_score := _compute_tile_from(cell, after_emitters, after_categories)
		var delta := after_score - before_score
		city_delta += delta
		if delta != 0:
			changed.append({
				"cell": CommunityConstants.coordinate_record(cell),
				"before": before_score, "after": after_score, "delta": delta,
			})
	changed.sort_custom(func(a: Dictionary, b: Dictionary):
		var aa := absi(int(a["delta"])); var bb := absi(int(b["delta"]))
		if aa != bb: return aa > bb
		var ac: Dictionary = a["cell"]; var bc: Dictionary = b["cell"]
		return int(ac["x"]) < int(bc["x"]) if ac["x"] != bc["x"] else int(ac["z"]) < int(bc["z"]))
	return {"city_delta": city_delta, "affected_tile_count": changed.size(),
		"changed_tiles": changed.slice(0, 12), "certainty": "exact", "uncertainties": []}

# ── Inner classes ─────────────────────────────────────────────────────────────

class _Emitter extends RefCounted:
	var anchor: Vector2i
	var radius: int = 1
	var base: int = 0
	var residential: int = 0
	var commercial: int = 0
	var industrial: int = 0
	var nature: int = 0

	func contribution_for(receiver_category: String) -> int:
		match receiver_category:
			"residential": return residential
			"commercial":  return commercial
			"industrial":  return industrial
			"nature":      return nature
			_:             return 0

class _AttrSource extends CityStatSource:
	var _plugin
	func _init(p) -> void: _plugin = p
	func get_type_id() -> String: return "attractiveness"
	func tick(_hour: float) -> int: return int(_plugin.city_score())
