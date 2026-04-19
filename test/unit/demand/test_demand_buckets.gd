extends GutTest

## Unit tests for the demand system (Phase 1 / M1).
##
## Each bucket is exercised in isolation via its .tick(hour, context) entry
## point — no DayNight ticking, no plugin boot. The final test reaches into
## a live CityStats to confirm buckets' CityStatSources flow through.

const DesirabilityBucketCls    := preload("res://scripts/demand/desirability_bucket.gd")
const HousingDemandBucketCls   := preload("res://scripts/demand/housing_demand_bucket.gd")
const IndustrialDemandBucketCls := preload("res://scripts/demand/industrial_demand_bucket.gd")
const CommercialDemandBucketCls := preload("res://scripts/demand/commercial_demand_bucket.gd")
const CityStatsPluginCls       := preload("res://plugins/city_stats/city_stats_plugin.gd")
const DemandPluginCls          := preload("res://plugins/demand/demand_plugin.gd")

# ── Base class signal emission ────────────────────────────────────────────────

func test_bucket_base_emits_on_tick() -> void:
	var bucket := DesirabilityBucketCls.new()
	watch_signals(GameEvents)
	bucket.tick(0.0, {"satisfaction_score": 1.0, "amenity_count": 0})
	assert_signal_emitted(GameEvents, "demand_changed", "demand_changed should fire on tick")
	var params: Array = get_signal_parameters(GameEvents, "demand_changed", 0)
	assert_eq(params[0], "desirability", "bucket_type_id should be the bucket's type_id")
	assert_almost_eq(params[1], bucket.value, 0.0001, "emitted value must match cached bucket.value")

# ── Desirability clamp ────────────────────────────────────────────────────────

func test_desirability_clamped_0_1() -> void:
	var bucket := DesirabilityBucketCls.new()

	# Max possible: satisfaction=1.0, amenities saturate the term.
	bucket.tick(0.0, {"satisfaction_score": 1.0, "amenity_count": 9999})
	assert_lt(bucket.value, 1.00001, "desirability must not exceed 1.0")
	assert_almost_eq(bucket.value, 1.0, 0.0001, "max inputs should produce 1.0")

	# Min possible: all zero.
	bucket.value = 0.0
	bucket.tick(0.0, {"satisfaction_score": 0.0, "amenity_count": 0})
	assert_eq(bucket.value, 0.0, "zero inputs should produce 0.0")

	# Ridiculous negatives (shouldn't happen in practice) still clamp.
	bucket.tick(0.0, {"satisfaction_score": -5.0, "amenity_count": 0})
	assert_gt(bucket.value, -0.00001, "desirability must not go negative")

# ── Housing never shrinks ─────────────────────────────────────────────────────

func test_housing_demand_floor() -> void:
	var bucket := HousingDemandBucketCls.new()
	bucket.growth_rate = 1.0

	# Grow for a few ticks with high desirability.
	for i in 3:
		bucket.tick(0.0, {"desirability": 1.0})
	var peak: float = bucket.value
	assert_gt(peak, 0.0, "housing should have risen above zero")

	# Now desirability collapses — value must not decrease.
	for i in 5:
		bucket.tick(0.0, {"desirability": 0.0})
		assert_gte(bucket.value, peak, "housing_demand must not shrink (floor violated)")

	# Even if a subclass _compute returned a smaller value, floor holds.
	bucket.value = 10.0
	bucket.tick(0.0, {"desirability": 0.0})
	assert_gte(bucket.value, 10.0, "floor equals prior value — must never decrease")

# ── Industrial tracks population ──────────────────────────────────────────────

func test_industrial_tracks_population() -> void:
	var bucket := IndustrialDemandBucketCls.new()
	bucket.ratio = 0.5
	bucket.adjust_rate = 1.0  # full step — no easing, for a deterministic assertion

	bucket.tick(0.0, {"population": 100})
	assert_almost_eq(bucket.value, 50.0, 0.0001, "target = pop × ratio, adjust_rate=1 snaps to target")

	bucket.tick(0.0, {"population": 20})
	assert_almost_eq(bucket.value, 10.0, 0.0001, "lower population → lower target (not a floor)")

	# With easing, bucket moves *toward* target but not all the way.
	var eased := IndustrialDemandBucketCls.new()
	eased.ratio = 0.5
	eased.adjust_rate = 0.25
	eased.tick(0.0, {"population": 100})  # target=50, value moves from 0 toward 50
	assert_almost_eq(eased.value, 12.5, 0.0001, "adjust_rate=0.25 → 25% of the 0→50 gap")

# ── Commercial tracks industrial with easing ──────────────────────────────────

