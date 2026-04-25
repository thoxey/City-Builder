extends GutTest

## Unit tests for the demand system.
##
## Each bucket carries three numbers post-refactor:
##   total_demand — monotonic accumulator (desirability is non-monotonic — a rate)
##   fulfilled    — sum of placed-building capacity in the bucket
##   unserved     — derived: max(0, total - fulfilled). What the player can spend.
##
## Tests exercise buckets in isolation via .tick() and add_fulfilled/remove_fulfilled,
## plus DemandPlugin.try_spend/can_afford for the spend-gate.

const DesirabilityBucketCls    := preload("res://scripts/demand/desirability_bucket.gd")
const HousingDemandBucketCls   := preload("res://scripts/demand/housing_demand_bucket.gd")
const IndustrialDemandBucketCls := preload("res://scripts/demand/industrial_demand_bucket.gd")
const CommercialDemandBucketCls := preload("res://scripts/demand/commercial_demand_bucket.gd")
const CityStatsPluginCls       := preload("res://plugins/city_stats/city_stats_plugin.gd")
const DemandPluginCls          := preload("res://plugins/demand/demand_plugin.gd")

# ── Base class signal emission ────────────────────────────────────────────────

func test_bucket_base_emits_unserved_on_tick() -> void:
	var bucket := DesirabilityBucketCls.new()
	watch_signals(GameEvents)
	bucket.tick(0.0, {"satisfaction_score": 1.0, "amenity_count": 0})
	assert_signal_emitted(GameEvents, "demand_unserved_changed", "unserved signal fires every tick")
	var params: Array = get_signal_parameters(GameEvents, "demand_unserved_changed", 0)
	assert_eq(params[0], "desirability", "bucket_type_id should be the bucket's type_id")
	assert_almost_eq(params[1], bucket.get_unserved(), 0.0001, "emitted value matches unserved")

func test_bucket_emits_total_changed_when_total_grows() -> void:
	var bucket := HousingDemandBucketCls.new()
	bucket.growth_rate = 5.0
	bucket.total_demand = 0.0
	watch_signals(GameEvents)
	bucket.tick(0.0, {"desirability": 1.0})
	assert_signal_emitted(GameEvents, "demand_total_changed", "total grows on first tick")

# ── Desirability — non-monotonic 0..1 rate ───────────────────────────────────

func test_desirability_clamped_0_1() -> void:
	var bucket := DesirabilityBucketCls.new()
	bucket.tick(0.0, {"satisfaction_score": 1.0, "amenity_count": 9999})
	assert_almost_eq(bucket.total_demand, 1.0, 0.0001, "max inputs should produce 1.0")

	bucket.tick(0.0, {"satisfaction_score": 0.0, "amenity_count": 0})
	assert_eq(bucket.total_demand, 0.0, "zero inputs should produce 0.0")

	bucket.tick(0.0, {"satisfaction_score": -5.0, "amenity_count": 0})
	assert_gt(bucket.total_demand, -0.00001, "must not go negative")

func test_desirability_can_drop() -> void:
	# Non-monotonic: tracks live state, can decrease tick-to-tick.
	var bucket := DesirabilityBucketCls.new()
	bucket.tick(0.0, {"satisfaction_score": 1.0, "amenity_count": 100})
	var peak: float = bucket.total_demand
	assert_gt(peak, 0.5, "should be high")

	bucket.tick(0.0, {"satisfaction_score": 0.0, "amenity_count": 0})
	assert_lt(bucket.total_demand, peak, "desirability must shrink with the inputs")

# ── Housing — monotonic total, capped by desirability × max_cap ──────────────

func test_housing_total_monotonic() -> void:
	var bucket := HousingDemandBucketCls.new()
	bucket.growth_rate = 1.0

	for i in 3:
		bucket.tick(0.0, {"desirability": 1.0})
	var peak: float = bucket.total_demand
	assert_gt(peak, 0.0, "housing total should have risen")

	for i in 5:
		bucket.tick(0.0, {"desirability": 0.0})
		assert_gte(bucket.total_demand, peak, "monotonic clamp must hold total")

