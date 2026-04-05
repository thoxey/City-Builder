extends PluginBase

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
func get_dependencies() -> Array[String]: return ["CityStats"]

var _city_stats: PluginBase

func inject(deps: Dictionary) -> void:
	_city_stats = deps.get("CityStats")

# ── Weights — adjust these as balance levers ──────────────────────────────────

var weight_safety: float = 1.0
var weight_health: float = 1.0
var weight_budget: float = 1.0

# ── State ─────────────────────────────────────────────────────────────────────

var _score: float = 1.0

func get_score() -> float:
	return _score

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	_city_stats.stats_ticked.connect(_on_stats_ticked)

# ── Tick ──────────────────────────────────────────────────────────────────────

func _on_stats_ticked(_supply: Dictionary, _demand: Dictionary, satisfaction: Dictionary) -> void:
	var weights: Dictionary = {
		"safety": weight_safety,
		"health": weight_health,
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
	GameEvents.satisfaction_changed.emit(_score)

	if OS.is_debug_build():
		print("[Satisfaction] score=%.2f  (safety=%.2f health=%.2f budget=%.2f)" % [
			_score,
			satisfaction.get("safety", 1.0),
			satisfaction.get("health", 1.0),
			satisfaction.get("budget", 1.0),
		])
