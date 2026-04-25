extends PluginBase

## Demand system — four buckets ticked once per in-game hour.
##
##   desirability  → 0..1 rate, non-monotonic; tracks live satisfaction + amenities
##   housing       → monotonic total; grows with desirability; capped per tick
##   industrial    → monotonic total; tracks population × ratio
##   commercial    → monotonic total; tracks industrial_output × ratio
##
## Each spendable bucket carries three numbers:
##   total_demand  — the town's ever-asked-for need (only grows for the three
##                   spendable buckets; desirability is a live rate)
##   fulfilled     — sum of placed building capacity in this bucket
##   unserved      — derived: max(0, total - fulfilled). Gates spending.
##
## Each bucket also publishes a CityStatSource (publishing UNSERVED) so other
## plugins can read via CityStats without peeking at internals.
##
## Placement: Builder calls try_spend(structure). On success the structure's
## capacity is added to the matching bucket's `fulfilled` (NOT subtracted from
## total — total is monotonic).
## Demolition: this plugin listens to structure_demolished and decrements
## `fulfilled` so the slot frees up for re-placement.

func get_plugin_name() -> String: return "Demand"
func get_dependencies() -> Array[String]: return ["DayNight", "CityStats", "Satisfaction", "BuildingCatalog"]

var _day_night: PluginBase
var _city_stats: PluginBase
var _satisfaction: PluginBase
var _catalog: PluginBase

func inject(deps: Dictionary) -> void:
	_day_night   = deps.get("DayNight")
	_city_stats  = deps.get("CityStats")
	_satisfaction = deps.get("Satisfaction")
	_catalog     = deps.get("BuildingCatalog")

# ── Tuning levers — adjust to rebalance the loop ──────────────────────────────

@export_group("Desirability")
@export var desirability_weight_satisfaction: float = 0.6
@export var desirability_weight_amenity: float = 0.4
## Amenity count that saturates the amenity term.
@export var desirability_amenity_saturation: float = 10.0

@export_group("Housing")
@export var growth_rate_housing: float = 0.5
## Desirability × max_cap is the ceiling housing demand can grow to.
@export var housing_max_cap: float = 1000.0

@export_group("Industrial")
@export var industrial_ratio: float = 0.5

@export_group("Commercial")
@export var commercial_ratio: float = 0.5

@export_group("Reference costs (bank render + tier placeholder)")
## floor(unserved / reference_cost) = "N banked" shown in HUD.
@export var ref_cost_housing: int = 5
@export var ref_cost_industrial: int = 20
@export var ref_cost_commercial: int = 30

@export_group("Starting balances")
## Seeded into total_demand at startup so the player can place a few buildings
## before the simulation has had time to generate any demand.
@export var starting_housing: float = 100.0
@export var starting_industrial: float = 100.0
@export var starting_commercial: float = 100.0

# ── Buckets ───────────────────────────────────────────────────────────────────

var buckets: Dictionary = {}                # type_id -> DemandBucket
var _bucket_order: Array[DemandBucket] = [] # preserves dependency order
var _sources: Array[CityStatSource] = []    # registered sources (for teardown)

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	_build_buckets()
	_register_sources()
	if _day_night:
		_day_night.hour_changed.connect(_on_hour)
	GameEvents.structure_demolished.connect(_on_demolished)
	GameEvents.map_loaded.connect(_on_map_loaded)
	# A registry might already be populated by Builder before our connect — sync now.
	_resync_fulfilled_from_registry()

func _build_buckets() -> void:
	var desirability := DesirabilityBucket.new()
	desirability.weight_satisfaction = desirability_weight_satisfaction
	desirability.weight_amenity      = desirability_weight_amenity
	desirability.amenity_saturation  = desirability_amenity_saturation

	var housing := HousingDemandBucket.new()
	housing.growth_rate    = growth_rate_housing
	housing.max_cap        = housing_max_cap
	housing.reference_cost = ref_cost_housing
	housing.total_demand   = starting_housing

	var industrial := IndustrialDemandBucket.new()
	industrial.ratio          = industrial_ratio
	industrial.reference_cost = ref_cost_industrial
	industrial.total_demand   = starting_industrial

	var commercial := CommercialDemandBucket.new()
	commercial.ratio          = commercial_ratio
	commercial.reference_cost = ref_cost_commercial
	commercial.total_demand   = starting_commercial

	_bucket_order = [desirability, housing, industrial, commercial]
	for b in _bucket_order:
		buckets[b.type_id] = b

func _register_sources() -> void:
	if _city_stats == null:
		return
	for b in _bucket_order:
		var src := b.make_source()
		_sources.append(src)
		_city_stats.register_source(src)