func test_housing_caps_at_desirability_times_max() -> void:
	var bucket := HousingDemandBucketCls.new()
	bucket.growth_rate = 1000.0
	bucket.max_cap     = 100.0

	bucket.tick(0.0, {"desirability": 0.5})
	assert_almost_eq(bucket.total_demand, 50.0, 0.0001, "pin at desirability × max_cap")

	bucket.tick(0.0, {"desirability": 0.5})
	assert_almost_eq(bucket.total_demand, 50.0, 0.0001, "no growth at cap")

	bucket.tick(0.0, {"desirability": 1.0})
	assert_almost_eq(bucket.total_demand, 100.0, 0.0001, "higher desirability lifts cap")

	# Cap drops below total — monotonic clamp protects total.
	bucket.tick(0.0, {"desirability": 0.1})
	assert_eq(bucket.total_demand, 100.0, "monotonic protects total when cap drops")

# ── Industrial / Commercial — monotonic, no easing ───────────────────────────

func test_industrial_tracks_population_monotonic() -> void:
	var bucket := IndustrialDemandBucketCls.new()
	bucket.ratio = 0.5

	bucket.tick(0.0, {"population": 100})
	assert_almost_eq(bucket.total_demand, 50.0, 0.0001, "snaps to pop × ratio")

	bucket.tick(0.0, {"population": 20})
	assert_almost_eq(bucket.total_demand, 50.0, 0.0001, "monotonic — total holds when pop drops")

	bucket.tick(0.0, {"population": 200})
	assert_almost_eq(bucket.total_demand, 100.0, 0.0001, "rises with pop")

func test_commercial_tracks_industrial_output_monotonic() -> void:
	var bucket := CommercialDemandBucketCls.new()
	bucket.ratio = 0.5

	bucket.tick(0.0, {"industrial_output": 0})
	assert_eq(bucket.total_demand, 0.0)

	bucket.tick(0.0, {"industrial_output": 40})
	assert_almost_eq(bucket.total_demand, 20.0, 0.0001, "snaps to output × ratio")

	bucket.tick(0.0, {"industrial_output": 0})
	assert_almost_eq(bucket.total_demand, 20.0, 0.0001, "monotonic — total holds")

# ── Tick order (DemandPlugin choreography) ───────────────────────────────────

func test_tick_order() -> void:
	var desirability := DesirabilityBucketCls.new()
	var housing      := HousingDemandBucketCls.new()
	var industrial   := IndustrialDemandBucketCls.new()
	var commercial   := CommercialDemandBucketCls.new()
	housing.growth_rate = 1.0

	var context := {
		"satisfaction_score": 1.0,
		"amenity_count":      10,
		"population":         50,
		"industrial_output":  40,
	}

	desirability.tick(0.0, context); context["desirability"]      = desirability.total_demand
	housing.tick     (0.0, context); context["housing_demand"]    = housing.total_demand
	industrial.tick  (0.0, context); context["industrial_demand"] = industrial.total_demand
	commercial.tick  (0.0, context); context["commercial_demand"] = commercial.total_demand

	assert_almost_eq(desirability.total_demand, 1.0, 0.0001)
	assert_almost_eq(housing.total_demand, 1.0, 0.0001)
	assert_almost_eq(industrial.total_demand, 25.0, 0.0001)
	assert_almost_eq(commercial.total_demand, 20.0, 0.0001)

# ── Fulfilled accounting ─────────────────────────────────────────────────────

func test_fulfilled_add_remove_emits_signals() -> void:
	var bucket := HousingDemandBucketCls.new()
	bucket.total_demand = 100.0

	watch_signals(GameEvents)
	bucket.add_fulfilled(30.0)
	assert_almost_eq(bucket.fulfilled, 30.0, 0.0001)
	assert_almost_eq(bucket.get_unserved(), 70.0, 0.0001, "unserved drops by fulfilled")
	assert_signal_emitted(GameEvents, "demand_fulfilled_changed")
	assert_signal_emitted(GameEvents, "demand_unserved_changed")

	bucket.remove_fulfilled(10.0)
	assert_almost_eq(bucket.fulfilled, 20.0, 0.0001)
	assert_almost_eq(bucket.get_unserved(), 80.0, 0.0001, "remove returns capacity to unserved")

