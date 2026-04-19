extends PluginBase

## Demand system — four buckets ticked once per in-game hour.
##
##   desirability  → 0..1, blend of satisfaction score + amenity coverage
##   housing       → monotonically non-decreasing, grows with desirability
##   industrial    → tracks population (target = pop × ratio), eased
##   commercial    → tracks industrial (target = ind × ratio), eased
##
## Each bucket also registers a CityStatSource so downstream plugins (e.g.
## the Phase 2 tier gating, HUD polling) can read the current value via the
## existing CityStats machinery instead of peeking at plugin internals.
##
## The buckets themselves consume upstream values through a context dict
## assembled each tick — CityStats sinks would require int round-trips that
## are lossy for 0..1 desirability, so the context is the single source of
## truth for intra-tick plumbing.

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
## Mad high on purpose — rebalance once M2 tiers shake out real numbers.
@export var housing_max_cap: float = 1000.0

@export_group("Industrial")
@export var industrial_ratio: float = 0.5
@export var industrial_adjust_rate: float = 0.25

@export_group("Commercial")
@export var commercial_ratio: float = 0.5
@export var commercial_adjust_rate: float = 0.25

@export_group("Reference costs (bank render + M2 tier placeholder)")
## floor(bucket.value / reference_cost) = "N banked" shown in HUD.
## These match the smallest current catalog capacity in each category;
## M2 tier gating will override per-tier.
@export var ref_cost_housing: int = 5
@export var ref_cost_industrial: int = 20
@export var ref_cost_commercial: int = 30

@export_group("Starting balances")
## Seeded into the three growth buckets at startup so the player can place
## a few buildings before the simulation has had time to generate any demand.
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

func _build_buckets() -> void:
	var desirability := DesirabilityBucket.new()
	desirability.weight_satisfaction = desirability_weight_satisfaction
	desirability.weight_amenity      = desirability_weight_amenity
	desirability.amenity_saturation  = desirability_amenity_saturation

	var housing := HousingDemandBucket.new()
	housing.growth_rate    = growth_rate_housing
	housing.max_cap        = housing_max_cap
	housing.reference_cost = ref_cost_housing
	housing.value          = starting_housing
	# Floor the seed too — housing's "no shrinkage" rule should also protect
	# the starting grant from being eaten by a low-desirability first tick.
	housing.floor_value    = starting_housing

	var industrial := IndustrialDemandBucket.new()
	industrial.ratio          = industrial_ratio
	industrial.adjust_rate    = industrial_adjust_rate
	industrial.reference_cost = ref_cost_industrial
	industrial.value          = starting_industrial

	var commercial := CommercialDemandBucket.new()
	commercial.ratio          = commercial_ratio
	commercial.adjust_rate    = commercial_adjust_rate
	commercial.reference_cost = ref_cost_commercial
	commercial.value          = starting_commercial

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
	# CityStats.hour_changed runs first (plugin topo order) so Workplace's
	# _WorkerSink.last_fulfilled is already refreshed by the time we query output.
	var context := {
		"satisfaction_score": _satisfaction.get_score() if _satisfaction else 1.0,
		"amenity_count":      _count_amenities(),
		"population":         _get_population(),
		"industrial_output":  _get_industrial_output(),
	}

	for b in _bucket_order:
		b.tick(hour, context)
		context[b.type_id] = b.value

	print("[Demand] tick: desirability=%.2f housing=%.1f industrial=%.1f commercial=%.1f output=%d" % [
		buckets["desirability"].value,
		buckets["housing_demand"].value,
		buckets["industrial_demand"].value,
		buckets["commercial_demand"].value,
		context["industrial_output"],
	])
	for b in _bucket_order:
		print("[Demand] emit: bucket=%s value=%.2f" % [b.type_id, b.value])

# ── Lookups ───────────────────────────────────────────────────────────────────

func get_value(type_id: String) -> float:
	var b: DemandBucket = buckets.get(type_id)
	return b.value if b else 0.0

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

## Non-mutating preview — would `try_spend(structure)` succeed right now?
## Returns true for free placements (roads, nature, anything without a profile
## or with an unknown category) — they skip the demand gate entirely.
func can_afford(structure: Structure) -> bool:
	if structure == null:
		return true
	var profile := structure.find_metadata(BuildingProfile) as BuildingProfile
	if profile == null:
		return true
	var bucket_id := bucket_for_category(profile.category)
	if bucket_id == "":
		return true
	var bucket: DemandBucket = buckets.get(bucket_id)
	if bucket == null:
		return true
	return bucket.value >= float(profile.capacity)

## Attempts to spend the demand required to place `structure`.
## Returns a Dictionary describing the outcome:
##   ok:        bool   — whether placement may proceed
##   bucket_id: String — matched bucket ("" for free placements)
##   cost:      float  — required demand for this placement
##   have:      float  — bucket value pre-spend (useful for shortfall messages)
## Free placements (no profile / non-growth category) yield ok=true with empty
## bucket_id and zero cost. Blocked placements leave the bucket untouched.
func try_spend(structure: Structure) -> Dictionary:
	var result := {"ok": true, "bucket_id": "", "cost": 0.0, "have": 0.0}

	var profile := structure.find_metadata(BuildingProfile) as BuildingProfile
	if profile == null:
		return result  # roads, nature, anything without a profile → free
	var bucket_id := bucket_for_category(profile.category)
	if bucket_id == "":
		return result  # unknown category → free (forward-compat)
	var bucket: DemandBucket = buckets.get(bucket_id)
	if bucket == null:
		return result

	var cost := float(profile.capacity)
	result["bucket_id"] = bucket_id
	result["cost"] = cost
	result["have"] = bucket.value

	if bucket.value < cost:
		result["ok"] = false
		print("[Demand] place_blocked: bucket=%s cost=%.1f value=%.1f" % [bucket_id, cost, bucket.value])
		return result

	bucket.value -= cost
	GameEvents.demand_changed.emit(bucket_id, bucket.value)
	print("[Demand] spent: bucket=%s cost=%.1f remaining=%.1f" % [bucket_id, cost, bucket.value])
	return result

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
## Parks / greenery / duck pond / nature patch — the Phase 1 amenity set.
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
