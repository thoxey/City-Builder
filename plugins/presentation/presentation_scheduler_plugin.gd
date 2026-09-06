extends PluginBase
class_name PresentationSchedulerPlugin

const Registration := preload("res://scripts/presentation/presenter_registration.gd")
const Domains := preload("res://scripts/presentation/invalidation_domains.gd")

var _presenters := {}
var _flush_scheduled := false
var _flushing := false
var _invalidated_during_flush := {}
var _latest_version := 0
var _projection_registry: PluginBase
var _transaction: PluginBase
var _performance_monitor: PluginBase

func get_plugin_name() -> String: return "PresentationScheduler"
func get_dependencies() -> Array[String]: return ["SimulationTransaction", "ProjectionRegistry", "PerformanceMonitor"]

func inject(deps: Dictionary) -> void:
	_transaction = deps.get("SimulationTransaction")
	_projection_registry = deps.get("ProjectionRegistry")
	_performance_monitor = deps.get("PerformanceMonitor")

func _plugin_ready() -> void:
	if _transaction:
		_transaction.transaction_committed.connect(invalidate)
	GameEvents.authoritative_change_committed.connect(invalidate)

func register_presenter(id: StringName, domains: Array, visible: Callable, present: Callable) -> Dictionary:
	if _presenters.has(id): return {"ok":false, "reason_code":"duplicate_presenter"}
	var registration = Registration.create(id, domains, visible, present)
	if not registration.is_valid(): return {"ok":false, "reason_code":"invalid_presenter"}
	_presenters[id] = registration
	return {"ok":true}

func unregister_presenter(id: StringName) -> bool:
	if _flushing: return false
	return _presenters.erase(id)

func invalidate(change_set: Variant, _ledger_summary: Dictionary = {}) -> void:
	_latest_version = maxi(_latest_version, int(change_set.post_state_version))
	if _projection_registry: _projection_registry.apply_change_set(change_set)
	for id in _presenters:
		if _presenters[id].invalidate(change_set.get_domains(), change_set.post_state_version) and _flushing:
			_invalidated_during_flush[id] = true
	_schedule_flush()

func _schedule_flush() -> void:
	if _flush_scheduled: return
	_flush_scheduled = true
	if is_inside_tree(): call_deferred("flush")

func flush() -> Dictionary:
	if _flushing: return {"flush_version":_latest_version, "presented":[], "failed":[], "next_flush_count":1}
	var flush_started := Time.get_ticks_usec()
	_flush_scheduled = false
	_flushing = true
	_invalidated_during_flush.clear()
	var version := _latest_version
	var report := {"flush_version":version, "queued":[], "presented":[], "skipped_hidden":[],
		"failed":[], "coalesced_domains":[], "elapsed_usec":{}, "next_flush_count":0}
	var all_domains: Array = []
	var ids: Array = _presenters.keys(); ids.sort_custom(func(a, b): return String(a) < String(b))
	for id in ids:
		var registration = _presenters[id]
		if not registration.queue_if_visible():
			if registration.state == Registration.State.DIRTY_HIDDEN: report.skipped_hidden.append(String(id))
			continue
		report.queued.append(String(id))
		var dirty: Array[StringName] = registration.begin_presenting()
		all_domains.append_array(dirty)
		var started := Time.get_ticks_usec()
		var outcome: Variant = registration.present.call(version, dirty.duplicate())
		report.elapsed_usec[String(id)] = Time.get_ticks_usec() - started
		if outcome is Dictionary and not bool(outcome.get("ok", true)):
			report.failed.append({"presenter_id":String(id),
				"reason":String(outcome.get("reason", "presentation_failed"))})
		else:
			report.presented.append(String(id))
		registration.finish_presenting(version, _invalidated_during_flush.has(id))
	_flushing = false
	report.coalesced_domains = Domains.canonicalize(all_domains)
	report.next_flush_count = _invalidated_during_flush.size()
	if report.next_flush_count > 0: _schedule_flush()
	if _performance_monitor:
		_performance_monitor.record(&"presentation.flush", Time.get_ticks_usec() - flush_started,
			{"registered":_presenters.size(), "presented":report.presented.size(),
			"hidden":report.skipped_hidden.size(), "failed":report.failed.size()})
	return report