func test_fulfilled_clamps_at_zero() -> void:
	var bucket := HousingDemandBucketCls.new()
	bucket.total_demand = 10.0
	bucket.add_fulfilled(5.0)
	bucket.remove_fulfilled(20.0)
	assert_eq(bucket.fulfilled, 0.0, "must not go negative")

# ── Bank render ──────────────────────────────────────────────────────────────

func test_bank_count_is_floor_of_unserved_over_reference_cost() -> void:
	var bucket := HousingDemandBucketCls.new()
	bucket.reference_cost = 5
	bucket.total_demand = 12.7
	assert_eq(bucket.get_bank_count(), 2, "12.7 / 5 → floor 2")

	bucket.add_fulfilled(5.0)
	# unserved = 12.7 - 5 = 7.7 → bank = 1
	assert_eq(bucket.get_bank_count(), 1, "fulfilled reduces bank")

	bucket.reference_cost = 0
	assert_eq(bucket.get_bank_count(), 0, "non-spendable → 0")

# ── CityStats source publishes UNSERVED ──────────────────────────────────────

func test_source_publishes_unserved() -> void:
	var stats: Node = CityStatsPluginCls.new()
	add_child(stats)
	stats._day_night = null

	var bucket := IndustrialDemandBucketCls.new()
	bucket.tick(0.0, {"population": 60})  # total = 30
	bucket.add_fulfilled(10.0)             # unserved = 20

	var src := bucket.make_source()
	stats.register_source(src)

	watch_signals(stats)
	stats._on_hour(0.0)
	var params: Array = get_signal_parameters(stats, "stats_ticked", 0)
	var supply: Dictionary = params[0]
	assert_eq(supply["industrial_demand"], 20, "supply = unserved × source_scale")

	stats.queue_free()

# ── DemandPlugin spend (uses unserved gate, increments fulfilled) ────────────

func _make_structure_with_profile(category: String, capacity: int) -> Structure:
	var s := Structure.new()
	var p := BuildingProfile.new()
	p.category = category
	p.capacity = capacity
	var meta: Array[StructureMetadata] = [p]
	s.metadata = meta
	return s

func _minimal_demand_plugin() -> Node:
	var plugin: Node = DemandPluginCls.new()
	add_child(plugin)
	plugin._build_buckets()
	return plugin

func test_try_spend_increments_fulfilled() -> void:
	var plugin := _minimal_demand_plugin()
	plugin.buckets["housing_demand"].total_demand = 20.0
	var house := _make_structure_with_profile("residential", 5)

	watch_signals(GameEvents)
	var info: Dictionary = plugin.try_spend(house)

	assert_true(info["ok"], "succeeds when unserved >= cost")
	assert_eq(info["bucket_id"], "housing_demand")
	assert_almost_eq(info["cost"], 5.0, 0.0001)
	assert_almost_eq(info["have"], 20.0, 0.0001, "have reports pre-spend UNSERVED")
	assert_almost_eq(plugin.buckets["housing_demand"].fulfilled, 5.0, 0.0001, "fulfilled bumped")
	assert_almost_eq(plugin.buckets["housing_demand"].get_unserved(), 15.0, 0.0001, "unserved drops")
	assert_almost_eq(plugin.buckets["housing_demand"].total_demand, 20.0, 0.0001, "total untouched")
	assert_signal_emitted(GameEvents, "demand_fulfilled_changed")
	plugin.queue_free()

func test_try_spend_blocks_when_unserved_insufficient() -> void:
	var plugin := _minimal_demand_plugin()
	plugin.buckets["housing_demand"].total_demand = 3.0
	var house := _make_structure_with_profile("residential", 5)

	watch_signals(GameEvents)
	var info: Dictionary = plugin.try_spend(house)

	assert_false(info["ok"], "block when unserved < cost")
	assert_almost_eq(info["have"], 3.0, 0.0001)
	assert_almost_eq(plugin.buckets["housing_demand"].fulfilled, 0.0, 0.0001, "fulfilled untouched")
	assert_signal_not_emitted(GameEvents, "demand_fulfilled_changed", "no emit when blocked")
	plugin.queue_free()