# ── Tick ──────────────────────────────────────────────────────────────────────

func _on_hour(hour: float) -> void:
	var context := {
		"satisfaction_score": _satisfaction.get_score() if _satisfaction else 1.0,
		"amenity_count":      _count_amenities(),
		"population":         _get_population(),
		"industrial_output":  _get_industrial_output(),
	}

	for b in _bucket_order:
		b.tick(hour, context)
		context[b.type_id] = b.total_demand

	print("[Demand] tick: desirability=%.2f housing=t%.1f/f%.1f/u%.1f industrial=t%.1f/f%.1f/u%.1f commercial=t%.1f/f%.1f/u%.1f output=%d" % [
		buckets["desirability"].total_demand,
		buckets["housing_demand"].total_demand,    buckets["housing_demand"].fulfilled,    buckets["housing_demand"].get_unserved(),
		buckets["industrial_demand"].total_demand, buckets["industrial_demand"].fulfilled, buckets["industrial_demand"].get_unserved(),
		buckets["commercial_demand"].total_demand, buckets["commercial_demand"].fulfilled, buckets["commercial_demand"].get_unserved(),
		context["industrial_output"],
	])

# ── Lookups ───────────────────────────────────────────────────────────────────

## UNSERVED value (the spendable amount) — preserves the legacy semantic of
## the now-renamed `get_value` for downstream consumers (CharacterSystem,
## UniqueRegistry, EventSystem condition ctx).
func get_value(type_id: String) -> float:
	return get_unserved(type_id)

func get_unserved(type_id: String) -> float:
	var b: DemandBucket = buckets.get(type_id)
	return b.get_unserved() if b else 0.0

func get_total(type_id: String) -> float:
	var b: DemandBucket = buckets.get(type_id)
	return b.total_demand if b else 0.0

func get_fulfilled(type_id: String) -> float:
	var b: DemandBucket = buckets.get(type_id)
	return b.fulfilled if b else 0.0

## Category → bucket_id mapping. Growth categories are spendable; anything
## else (nature, road, pavement, unique-specific) maps to "" = free placement.
static func bucket_for_category(category: String) -> String:
	match category:
		"residential": return "housing_demand"
		"workplace":   return "industrial_demand"
		"commercial":  return "commercial_demand"
		_:             return ""

## Short human-friendly name for toasts / HUD. "housing_demand" → "housing".
static func bucket_display_name(bucket_id: String) -> String:
	match bucket_id:
		"housing_demand":    return "housing"
		"industrial_demand": return "industrial"
		"commercial_demand": return "commercial"
		_:                   return bucket_id

# ── Spending ──────────────────────────────────────────────────────────────────

func _pool_config_for(structure: Structure) -> Dictionary:
	if structure == null or structure.pool_id.is_empty() or _catalog == null:
		return {}
	return _catalog.get_pool_config(structure.pool_id)

func _placement_params(structure: Structure) -> Dictionary:
	var params := {"bucket_id": "", "cost": 0.0, "threshold": 0.0}
	var profile := structure.find_metadata(BuildingProfile) as BuildingProfile
	if profile == null:
		return params
	var bucket_id := bucket_for_category(profile.category)
	if bucket_id == "":
		return params
	params["bucket_id"] = bucket_id
	params["cost"] = float(profile.capacity)
	var pool_cfg := _pool_config_for(structure)
	if not pool_cfg.is_empty():
		params["cost"] = float(pool_cfg.get("demand_per_unit", params["cost"]))
		params["threshold"] = float(pool_cfg.get("demand_threshold", 0))
	return params

## Non-mutating preview. Pool-gated structures must clear their tier threshold
## (against UNSERVED), and unserved must cover the cost.
func can_afford(structure: Structure) -> bool:
	if structure == null:
		return true
	var params := _placement_params(structure)
	var bucket_id: String = params["bucket_id"]
	if bucket_id.is_empty():
		return true
	var bucket: DemandBucket = buckets.get(bucket_id)
	if bucket == null:
		return true
	if bucket.get_unserved() < float(params["threshold"]):
		return false
	return bucket.get_unserved() >= float(params["cost"])

