extends RefCounted
class_name AuthoritativeChangeSet

const Domains := preload("res://scripts/presentation/invalidation_domains.gd")

const SOURCE_KINDS := [&"hourly_transaction", &"building_mutation", &"map_load", &"map_clear"]

var change_id: String
var source_kind: StringName
var source_id: String
var pre_state_version: int
var post_state_version: int
var _domains: Array[StringName]
var _entity_keys: Dictionary
var _deltas: Dictionary
var _dependency_revisions: Dictionary

static func create(p_change_id: String, p_source_kind: StringName, p_source_id: String,
		p_pre: int, p_post: int, p_domains: Array, p_entity_keys: Dictionary = {},
		p_deltas: Dictionary = {}, p_revisions: Dictionary = {}) -> Variant:
	var value = (load("res://scripts/simulation/authoritative_change_set.gd") as GDScript).new()
	value.change_id = p_change_id
	value.source_kind = p_source_kind
	value.source_id = p_source_id
	value.pre_state_version = p_pre
	value.post_state_version = p_post
	value._domains = Domains.canonicalize(p_domains)
	value._entity_keys = {}
	for domain in value._domains:
		var keys: Array = p_entity_keys.get(String(domain), p_entity_keys.get(domain, [])).duplicate()
		keys.sort()
		value._entity_keys[String(domain)] = keys
	value._deltas = p_deltas.duplicate(true)
	value._dependency_revisions = p_revisions.duplicate(true)
	return value

func is_valid() -> bool:
	return not change_id.is_empty() and source_kind in SOURCE_KINDS and pre_state_version >= 0 \
		and post_state_version == pre_state_version + 1

func get_domains() -> Array[StringName]: return _domains.duplicate()
func get_entity_keys() -> Dictionary: return _entity_keys.duplicate(true)
func get_deltas() -> Dictionary: return _deltas.duplicate(true)
func get_dependency_revisions() -> Dictionary: return _dependency_revisions.duplicate(true)

func to_dict() -> Dictionary:
	return {"change_id":change_id,"source_kind":String(source_kind),"source_id":source_id,
		"pre_state_version":pre_state_version,"post_state_version":post_state_version,
		"domains":get_domains(),"entity_keys":get_entity_keys(),"deltas":get_deltas(),
		"dependency_revisions":get_dependency_revisions()}
