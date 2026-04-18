extends RefCounted
class_name DemandBucket

## Base class for the four demand buckets — desirability, housing, industrial,
## commercial — that the DemandPlugin ticks once per in-game hour.
##
## Subclasses override _compute() with the bucket-specific formula.
## The base class handles the floor clamp, value caching, and the
## GameEvents.demand_changed emission so every bucket behaves identically
## from the plugin's perspective.

var type_id: String = ""
var value: float = 0.0
var floor_value: float = 0.0     # housing uses this so towns don't shrink

## Scale factor applied when publishing this bucket's value through a
## CityStatSource (which returns int). 100 for 0..1 floats, 1 for unit counts.
var source_scale: float = 1.0

## Reference "one-unit" cost for the bank-count render.
## `floor(value / reference_cost)` = how many default-cost buildings the bucket
## can afford. 0 means "not spendable" (e.g. desirability — a rate, not a currency).
## Set by DemandPlugin from @export tunables so M2's tier costs can override later.
var reference_cost: int = 0

func _init(p_type_id: String, p_source_scale: float = 1.0) -> void:
	type_id = p_type_id
	source_scale = p_source_scale

## How many reference-cost units this bucket can currently fund.
## Returns 0 if the bucket is non-spendable (reference_cost <= 0).
func get_bank_count() -> int:
	if reference_cost <= 0:
		return 0
	return int(floor(value / float(reference_cost)))

## Called once per in-game hour. Context carries upstream inputs
## (population, satisfaction score, other bucket values, amenity counts…).
func tick(_hour: float, context: Dictionary) -> void:
	var new_value := _compute(context)
	value = max(new_value, floor_value)
	GameEvents.demand_changed.emit(type_id, value)

## Override in each subclass.
func _compute(_context: Dictionary) -> float:
	push_error("[DemandBucket] _compute() not overridden for type_id=%s" % type_id)
	return 0.0

## Wrap this bucket in a CityStatSource so downstream plugins can read the value
## via the existing CityStats machinery (no peeking at plugin internals).
func make_source() -> CityStatSource:
	return _BucketSource.new(self)

class _BucketSource extends CityStatSource:
	var _bucket: DemandBucket

	func _init(bucket: DemandBucket) -> void:
		_bucket = bucket

	func get_type_id() -> String:
		return _bucket.type_id

	func tick(_hour: float) -> int:
		return int(_bucket.value * _bucket.source_scale)
