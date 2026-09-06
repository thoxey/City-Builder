extends PluginBase

const SimulationIntentType := preload("res://scripts/simulation/simulation_intent.gd")

## Composite satisfaction score — the primary balance lever.
##
## Each in-game hour, reads the per-resource satisfaction scores from CityStats
## and blends them into a single 0–1 score using the weights below.
## That score is emitted on GameEvents.satisfaction_changed and is read by
## the Residential plugin to scale the available population pool.
##
## Tune the weights here to set the relative importance of each factor.
## Resources with no demand default to 1.0 (fully satisfied).

func get_plugin_name() -> String: return "Satisfaction"
func get_dependencies() -> Array[String]: return ["CityStats", "SimulationTransaction"]

var _city_stats: PluginBase
var _performance_debug_logs := OS.get_environment("CITY_BUILDER_PERFORMANCE_DEBUG_LOGS") == "1"
var _simulation_transaction: PluginBase
var _pending_publication := false

func inject(deps: Dictionary) -> void:
	_city_stats = deps.get("CityStats")
	_simulation_transaction = deps.get("SimulationTransaction")

# ── Weights — adjust these as balance levers ──────────────────────────────────

var weight_budget: float = 1.0

# ── State ─────────────────────────────────────────────────────────────────────

var _score: float = 1.0

func get_score() -> float:
	var community := PluginManager.get_plugin("Community")
	if community and community.has_method("get_population") and community.get_population() > 0:
		return clampf(float(community.get_average_composite()) / 100.0, 0.0, 1.0)
	return _score

func reset_runtime_state() -> void:
	_score = 1.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	if _simulation_transaction:
		_simulation_transaction.register_reducer(&"progression", [&"satisfaction_tick"], _reduce_hour, _commit_hour, 1)
		_simulation_transaction.register_contributor(&"satisfaction", [&"progression"], _collect_hour)
		_simulation_transaction.transaction_committed.connect(_publish_committed_hour)
	else:
		_city_stats.stats_ticked.connect(_on_stats_ticked)

func _collect_hour(context: Variant, sink: Variant) -> void:
	sink.submit(SimulationIntentType.create("satisfaction:%d" % context.absolute_hour, &"satisfaction",
		"city", &"progression", &"satisfaction_tick", {"hour":context.clock_hour}, 0, &"set", 1))

func _reduce_hour(intents: Array, _context: Variant) -> Dictionary:
	return {"ok":intents.size() == 1, "reason_code":"invalid_payload", "plan":{}, "domains":[&"progression"]}

func _commit_hour(_plan: Dictionary, _context: Variant) -> Dictionary:
	_on_stats_ticked({}, {}, _city_stats.get_satisfaction_snapshot(), false)
	return {"ok":true}

func _publish_committed_hour(_change_set: Variant, _ledger: Dictionary) -> void:
	if not _pending_publication: return
	_pending_publication = false
	GameEvents.satisfaction_changed.emit(_score)

# ── Tick ──────────────────────────────────────────────────────────────────────

func _on_stats_ticked(_supply: Dictionary, _demand: Dictionary, satisfaction: Dictionary, publish: bool = true) -> void:
	var weights: Dictionary = {
		"budget": weight_budget,
	}

	var weighted_sum  := 0.0
	var total_weight  := 0.0
	for key in weights:
		var w: float = weights[key]
		var s: float = satisfaction.get(key, 1.0)
		weighted_sum += s * w
		total_weight += w

	_score = weighted_sum / total_weight if total_weight > 0.0 else 1.0
	if publish: GameEvents.satisfaction_changed.emit(_score)
	else: _pending_publication = true

	if _performance_debug_logs:
		print("[Satisfaction] score=%.2f  (budget=%.2f)" % [
			_score,
			satisfaction.get("budget", 1.0),
		])