func test_commercial_tracks_industrial_output() -> void:
	# Commercial follows industrial OUTPUT (filled-workplace production), not
	# industrial demand. Unstaffed factories generate no commercial demand.
	var bucket := CommercialDemandBucketCls.new()
	bucket.ratio = 0.5
	bucket.adjust_rate = 0.25

	# First tick: no output → target=0 → commercial stays at 0.
	bucket.tick(0.0, {"industrial_output": 0})
	assert_eq(bucket.value, 0.0)

	# Output jumps to 40 → target=20. With adjust_rate=0.25 and value=0,
	# commercial rises toward target but does NOT reach it in one tick — the
	# easing creates the intentional one-tick lag behind output.
	bucket.tick(0.0, {"industrial_output": 40})
	assert_almost_eq(bucket.value, 5.0, 0.0001, "one-step-eased commercial should be 25% of gap")
	assert_lt(bucket.value, 20.0, "commercial must lag output's target on first tick")

	# Several more ticks converge.
	for i in 30:
		bucket.tick(0.0, {"industrial_output": 40})
	assert_almost_eq(bucket.value, 20.0, 0.01, "commercial converges to target over many ticks")

	# Output falling back to 0 → commercial DOES shrink (no floor, unlike housing).
	for i in 30:
		bucket.tick(0.0, {"industrial_output": 0})
	assert_almost_eq(bucket.value, 0.0, 0.01, "commercial eases back down when output collapses")

# ── Tick order inside DemandPlugin ────────────────────────────────────────────

func test_tick_order() -> void:
	# Simulate the plugin's tick choreography by running the buckets in order
	# and asserting each one sees the just-computed upstream value.
	var desirability := DesirabilityBucketCls.new()
	var housing      := HousingDemandBucketCls.new()
	var industrial   := IndustrialDemandBucketCls.new()
	var commercial   := CommercialDemandBucketCls.new()
	housing.growth_rate      = 1.0
	industrial.adjust_rate   = 1.0
	commercial.adjust_rate   = 1.0

	var context := {
		"satisfaction_score": 1.0,
		"amenity_count":      10,  # hits saturation → amenity term = 1.0
		"population":         50,
		"industrial_output":  40,  # produced by Workplace — fed in by the plugin each tick
	}

	desirability.tick(0.0, context); context["desirability"]      = desirability.value
	housing.tick     (0.0, context); context["housing_demand"]    = housing.value
	industrial.tick  (0.0, context); context["industrial_demand"] = industrial.value
	commercial.tick  (0.0, context); context["commercial_demand"] = commercial.value

	# Desirability saturates at 1.0 (both weights pegged).
	assert_almost_eq(desirability.value, 1.0, 0.0001)
	# Housing grew by growth_rate × desirability = 1.0.
	assert_almost_eq(housing.value, 1.0, 0.0001)
	# Industrial target = population × 0.5 = 25, adjust=1 → snaps to 25.
	assert_almost_eq(industrial.value, 25.0, 0.0001)
	# Commercial target = industrial_output × 0.5 = 20, adjust=1 → snaps to 20.
	# (Confirms commercial reads industrial_output, not industrial_demand.)
	assert_almost_eq(commercial.value, 20.0, 0.0001)

# ── Housing caps at desirability × max_cap ───────────────────────────────────

func test_housing_caps_at_desirability_times_max() -> void:
	var bucket := HousingDemandBucketCls.new()
	bucket.growth_rate = 1000.0  # huge — want to test that the cap, not the rate, is the ceiling
	bucket.max_cap     = 100.0

	# desirability=0.5 → cap = 50. After one oversized growth step, value pins at 50.
	bucket.tick(0.0, {"desirability": 0.5})
	assert_almost_eq(bucket.value, 50.0, 0.0001, "housing should pin at desirability × max_cap")

	# Another tick at same desirability — already at cap, no growth.
	bucket.tick(0.0, {"desirability": 0.5})
	assert_almost_eq(bucket.value, 50.0, 0.0001, "no growth once at cap")

	# Desirability rises to 1.0 — new cap = 100, housing can grow further.
	bucket.tick(0.0, {"desirability": 1.0})
	assert_almost_eq(bucket.value, 100.0, 0.0001, "higher desirability lifts the cap")

	# Desirability collapses to 0.1 — new cap = 10. Value=100 is above cap but
	# the floor protects against shrinking. Value stays at 100.
	bucket.tick(0.0, {"desirability": 0.1})
	assert_eq(bucket.value, 100.0, "floor protects value when cap drops below it")

# ── Spending via DemandPlugin.try_spend ───────────────────────────────────────

func _make_structure_with_profile(category: String, capacity: int) -> Structure:
	var s := Structure.new()
	var p := BuildingProfile.new()
	p.category = category
	p.capacity = capacity
	var meta: Array[StructureMetadata] = [p]
	s.metadata = meta
	return s

