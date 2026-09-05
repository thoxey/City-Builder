extends PluginBase

## Economy — running cash surplus.
##
## Each in-game hour:
##   tax_income      = industrial_output × tax_rate
##   cash           += tax_income   (clamped at 0)
##
## Decoratives (nature category) consume cash on placement via `try_spend_cash`.
## Growth buildings (residential / workplace / commercial) stay demand-bank gated;
## this plugin doesn't touch them. Reads industrial_output from the CityStats
## supply snapshot — the same signal Workplace publishes for the demand chain.

func get_plugin_name() -> String: return "Economy"
func get_dependencies() -> Array[String]: return ["DayNight", "CityStats", "BuildingCatalog", "Commercial"]

var _day_night:  PluginBase
var _city_stats: PluginBase
var _catalog:    PluginBase
var _commercial: PluginBase

func inject(deps: Dictionary) -> void:
	_day_night  = deps.get("DayNight")
	_city_stats = deps.get("CityStats")
	_catalog    = deps.get("BuildingCatalog")
	_commercial = deps.get("Commercial")

# ── Tuning levers ─────────────────────────────────────────────────────────────

@export_group("Tax")
## Cash earned per unit of industrial output per in-game hour.
@export var tax_rate: int = 5

# ── State ─────────────────────────────────────────────────────────────────────

var _last_supply: Dictionary = {}  # snapshot from CityStats.stats_ticked
var _last_hourly_income: int = 0
var _cumulative_income: int = 0
var _last_shop_proximity_income: int = 0
var _cumulative_shop_proximity_income: int = 0
var _spend_by_category: Dictionary = {}

func get_last_hourly_income() -> int:
	return _last_hourly_income

func get_runtime_ledger() -> Dictionary:
	var spend := _spend_by_category.duplicate(true)
	var total_spend := 0
	for amount in spend.values():
		total_spend += int(amount)
	return {
		"cumulative_income": _cumulative_income,
		"last_shop_proximity_income": _last_shop_proximity_income,
		"cumulative_shop_proximity_income": _cumulative_shop_proximity_income,
		"cumulative_spend": total_spend,
		"spend_by_category": spend,
	}

func reset_runtime_state() -> void:
	_last_supply.clear()
	_last_hourly_income = 0
	_cumulative_income = 0
	_last_shop_proximity_income = 0
	_cumulative_shop_proximity_income = 0
	_spend_by_category.clear()

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
	var shop_bonus_income := int(_commercial.get_town_hall_bonus_income()) if _commercial and _commercial.has_method("get_town_hall_bonus_income") else 0
	var income: int = output * tax_rate + shop_bonus_income
	_last_shop_proximity_income = shop_bonus_income
	_cumulative_shop_proximity_income += shop_bonus_income
	_last_hourly_income = income
	_cumulative_income += income

	_apply_delta(income)

	print("[Economy] tick: income=%d cash=%d" % [
		income, GameState.map.cash
	])

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

## Non-mutating preview — would `try_spend_cash(structure)` succeed right now?
## Cash-free structures (cost==0) always pass.
func can_afford_cash(structure: Structure) -> bool:
	return bool(quote_cash(structure)["ok"])

## Complete non-mutating cash decision used by Builder's atomic validation.
func quote_cash(structure: Structure) -> Dictionary:
	var cost: int = get_cash_cost(structure)
	var have: int = GameState.map.cash
	return {
		"ok": cost <= 0 or have >= cost,
		"cost": cost,
		"have": have,
		"reason": "insufficient_cash" if cost > 0 and have < cost else "",
	}

## Attempts to spend the cash required to place `structure`.
## Returns a Dictionary describing the outcome:
##   ok:    bool — whether placement may proceed
##   cost:  int  — required cash for this placement
##   have:  int  — cash balance pre-spend
## Cash-free structures (cash_cost == 0) yield ok=true with zero cost.
func try_spend_cash(structure: Structure) -> Dictionary:
	var result := quote_cash(structure)
	var cost: int = result["cost"]
	var have: int = result["have"]
	if cost <= 0:
		return result
	if not result["ok"]:
		print("[Economy] place_blocked: cost=%d cash=%d" % [cost, have])
		return result
	_apply_delta(-cost)
	var category := _cash_category(structure)
	_spend_by_category[category] = int(_spend_by_category.get(category, 0)) + cost
	print("[Economy] spent: cost=%d remaining=%d" % [cost, GameState.map.cash])
	return result

func _cash_category(structure: Structure) -> String:
	if _catalog == null:
		return "other"
	var sid := GameState.structures.find(structure)
	var summaries: Array = _catalog.get_summary()
	if sid < 0 or sid >= summaries.size():
		return "other"
	var summary: Dictionary = summaries[sid]
	var category := String(summary.get("category", "other"))
	return category if not category.is_empty() else "other"

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
