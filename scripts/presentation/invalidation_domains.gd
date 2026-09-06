extends RefCounted
class_name InvalidationDomains

const ALL := [&"clock", &"structures", &"topology", &"occupancy", &"resources", &"economy",
	&"demand", &"community", &"traffic", &"progression", &"presentation_config"]
const SOURCE_DOMAINS := {
	&"hourly_transaction": [&"clock", &"resources", &"economy", &"demand", &"community", &"traffic"],
	&"building_mutation": [&"structures", &"topology", &"occupancy", &"resources", &"economy", &"demand", &"community", &"traffic", &"progression"],
	&"map_load": ALL,
	&"map_clear": ALL,
}

static func is_valid(domain: StringName) -> bool: return domain in ALL

static func canonicalize(domains: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for domain in ALL:
		if domain in domains:
			result.append(domain)
	return result

static func for_source(source_kind: StringName) -> Array[StringName]:
	return canonicalize(SOURCE_DOMAINS.get(source_kind, []))
