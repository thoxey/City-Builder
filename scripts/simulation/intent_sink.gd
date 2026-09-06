extends RefCounted
class_name SimulationIntentSink

var contributor_id: StringName
var declared_domains: Array[StringName]
var _intents: Array = []
var _failure: Dictionary = {}

static func create(id: StringName, domains: Array[StringName]) -> Variant:
	var sink = (load("res://scripts/simulation/intent_sink.gd") as GDScript).new()
	sink.contributor_id = id
	sink.declared_domains = domains.duplicate()
	return sink

func submit(intent: Variant) -> bool:
	if intent == null or not intent.has_method("is_valid") or not intent.is_valid():
		_failure = {"reason_code": "invalid_payload"}
		return false
	if intent.contributor_id != contributor_id or intent.target_domain not in declared_domains:
		_failure = {"reason_code": "unknown_domain"}
		return false
	_intents.append(intent)
	return true

func intents() -> Array: return _intents.duplicate()
func failure() -> Dictionary: return _failure.duplicate(true)