## Attempts to spend the demand required to place `structure`.
## Returns a Dictionary describing the outcome:
##   ok:        bool   — whether placement may proceed
##   bucket_id: String — matched bucket ("" for free placements)
##   cost:      float  — required demand for this placement
##   have:      float  — bucket UNSERVED pre-spend
##   threshold: float  — tier unlock threshold (0 for non-tiered)
##   reason:    String — "below_threshold" | "insufficient" | ""
## On success the bucket's `fulfilled` is incremented (total stays monotonic).
func try_spend(structure: Structure) -> Dictionary:
	var result := {"ok": true, "bucket_id": "", "cost": 0.0, "have": 0.0,
				   "threshold": 0.0, "reason": ""}

	var params := _placement_params(structure)
	var bucket_id: String = params["bucket_id"]
	if bucket_id.is_empty():
		return result
	var bucket: DemandBucket = buckets.get(bucket_id)
	if bucket == null:
		return result

	var cost: float = params["cost"]
	var threshold: float = params["threshold"]
	var unserved: float = bucket.get_unserved()
	result["bucket_id"] = bucket_id
	result["cost"]      = cost
	result["have"]      = unserved
	result["threshold"] = threshold

	if unserved < threshold:
		result["ok"] = false
		result["reason"] = "below_threshold"
		print("[Demand] place_blocked: bucket=%s reason=below_threshold threshold=%.1f unserved=%.1f" % [
			bucket_id, threshold, unserved
		])
		return result

	if unserved < cost:
		result["ok"] = false
		result["reason"] = "insufficient"
		print("[Demand] place_blocked: bucket=%s cost=%.1f unserved=%.1f" % [bucket_id, cost, unserved])
		return result

	bucket.add_fulfilled(cost)
	print("[Demand] spent: bucket=%s cost=%.1f fulfilled=%.1f unserved=%.1f" % [
		bucket_id, cost, bucket.fulfilled, bucket.get_unserved()
	])
	return result

# ── Fulfilled accounting (placement is via try_spend; demolish + map_loaded here) ─

func _on_demolished(pos: Vector3i) -> void:
	# We can't look up the demolished structure from `pos` after Builder has
	# already cleared the cell. Builder mirrors the registry though, so the
	# cleanest path is to fully resync from the post-demolish registry state.
	_resync_fulfilled_from_registry()

func _on_map_loaded(_map) -> void:
	# Placed buildings on the loaded map need their capacity counted into the
	# corresponding bucket's `fulfilled` so unserved comes out right.
	_resync_fulfilled_from_registry()

## Walks GameState.building_registry, sums per-bucket capacity, and writes
## each bucket's `fulfilled` to that total. Cheap enough — only fires on
## demolish / map_loaded, not per tick.
func _resync_fulfilled_from_registry() -> void:
	if buckets.is_empty():
		return
	var totals := {"housing_demand": 0.0, "industrial_demand": 0.0, "commercial_demand": 0.0}
	if GameState and GameState.building_registry:
		for bid in GameState.building_registry:
			var entry: Dictionary = GameState.building_registry[bid]
			var sid: int = int(entry.get("structure", -1))
			if sid < 0 or sid >= GameState.structures.size():
				continue
			var s: Structure = GameState.structures[sid]
			var profile := s.find_metadata(BuildingProfile) as BuildingProfile
			if profile == null:
				continue
			# Cost: pool config wins over profile.capacity, mirroring _placement_params.
			var cost: float = float(profile.capacity)
			if not s.pool_id.is_empty() and _catalog:
				var cfg: Dictionary = _catalog.get_pool_config(s.pool_id)
				if not cfg.is_empty():
					cost = float(cfg.get("demand_per_unit", cost))
			var bucket_id := bucket_for_category(profile.category)
			if not totals.has(bucket_id):
				continue
			totals[bucket_id] += cost
	for bid in totals:
		var b: DemandBucket = buckets.get(bid)
		if b:
			b.set_fulfilled(totals[bid])

# ── Inputs ────────────────────────────────────────────────────────────────────

func _get_population() -> int:
	var residential := PluginManager.get_plugin("Residential")
	if residential and residential.has_method("get_current_population"):
		return residential.get_current_population()
	return 0

func _get_industrial_output() -> int:
	var workplace := PluginManager.get_plugin("Workplace")
	if workplace and workplace.has_method("get_total_output"):
		return workplace.get_total_output()
	return 0

## Count buildings whose catalog summary flags them as category "nature".
func _count_amenities() -> int:
	if _catalog == null:
		return 0
	var summaries: Array = _catalog.get_summary()
	if summaries.is_empty():
		return 0
	var count := 0
	for bid in GameState.building_registry:
		var entry: Dictionary = GameState.building_registry[bid]
		var sid: int = entry.get("structure", -1)
		if sid < 0 or sid >= summaries.size():
			continue
		var summary: Dictionary = summaries[sid]
		if summary.get("category", "") == "nature":
			count += 1
	return count