func test_try_spend_free_for_non_growth() -> void:
	var plugin := _minimal_demand_plugin()
	for id in ["housing_demand", "industrial_demand", "commercial_demand"]:
		plugin.buckets[id].total_demand = 50.0

	var road := Structure.new()
	var info: Dictionary = plugin.try_spend(road)
	assert_true(info["ok"])
	assert_eq(info["bucket_id"], "")

	var unknown := _make_structure_with_profile("infrastructure", 10)
	assert_true(plugin.try_spend(unknown)["ok"], "unknown categories default to free")

	for id in ["housing_demand", "industrial_demand", "commercial_demand"]:
		assert_almost_eq(plugin.buckets[id].fulfilled, 0.0, 0.0001,
				"%s fulfilled untouched by free placements" % id)
	plugin.queue_free()

func test_try_spend_routes_by_category() -> void:
	var plugin := _minimal_demand_plugin()
	for id in ["housing_demand", "industrial_demand", "commercial_demand"]:
		plugin.buckets[id].total_demand = 100.0

	assert_true(plugin.try_spend(_make_structure_with_profile("residential", 5))["ok"])
	assert_true(plugin.try_spend(_make_structure_with_profile("workplace", 20))["ok"])
	assert_true(plugin.try_spend(_make_structure_with_profile("commercial", 30))["ok"])

	assert_almost_eq(plugin.buckets["housing_demand"].fulfilled,    5.0,  0.0001)
	assert_almost_eq(plugin.buckets["industrial_demand"].fulfilled, 20.0, 0.0001)
	assert_almost_eq(plugin.buckets["commercial_demand"].fulfilled, 30.0, 0.0001)
	plugin.queue_free()

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

	plugin.buckets["housing_demand"].total_demand = 20.0
	var house := _make_generic_residence("residential_t1", 99)

	var info: Dictionary = plugin.try_spend(house)
	assert_true(info["ok"], "pool cost 5 fits in unserved 20")
	assert_almost_eq(info["cost"], 5.0, 0.0001, "cost from pool, not profile")
	assert_almost_eq(plugin.buckets["housing_demand"].fulfilled, 5.0, 0.0001)
	catalog.free()
	plugin.queue_free()

func test_threshold_gates_tier() -> void:
	var plugin := _minimal_demand_plugin()
	var catalog := StubCatalog.new()
	catalog.configs["residential_t2"] = {"demand_per_unit": 15, "demand_threshold": 30}
	plugin._catalog = catalog

	plugin.buckets["housing_demand"].total_demand = 20.0
	var tower := _make_generic_residence("residential_t2", 12)

	assert_false(plugin.can_afford(tower), "tier locked until unserved threshold clears")
	var blocked: Dictionary = plugin.try_spend(tower)
	assert_eq(blocked.get("reason", ""), "below_threshold")

	plugin.buckets["housing_demand"].total_demand = 35.0
	assert_true(plugin.can_afford(tower), "threshold met")
	var ok: Dictionary = plugin.try_spend(tower)
	assert_true(ok["ok"])
	assert_almost_eq(plugin.buckets["housing_demand"].fulfilled, 15.0, 0.0001)

	catalog.free()
	plugin.queue_free()

func test_can_afford_preview_is_nonmutating() -> void:
	var plugin := _minimal_demand_plugin()
	plugin.buckets["housing_demand"].total_demand = 10.0
	var house := _make_structure_with_profile("residential", 5)

	watch_signals(GameEvents)
	assert_true(plugin.can_afford(house))
	assert_almost_eq(plugin.buckets["housing_demand"].fulfilled, 0.0, 0.0001, "preview must not mutate")
	assert_signal_not_emitted(GameEvents, "demand_fulfilled_changed", "preview must not emit")
	plugin.queue_free()
