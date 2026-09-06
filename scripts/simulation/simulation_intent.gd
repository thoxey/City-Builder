extends RefCounted
class_name SimulationIntent

var intent_id: String
var contributor_id: StringName
var entity_key: String
var target_domain: StringName
var operation: StringName
var priority: int
var combine_mode: StringName
var reducer_phase: int
var _payload: Dictionary

static func create(p_intent_id: String, p_contributor_id: StringName, p_entity_key: String,
		p_target_domain: StringName, p_operation: StringName, p_payload: Dictionary,
		p_priority: int = 0, p_combine_mode: StringName = &"set", p_reducer_phase: int = 0) -> Variant:
	var value = (load("res://scripts/simulation/simulation_intent.gd") as GDScript).new()
	value.intent_id = p_intent_id
	value.contributor_id = p_contributor_id
	value.entity_key = p_entity_key
	value.target_domain = p_target_domain
	value.operation = p_operation
	value._payload = p_payload.duplicate(true)
	value.priority = p_priority
	value.combine_mode = p_combine_mode
	value.reducer_phase = p_reducer_phase
	return value

func is_valid() -> bool:
	return not intent_id.is_empty() and not String(contributor_id).is_empty() \
		and not String(target_domain).is_empty() and not String(operation).is_empty()

func get_payload() -> Dictionary:
	return _payload.duplicate(true)

func canonical_key() -> String:
	return "%010d|%s|%s|%010d|%s|%s|%s" % [reducer_phase, String(target_domain),
		String(_payload.get("target_key", entity_key)), priority, String(contributor_id),
		entity_key, intent_id]

func to_dict() -> Dictionary:
	return {"intent_id":intent_id,"contributor_id":String(contributor_id),"entity_key":entity_key,
		"target_domain":String(target_domain),"operation":String(operation),"payload":get_payload(),
		"priority":priority,"combine_mode":String(combine_mode),"ordering_key":canonical_key()}
