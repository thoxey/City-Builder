extends GutTest

## Unit tests for the demand system (post-attractiveness refactor).
##
## Each bucket carries three numbers:
##   total_demand — monotonic accumulator
##   fulfilled    — sum of placed-building capacity in the bucket
##   unserved     — derived: max(0, total - fulfilled). What the player can spend.
##
## Housing growth is now driven by city attractiveness via context["attractiveness"].

const HousingDemandBucketCls    := preload("res://scripts/demand/housing_demand_bucket.gd")
const IndustrialDemandBucketCls := preload("res://scripts/demand/industrial_demand_bucket.gd")
const CommercialDemandBucketCls := preload("res://scripts/demand/commercial_demand_bucket.gd")
const CityStatsPluginCls        := preload("res://plugins/city_stats/city_stats_plugin.gd")
const DemandPluginCls           := preload("res://plugins/demand/demand_plugin.gd")

# ── Base class signal emission ────────────────────────────────────────────────

func test_bucket_base_emits_unserved_on_tick() -> void:
	var bucket := HousingDemandBucketCls.new()
	bucket.total_demand = 50.0
	watch_signals(GameEvents)
	bucket.tick(0.0, {"attractiveness": 100})
	assert_signal_emitted(GameEvents, "demand_unserved_changed", "unserved signal fires every tick")
	var params: Array = get_signal_parameters(GameEvents, "demand_unserved_changed", 0)
	assert_eq(params[0], "residential", "bucket_type_id should be the bucket's type_id")
	assert_almost_eq(params[1], bucket.get_unserved(), 0.0001, "emitted value matches unserved")

func test_bucket_emits_total_changed_when_total_grows() -> void:
	var bucket := HousingDemandBucketCls.new()
	bucket.growth_rate = 5.0
	bucket.total_demand = 0.0
	watch_signals(GameEvents)
	bucket.tick(0.0, {"attractiveness": 1000})
	assert_signal_emitted(GameEvents, "demand_total_changed", "total grows on first tick")

# ── Housing — saturation-clamped, monotonic ──────────────────────────────────

func test_housing_grows_with_attractiveness() -> void:
	var bucket := HousingDemandBucketCls.new()
	bucket.growth_rate = 1.0
	bucket.saturation = 100.0  # easy threshold for the test
	bucket.max_cap = 100.0

	# Below saturation: growth scales linearly.
	for i in 3:
		bucket.tick(0.0, {"attractiveness": 50})  # factor=0.5
	# 3 ticks × 0.5 growth_rate × 0.5 factor = 0.75 expected, but capped at factor*max_cap=50.
	assert_gt(bucket.total_demand, 0.0, "housing should grow with positive attractiveness")
	assert_lte(bucket.total_demand, 50.0, "growth capped at factor × max_cap")

func test_housing_total_monotonic_when_attractiveness_drops() -> void:
	var bucket := HousingDemandBucketCls.new()
	bucket.growth_rate = 5.0
	bucket.saturation = 100.0

	for i in 5:
		bucket.tick(0.0, {"attractiveness": 100})  # factor=1
	var peak: float = bucket.total_demand
	assert_gt(peak, 0.0, "housing total should have risen")

	for i in 3:
		bucket.tick(0.0, {"attractiveness": 0})
		assert_gte(bucket.total_demand, peak, "monotonic clamp must hold total")

func test_housing_caps_at_factor_times_max() -> void:
	var bucket := HousingDemandBucketCls.new()
	bucket.growth_rate = 1000.0
	bucket.max_cap     = 100.0
	bucket.saturation  = 100.0

	# attractiveness=50 → factor=0.5 → cap=50.
	bucket.tick(0.0, {"attractiveness": 50})
	assert_almost_eq(bucket.total_demand, 50.0, 0.0001, "cap = factor × max_cap")

	# attractiveness rises to saturation → factor=1 → cap=100.
	bucket.tick(0.0, {"attractiveness": 100})
	assert_almost_eq(bucket.total_demand, 100.0, 0.0001, "saturation pegs cap at max_cap")

	# attractiveness collapses → cap=0 but monotonic protects total.
	bucket.tick(0.0, {"attractiveness": 0})
	assert_eq(bucket.total_demand, 100.0, "monotonic protects total when cap drops")

func test_housing_zero_attractiveness_zero_growth() -> void:
	var bucket := HousingDemandBucketCls.new()
	bucket.growth_rate = 1.0
	bucket.total_demand = 0.0
	bucket.tick(0.0, {"attractiveness": 0})
	assert_eq(bucket.total_demand, 0.0, "no attractiveness, no growth")

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
	assert_eq(supply["industrial"], 20, "supply = unserved × source_scale")

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
	plugin.buckets["residential"].total_demand = 20.0
	var house := _make_structure_with_profile("residential", 5)

	watch_signals(GameEvents)
	var info: Dictionary = plugin.try_spend(house)

	assert_true(info["ok"], "succeeds when unserved >= cost")
	assert_eq(info["bucket_id"], "residential")
	assert_almost_eq(info["cost"], 5.0, 0.0001)
	assert_almost_eq(info["have"], 20.0, 0.0001, "have reports pre-spend UNSERVED")
	assert_almost_eq(plugin.buckets["residential"].fulfilled, 5.0, 0.0001, "fulfilled bumped")
	assert_almost_eq(plugin.buckets["residential"].get_unserved(), 15.0, 0.0001, "unserved drops")
	assert_almost_eq(plugin.buckets["residential"].total_demand, 20.0, 0.0001, "total untouched")
	assert_signal_emitted(GameEvents, "demand_fulfilled_changed")
	plugin.queue_free()

