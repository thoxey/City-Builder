extends PluginBase
class_name ProjectionRegistryPlugin

const Domains := preload("res://scripts/presentation/invalidation_domains.gd")

var _operational := {}
var _diagnostic := {}
var _cache := {}
var _domain_revisions := {}
var _performance_monitor: PluginBase

func get_plugin_name() -> String: return "ProjectionRegistry"
func get_dependencies() -> Array[String]: return ["PerformanceMonitor"]

func inject(deps: Dictionary) -> void:
	_performance_monitor = deps.get("PerformanceMonitor")

func register_projection(id: StringName, domains: Array, projector: Callable) -> Dictionary:
	return _register(_operational, id, domains, projector)

func register_diagnostic_projection(id: StringName, domains: Array, projector: Callable) -> Dictionary:
	return _register(_diagnostic, id, domains, projector)

func _register(registry: Dictionary, id: StringName, domains: Array, projector: Callable) -> Dictionary:
	if _operational.has(id) or _diagnostic.has(id): return {"ok":false, "reason_code":"duplicate_projection"}
	var canonical := Domains.canonicalize(domains)
	if String(id).is_empty() or canonical.is_empty() or canonical.size() != domains.size() or not projector.is_valid():
		return {"ok":false, "reason_code":"invalid_projection"}
	registry[id] = {"domains":canonical, "projector":projector}
	return {"ok":true}

func set_domain_revision(domain: StringName, revision: int) -> bool:
	if not Domains.is_valid(domain): return false
	_domain_revisions[domain] = revision
	return true

func apply_change_set(change_set: Variant) -> void:
	var revisions: Dictionary = change_set.get_dependency_revisions()
	for domain in change_set.get_domains():
		_domain_revisions[domain] = int(revisions.get(String(domain), change_set.post_state_version))

func get_projection(id: StringName, state_version: int = -1) -> Variant:
	return _fetch_projection(_operational, id, state_version)

func get_diagnostic_projection(id: StringName, state_version: int = -1) -> Variant:
	return _fetch_projection(_diagnostic, id, state_version)

func _fetch_projection(registry: Dictionary, id: StringName, state_version: int) -> Variant:
	if not registry.has(id): return null
	var registration: Dictionary = registry[id]
	var revisions := {}
	for domain in registration.domains: revisions[String(domain)] = int(_domain_revisions.get(domain, 0))
	var version := GameState.get_state_version() if state_version < 0 else state_version
	var cache_key := "%s|%s|%s" % [String(id), version, JSON.stringify(revisions)]
	if not _cache.has(cache_key):
		var started := Time.get_ticks_usec()
		var payload: Variant = registration.projector.call(version, revisions.duplicate(true))
		_cache[cache_key] = _detach(payload)
		if _performance_monitor:
			_performance_monitor.record(&"projection.diagnostic" if registry == _diagnostic else &"projection.operational",
				Time.get_ticks_usec() - started, {"projection_id":String(id), "cache_miss":1})
	return _detach(_cache[cache_key])

func clear_runtime() -> void: _cache.clear(); _domain_revisions.clear()

static func _detach(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value