## Build a DemandPlugin with buckets wired up but no DayNight/CityStats hookups —
## just enough to exercise try_spend.
func _minimal_demand_plugin() -> Node:
	var plugin: Node = DemandPluginCls.new()
	add_child(plugin)
	plugin._build_buckets()
	return plugin

func test_try_spend_debits_bucket() -> void:
	var plugin := _minimal_demand_plugin()
	plugin.buckets["housing_demand"].value = 20.0
	var house := _make_structure_with_profile("residential", 5)

	watch_signals(GameEvents)
	var info: Dictionary = plugin.try_spend(house)

	assert_true(info["ok"], "try_spend should succeed when bucket >= cost")
	assert_eq(info["bucket_id"], "housing_demand")
	assert_almost_eq(info["cost"], 5.0, 0.0001)
	assert_almost_eq(info["have"], 20.0, 0.0001, "have should report pre-spend value")
	assert_almost_eq(plugin.buckets["housing_demand"].value, 15.0, 0.0001, "bucket debited by capacity")
	assert_signal_emitted(GameEvents, "demand_changed", "spend must re-emit the signal so HUD updates")
	plugin.queue_free()

func test_try_spend_blocks_when_insufficient() -> void:
	var plugin := _minimal_demand_plugin()
	plugin.buckets["housing_demand"].value = 3.0
	var house := _make_structure_with_profile("residential", 5)

	watch_signals(GameEvents)
	var info: Dictionary = plugin.try_spend(house)

	assert_false(info["ok"], "try_spend must return ok=false when bucket < cost")
	assert_eq(info["bucket_id"], "housing_demand", "block still reports which bucket fell short")
	assert_almost_eq(info["cost"], 5.0, 0.0001)
	assert_almost_eq(info["have"], 3.0, 0.0001, "have reports current bucket value for the toast")
	assert_almost_eq(plugin.buckets["housing_demand"].value, 3.0, 0.0001, "bucket untouched on block")
	assert_signal_not_emitted(GameEvents, "demand_changed", "no spend emit when blocked")
	plugin.queue_free()

func test_try_spend_free_for_non_growth() -> void:
	var plugin := _minimal_demand_plugin()
	# Seed all buckets so any accidental debit is visible.
	for id in ["housing_demand", "industrial_demand", "commercial_demand"]:
		plugin.buckets[id].value = 50.0

	# No-profile structure (e.g. a road or grass tile) — must be free.
	var road := Structure.new()
	var road_info: Dictionary = plugin.try_spend(road)
	assert_true(road_info["ok"], "no-profile structures must be free")
	assert_eq(road_info["bucket_id"], "", "free placements carry no bucket_id")

	# Unknown category (e.g. a future "public" or "infrastructure") — also free.
	var unknown := _make_structure_with_profile("infrastructure", 10)
	var unknown_info: Dictionary = plugin.try_spend(unknown)
	assert_true(unknown_info["ok"], "unknown categories default to free")
	assert_eq(unknown_info["bucket_id"], "")

	for id in ["housing_demand", "industrial_demand", "commercial_demand"]:
		assert_almost_eq(plugin.buckets[id].value, 50.0, 0.0001,
				"%s should be untouched by free placements" % id)
	plugin.queue_free()

func test_try_spend_routes_by_category() -> void:
	var plugin := _minimal_demand_plugin()
	plugin.buckets["housing_demand"].value    = 100.0
	plugin.buckets["industrial_demand"].value = 100.0
	plugin.buckets["commercial_demand"].value = 100.0

	assert_true(plugin.try_spend(_make_structure_with_profile("residential", 5))["ok"])
	assert_true(plugin.try_spend(_make_structure_with_profile("workplace", 20))["ok"])
	assert_true(plugin.try_spend(_make_structure_with_profile("commercial", 30))["ok"])

	assert_almost_eq(plugin.buckets["housing_demand"].value,    95.0,  0.0001)
	assert_almost_eq(plugin.buckets["industrial_demand"].value, 80.0,  0.0001)
	assert_almost_eq(plugin.buckets["commercial_demand"].value, 70.0,  0.0001)
	plugin.queue_free()

# ── Bank render helper ────────────────────────────────────────────────────────

func test_bank_count_is_floor_of_value_over_reference_cost() -> void:
	var bucket := HousingDemandBucketCls.new()
	bucket.reference_cost = 5
	bucket.value = 12.7
	assert_eq(bucket.get_bank_count(), 2, "12.7 / 5 → floor = 2")

	bucket.value = 4.9
	assert_eq(bucket.get_bank_count(), 0, "value below reference_cost → 0 banked")

	bucket.reference_cost = 0
	bucket.value = 100.0
	assert_eq(bucket.get_bank_count(), 0, "reference_cost=0 means non-spendable → 0")