func test_try_spend_blocks_when_unserved_insufficient() -> void:
	var plugin := _minimal_demand_plugin()
	plugin.buckets["residential"].total_demand = 3.0
	var house := _make_structure_with_profile("residential", 5)

	watch_signals(GameEvents)
	var info: Dictionary = plugin.try_spend(house)

	assert_false(info["ok"], "block when unserved < cost")
	assert_almost_eq(info["have"], 3.0, 0.0001)
	assert_almost_eq(plugin.buckets["residential"].fulfilled, 0.0, 0.0001, "fulfilled untouched")
	assert_signal_not_emitted(GameEvents, "demand_fulfilled_changed", "no emit when blocked")
	plugin.queue_free()

func test_try_spend_free_for_non_growth() -> void:
	var plugin := _minimal_demand_plugin()
	for id in ["residential", "industrial", "commercial"]:
		plugin.buckets[id].total_demand = 50.0

	var road := Structure.new()
	var info: Dictionary = plugin.try_spend(road)
	assert_true(info["ok"])
	assert_eq(info["bucket_id"], "")

	var unknown := _make_structure_with_profile("infrastructure", 10)
	assert_true(plugin.try_spend(unknown)["ok"], "unknown categories default to free")

	for id in ["residential", "industrial", "commercial"]:
		assert_almost_eq(plugin.buckets[id].fulfilled, 0.0, 0.0001,
				"%s fulfilled untouched by free placements" % id)
	plugin.queue_free()

func test_try_spend_routes_by_category() -> void:
	var plugin := _minimal_demand_plugin()
	for id in ["residential", "industrial", "commercial"]:
		plugin.buckets[id].total_demand = 100.0

	assert_true(plugin.try_spend(_make_structure_with_profile("residential", 5))["ok"])
	assert_true(plugin.try_spend(_make_structure_with_profile("industrial", 20))["ok"])
	assert_true(plugin.try_spend(_make_structure_with_profile("commercial", 30))["ok"])

	assert_almost_eq(plugin.buckets["residential"].fulfilled, 5.0, 0.0001)
	assert_almost_eq(plugin.buckets["industrial"].fulfilled, 20.0, 0.0001)
	assert_almost_eq(plugin.buckets["commercial"].fulfilled, 30.0, 0.0001)
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

	plugin.buckets["residential"].total_demand = 20.0
	var house := _make_generic_residence("residential_t1", 99)

	var info: Dictionary = plugin.try_spend(house)
	assert_true(info["ok"], "pool cost 5 fits in unserved 20")
	assert_almost_eq(info["cost"], 5.0, 0.0001, "cost from pool, not profile")
	assert_almost_eq(plugin.buckets["residential"].fulfilled, 5.0, 0.0001)
	catalog.free()
	plugin.queue_free()

func test_threshold_gates_tier() -> void:
	var plugin := _minimal_demand_plugin()
	var catalog := StubCatalog.new()
	catalog.configs["residential_t2"] = {"demand_per_unit": 15, "demand_threshold": 30}
	plugin._catalog = catalog

	plugin.buckets["residential"].total_demand = 20.0
	var tower := _make_generic_residence("residential_t2", 12)

	assert_false(plugin.can_afford(tower), "tier locked until unserved threshold clears")
	var blocked: Dictionary = plugin.try_spend(tower)
	assert_eq(blocked.get("reason", ""), "below_threshold")

	plugin.buckets["residential"].total_demand = 35.0
	assert_true(plugin.can_afford(tower), "threshold met")
	var ok: Dictionary = plugin.try_spend(tower)
	assert_true(ok["ok"])
	assert_almost_eq(plugin.buckets["residential"].fulfilled, 15.0, 0.0001)

	catalog.free()
	plugin.queue_free()

func test_can_afford_preview_is_nonmutating() -> void:
	var plugin := _minimal_demand_plugin()
	plugin.buckets["residential"].total_demand = 10.0
	var house := _make_structure_with_profile("residential", 5)

	watch_signals(GameEvents)
	assert_true(plugin.can_afford(house))
	assert_almost_eq(plugin.buckets["residential"].fulfilled, 0.0, 0.0001, "preview must not mutate")
	assert_signal_not_emitted(GameEvents, "demand_fulfilled_changed", "preview must not emit")
	plugin.queue_free()
