extends RefCounted
class_name DemandBucket

## Base class for the demand buckets — desirability, housing, industrial,
## commercial — that the DemandPlugin ticks once per in-game hour.
##
## Three values per bucket:
##   total_demand — the town's accumulated need; monotonic by default. Each tick,
##                  _compute() returns the new candidate; total clamps to max(old,new).
##   fulfilled    — sum of placed-building capacity in this bucket. Decrements on
##                  demolish. Updated by DemandPlugin via add_fulfilled / remove_fulfilled.
##   unserved     — derived: max(0, total_demand - fulfilled). What the player can spend.
##
## Signals (for the HUD, the spend gate, and event triggers):
##   demand_total_changed     — fires when total_demand grows
##   demand_fulfilled_changed — fires on placement / demolition / map_loaded
##   demand_unserved_changed  — fires whenever total OR fulfilled moves
##
## Subclasses override _compute() with the bucket-specific formula.

var type_id: String = ""
var total_demand: float = 0.0
var fulfilled: float = 0.0

## When false, the bucket overwrites total_demand each tick instead of clamping
## monotonic. Used by Desirability — a 0..1 rate, not an accumulating need.
var monotonic: bool = true

## Scale factor applied when publishing this bucket's UNSERVED value through a
## CityStatSource (which returns int). 100 for 0..1 floats, 1 for unit counts.
var source_scale: float = 1.0

## Reference "one-unit" cost for the bank-count render.
## `floor(unserved / reference_cost)` = how many default-cost buildings the bucket
## can afford. 0 means "not spendable" (e.g. desirability — a rate, not a currency).
var reference_cost: int = 0

func _init(p_type_id: String, p_source_scale: float = 1.0) -> void:
	type_id = p_type_id
	source_scale = p_source_scale

# ── Derived value ─────────────────────────────────────────────────────────────

func get_unserved() -> float:
	return max(0.0, total_demand - fulfilled)

func get_bank_count() -> int:
	if reference_cost <= 0:
		return 0
	return int(floor(get_unserved() / float(reference_cost)))

# ── Tick ──────────────────────────────────────────────────────────────────────

## Called once per in-game hour. Context carries upstream inputs
## (population, satisfaction score, other bucket values, amenity counts…).
func tick(_hour: float, context: Dictionary) -> void:
	var new_total := _compute(context)
	var prev_total := total_demand
	if monotonic:
		total_demand = max(total_demand, new_total)
	else:
		total_demand = new_total
	if total_demand != prev_total:
		GameEvents.demand_total_changed.emit(type_id, total_demand)
	# Always emit unserved on tick — downstream (HUD, condition ctx) treats this
	# as the "heartbeat" event for the bucket.
	GameEvents.demand_unserved_changed.emit(type_id, get_unserved())

## Override in each subclass.
func _compute(_context: Dictionary) -> float:
	push_error("[DemandBucket] _compute() not overridden for type_id=%s" % type_id)
	return 0.0

# ── Fulfilled accounting (driven by DemandPlugin on placement / demolition) ──

func add_fulfilled(amount: float) -> void:
	if amount <= 0.0:
		return
	fulfilled += amount
	GameEvents.demand_fulfilled_changed.emit(type_id, fulfilled)
	GameEvents.demand_unserved_changed.emit(type_id, get_unserved())

func remove_fulfilled(amount: float) -> void:
	if amount <= 0.0:
		return
	fulfilled = max(0.0, fulfilled - amount)
	GameEvents.demand_fulfilled_changed.emit(type_id, fulfilled)
	GameEvents.demand_unserved_changed.emit(type_id, get_unserved())

func set_fulfilled(amount: float) -> void:
	fulfilled = max(0.0, amount)
	GameEvents.demand_fulfilled_changed.emit(type_id, fulfilled)
	GameEvents.demand_unserved_changed.emit(type_id, get_unserved())

# ── CityStats integration ─────────────────────────────────────────────────────

## Wrap this bucket in a CityStatSource that publishes UNSERVED — the
## spendable amount is the relevant downstream signal.
func make_source() -> CityStatSource:
	return _BucketSource.new(self)

class _BucketSource extends CityStatSource:
	var _bucket: DemandBucket

	func _init(bucket: DemandBucket) -> void:
		_bucket = bucket

	func get_type_id() -> String:
		return _bucket.type_id

	func tick(_hour: float) -> int:
		return int(_bucket.get_unserved() * _bucket.source_scale)