# ── CityStats source integration ──────────────────────────────────────────────

func test_source_sink_integration() -> void:
	# Register a bucket's CityStatSource with a live CityStats and tick it
	# directly (bypass DayNight) — the bucket's value should flow through as
	# the supply for its type_id.
	var stats: Node = CityStatsPluginCls.new()
	add_child(stats)
	# Drive the tick directly; skip _plugin_ready's DayNight connect.
	stats._day_night = null

	var bucket := IndustrialDemandBucketCls.new()
	bucket.adjust_rate = 1.0
	bucket.tick(0.0, {"population": 60})  # value becomes 30
	assert_almost_eq(bucket.value, 30.0, 0.0001)

	var src := bucket.make_source()
	stats.register_source(src)

	# Watch stats_ticked — its supply dict should contain our type_id.
	watch_signals(stats)
	stats._on_hour(0.0)
	assert_signal_emitted(stats, "stats_ticked")
	var params: Array = get_signal_parameters(stats, "stats_ticked", 0)
	var supply: Dictionary = params[0]
	assert_true(supply.has("industrial_demand"), "bucket source should contribute supply")
	assert_eq(supply["industrial_demand"], 30, "supply should equal bucket.value × source_scale")

	stats.queue_free()

# ── Pool-driven threshold & per-unit cost ─────────────────────────────────────

class StubCatalog:
	extends PluginBase
	var configs: Dictionary = {}
	func get_plugin_name() -> String: return "BuildingCatalog"
	func get_pool_config(pool_id: String) -> Dictionary:
		return configs.get(pool_id, {})

func _make_generic_residence(pool_id: String, capacity: int) -> Structure:
	var s := _make_structure_with_profile("residential", capacity)
	s.pool_id = pool_id
	return s

func test_pool_cost_overrides_profile_capacity() -> void:
	var plugin := _minimal_demand_plugin()
	var catalog := StubCatalog.new()
	catalog.configs["residential_t1"] = {"demand_per_unit": 5, "demand_threshold": 0}
	plugin._catalog = catalog

	plugin.buckets["housing_demand"].value = 20.0
	# Profile.capacity=99 should be ignored because the pool config supplies a cost.
	var house := _make_generic_residence("residential_t1", 99)

	var info: Dictionary = plugin.try_spend(house)
	assert_true(info["ok"], "pool-configured cost of 5 is well under bucket value of 20")
	assert_almost_eq(info["cost"], 5.0, 0.0001, "cost should come from pool config, not profile.capacity")
	assert_almost_eq(plugin.buckets["housing_demand"].value, 15.0, 0.0001, "only pool cost debited")
	catalog.free()
	plugin.queue_free()

func test_threshold_gates_tier() -> void:
	var plugin := _minimal_demand_plugin()
	var catalog := StubCatalog.new()
	catalog.configs["residential_t2"] = {"demand_per_unit": 15, "demand_threshold": 30}
	plugin._catalog = catalog

	# Value above cost but below threshold — blocked with reason=below_threshold.
	plugin.buckets["housing_demand"].value = 20.0
	var tower := _make_generic_residence("residential_t2", 12)

	assert_false(plugin.can_afford(tower), "tier locked until threshold clears")
	var blocked: Dictionary = plugin.try_spend(tower)
	assert_false(blocked["ok"], "try_spend blocked below threshold")
	assert_eq(blocked.get("reason", ""), "below_threshold")
	assert_almost_eq(plugin.buckets["housing_demand"].value, 20.0, 0.0001, "bucket untouched when locked")

	# Once threshold clears, it unlocks.
	plugin.buckets["housing_demand"].value = 35.0
	assert_true(plugin.can_afford(tower), "threshold met — tower is affordable")
	var ok: Dictionary = plugin.try_spend(tower)
	assert_true(ok["ok"])
	assert_almost_eq(plugin.buckets["housing_demand"].value, 20.0, 0.0001, "35 - 15 = 20 after spend")

	catalog.free()
	plugin.queue_free()

func test_can_afford_preview_is_nonmutating() -> void:
	var plugin := _minimal_demand_plugin()
	plugin.buckets["housing_demand"].value = 10.0
	var house := _make_structure_with_profile("residential", 5)

	watch_signals(GameEvents)
	var before: float = plugin.buckets["housing_demand"].value
	assert_true(plugin.can_afford(house))
	assert_almost_eq(plugin.buckets["housing_demand"].value, before, 0.0001, "preview must not mutate")
	assert_signal_not_emitted(GameEvents, "demand_changed", "preview must not emit")
	plugin.queue_free()
