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
func get_dependencies() -> Array[String]: return ["BuildingCatalog", "BuildableArea", "CityStats"]

var _catalog:    PluginBase
var _buildable:  PluginBase
var _city_stats: PluginBase

func inject(deps: Dictionary) -> void:
	_catalog    = deps.get("BuildingCatalog")
	_buildable  = deps.get("BuildableArea")
	_city_stats = deps.get("CityStats")

# ── State ─────────────────────────────────────────────────────────────────────

var _scores:    Dictionary = {}   # Vector2i -> int (per-tile attractiveness)
var _emitters:  Dictionary = {}   # Vector2i -> _Emitter
var _city_total: int = 0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
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
	var anchor := Vector2i(pos.x, pos.z)
	var em := _build_emitter(anchor, idx)
	if em != null:
		_emitters[anchor] = em
	_recompute()

func _on_demolished(pos: Vector3i) -> void:
	_emitters.erase(Vector2i(pos.x, pos.z))
	_recompute()

func _on_map_loaded(_map) -> void:
	_recompute_emitters_from_registry()
	_recompute()

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
	var cells: Array = _buildable.allowed_cells() if _buildable and _buildable.has_method("allowed_cells") else []
	var new_scores: Dictionary = {}
	for cell_v in cells:
		var T: Vector2i = cell_v
		var score: int = _compute_tile(T)
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

func _compute_tile(T: Vector2i) -> int:
	var receiver_cat := _receiver_category_at(T)
	var score: int = 0
	for anchor in _emitters:
		var em: _Emitter = _emitters[anchor]
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
