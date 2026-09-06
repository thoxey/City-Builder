extends RefCounted
class_name HourContext

var transaction_id: String
var absolute_hour: int
var day: int
var clock_hour: int
var pre_state_version: int
var _seed_context: Dictionary
var _projections: Dictionary
var _dependency_revisions: Dictionary

static func create(p_transaction_id: String, p_absolute_hour: int, p_day: int,
		p_clock_hour: int, p_seed_context: Dictionary, p_pre_state_version: int,
		p_projections: Dictionary, p_dependency_revisions: Dictionary) -> Variant:
	var value = (load("res://scripts/simulation/hour_context.gd") as GDScript).new()
	value.transaction_id = p_transaction_id
	value.absolute_hour = p_absolute_hour
	value.day = p_day
	value.clock_hour = p_clock_hour
	value.pre_state_version = p_pre_state_version
	value._seed_context = p_seed_context.duplicate(true)
	value._projections = p_projections.duplicate(true)
	value._dependency_revisions = p_dependency_revisions.duplicate(true)
	return value

func get_seed_context() -> Dictionary:
	return _seed_context.duplicate(true)

func get_projection(projection_id: StringName) -> Variant:
	var value: Variant = _projections.get(String(projection_id))
	return value.duplicate(true) if value is Dictionary or value is Array else value

func get_projections() -> Dictionary:
	return _projections.duplicate(true)

func get_dependency_revisions() -> Dictionary:
	return _dependency_revisions.duplicate(true)

func to_dict() -> Dictionary:
	return {"transaction_id":transaction_id,"absolute_hour":absolute_hour,"day":day,
		"clock_hour":clock_hour,"seed_context":get_seed_context(),
		"pre_state_version":pre_state_version,"projections":get_projections(),
		"dependency_revisions":get_dependency_revisions()}
