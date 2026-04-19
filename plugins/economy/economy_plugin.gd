extends PluginBase

## Economy — running cash surplus.
##
## Each in-game hour:
##   tax_income      = industrial_output × tax_rate
##   service_overhead = active police + medical stations × per-station rate
##   cash           += tax_income − service_overhead   (clamped at 0)
##
## Decoratives (nature category) consume cash on placement via `try_spend_cash`.
## Growth buildings (residential / workplace / commercial) stay demand-bank gated;
## this plugin doesn't touch them. Reads industrial_output from the CityStats
## supply snapshot — the same signal Workplace publishes for the demand chain.

func get_plugin_name() -> String: return "Economy"
func get_dependencies() -> Array[String]: return ["DayNight", "CityStats", "BuildingCatalog"]

var _day_night:  PluginBase
var _city_stats: PluginBase
var _catalog:    PluginBase

func inject(deps: Dictionary) -> void:
	_day_night  = deps.get("DayNight")
	_city_stats = deps.get("CityStats")
	_catalog    = deps.get("BuildingCatalog")

# ── Tuning levers ─────────────────────────────────────────────────────────────

@export_group("Tax")
## Cash earned per unit of industrial output per in-game hour.
@export var tax_rate: int = 5

@export_group("Service overhead")
## Cash drawn per active police station per hour.
@export var overhead_per_police: int = 20
## Cash drawn per active medical facility per hour.
@export var overhead_per_medical: int = 30

# ── State ─────────────────────────────────────────────────────────────────────

var _last_supply: Dictionary = {}  # snapshot from CityStats.stats_ticked

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	# CityStats fires stats_ticked synchronously inside its own hour_changed
	# handler; capture the supply snapshot so we can read industrial_output.
	_city_stats.stats_ticked.connect(_on_stats_ticked)
	# Run our own tick after CityStats has finished. Plugin topo order puts
	# Economy after CityStats, so this connect happens later in the same signal
	# emission and Godot fires handlers in connect order — but to be explicit
	# about ordering we use a deferred slot tied to hour_changed.
	_day_night.hour_changed.connect(_on_hour)

	# Surface starting cash to listeners (HUD wires up after this fires the
	# first time, so we also push on map_loaded below).
	GameEvents.cash_changed.emit(GameState.map.cash, 0)
	GameEvents.map_loaded.connect(_on_map_loaded)

func _on_stats_ticked(supply: Dictionary, _demand: Dictionary, _sat: Dictionary) -> void:
	_last_supply = supply

func _on_map_loaded(_map) -> void:
	# A new map (load / clear) has its own cash value — re-publish so the HUD
	# resets to whatever was saved (or the fresh 1000 grant).
	GameEvents.cash_changed.emit(GameState.map.cash, 0)

# ── Tick ──────────────────────────────────────────────────────────────────────

func _on_hour(_hour: float) -> void:
	# CityStats already ran (topo order) so _last_supply is fresh for this hour.
	var output: int = int(_last_supply.get("industrial_output", 0))
	var income: int = output * tax_rate
	var overhead: int = _compute_overhead()
	var delta: int = income - overhead

	_apply_delta(delta)

	print("[Economy] tick: income=%d overhead=%d delta=%+d cash=%d" % [
		income, overhead, delta, GameState.map.cash
	])

func _compute_overhead() -> int:
	var police_count := 0
	var medical_count := 0
	for bid in GameState.building_registry:
		var entry: Dictionary = GameState.building_registry[bid]
		var sid: int = entry.get("structure", -1)
		if sid < 0 or sid >= GameState.structures.size():
			continue
		var s: Structure = GameState.structures[sid]
		if s.find_metadata(PoliceMetadata) != null:
			police_count += 1
		elif s.find_metadata(MedicalMetadata) != null:
			medical_count += 1
	return police_count * overhead_per_police + medical_count * overhead_per_medical

# ── Spending ──────────────────────────────────────────────────────────────────

## Lookup the cash_cost for a structure via its building_id (stored in catalog summary).
## Returns 0 for any building without a cash_cost — those bypass the cash gate.
func get_cash_cost(structure: Structure) -> int:
	if _catalog == null:
		return 0
	var sid: int = GameState.structures.find(structure)
	if sid < 0:
		return 0
	var summaries: Array = _catalog.get_summary()
	if sid >= summaries.size():
		return 0
	return int((summaries[sid] as Dictionary).get("cash_cost", 0))

## Attempts to spend the cash required to place `structure`.
## Returns a Dictionary describing the outcome:
##   ok:    bool — whether placement may proceed
##   cost:  int  — required cash for this placement
##   have:  int  — cash balance pre-spend
## Cash-free structures (cash_cost == 0) yield ok=true with zero cost.
func try_spend_cash(structure: Structure) -> Dictionary:
	var cost: int = get_cash_cost(structure)
	var have: int = GameState.map.cash
	var result := {"ok": true, "cost": cost, "have": have}
	if cost <= 0:
		return result
	if have < cost:
		result["ok"] = false
		print("[Economy] place_blocked: cost=%d cash=%d" % [cost, have])
		return result
	_apply_delta(-cost)
	print("[Economy] spent: cost=%d remaining=%d" % [cost, GameState.map.cash])
	return result

# ── Cash mutator (single chokepoint, signal + clamp) ──────────────────────────

func _apply_delta(delta: int) -> void:
	if delta == 0:
		return
	var prev: int = GameState.map.cash
	var next: int = max(0, prev + delta)
	if next == prev:
		return
	GameState.map.cash = next
	GameEvents.cash_changed.emit(next, next - prev)
