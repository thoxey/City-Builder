extends PluginBase
class_name SimulationTransactionPlugin

const Context := preload("res://scripts/simulation/hour_context.gd")
const Sink := preload("res://scripts/simulation/intent_sink.gd")
const Ledger := preload("res://scripts/simulation/transaction_ledger_entry.gd")
const ChangeSet := preload("res://scripts/simulation/authoritative_change_set.gd")
const Domains := preload("res://scripts/presentation/invalidation_domains.gd")

signal transaction_committed(change_set: Variant, ledger_summary: Dictionary)
signal transaction_rejected(failure: Dictionary, ledger_summary: Dictionary)

const MAX_LEDGER_ENTRIES := 2048

var _contributors := {}
var _reducers := {}
var _active := false
var _ledger: Array = []
var _ledger_hash_state := "transaction-ledger:v1".sha256_text()

func get_plugin_name() -> String: return "SimulationTransaction"
var _performance_monitor: PluginBase

func get_dependencies() -> Array[String]: return ["PerformanceMonitor"]

func inject(deps: Dictionary) -> void:
	_performance_monitor = deps.get("PerformanceMonitor")

func register_contributor(id: StringName, domains: Array, collect: Callable) -> Dictionary:
	if String(id).is_empty() or _contributors.has(id):
		return {"ok": false, "reason_code": "duplicate_contributor"}
	var canonical := Domains.canonicalize(domains)
	if canonical.is_empty() or canonical.size() != domains.size() or not collect.is_valid():
		return {"ok": false, "reason_code": "unknown_domain"}
	_contributors[id] = {"domains": canonical, "collect": collect, "enabled": true}
	return {"ok": true}

func unregister_contributor(id: StringName) -> Dictionary:
	if _active: return {"ok": false, "reason_code": "reentrant_transaction"}
	var existed := _contributors.erase(id)
	return {"ok": existed, "reason_code": "" if existed else "unknown_contributor"}

func set_contributor_enabled(id: StringName, enabled: bool) -> bool:
	if _active or not _contributors.has(id): return false
	_contributors[id]["enabled"] = enabled
	return true

func register_reducer(domain: StringName, allowed_operations: Array, reduce: Callable,
		commit: Callable, phase: int = 0) -> Dictionary:
	if not Domains.is_valid(domain) or _reducers.has(domain) or not reduce.is_valid() or not commit.is_valid():
		return {"ok": false, "reason_code": "unknown_domain"}
	var allowed := {}
	for operation in allowed_operations: allowed[StringName(operation)] = true
	_reducers[domain] = {"allowed": allowed, "reduce": reduce, "commit": commit, "phase": phase}
	return {"ok": true}

func run_hour(absolute_hour: int, clock_hour: int, seed_context: Dictionary = {},
		projections: Dictionary = {}, expected_version: int = -1,
		dependency_revisions: Dictionary = {}) -> Dictionary:
	if _active: return _reject("reentrant_transaction", "", GameState.get_state_version())
	var pre_version := GameState.get_state_version()
	if expected_version >= 0 and expected_version != pre_version:
		return _reject("stale_state_version", "", pre_version)
	_active = true
	var total_started := Time.get_ticks_usec()
	var transaction_id := "hour:%d:version:%d" % [absolute_hour, pre_version]
	var context = Context.create(transaction_id, absolute_hour, int(absolute_hour / 24),
		clock_hour % 24, seed_context, pre_version, projections, dependency_revisions)
	var intents: Array = []
	var collect_started := Time.get_ticks_usec()
	var contributor_ids: Array = _contributors.keys()
	contributor_ids.sort_custom(func(a, b): return String(a) < String(b))
	for contributor_id in contributor_ids:
		var registration: Dictionary = _contributors[contributor_id]
		if not registration.enabled: continue
		var guard := _authority_guard()
		var before := _authority_fingerprint()
		var sink = Sink.create(contributor_id, registration.domains)
		registration.collect.call(context, sink)
		if before != _authority_fingerprint():
			_restore_authority_guard(guard)
			_active = false
			return _reject("collection_side_effect", String(contributor_id), pre_version)
		var failure: Dictionary = sink.failure()
		if not failure.is_empty():
			_active = false
			return _reject(String(failure.reason_code), String(contributor_id), pre_version)
		intents.append_array(sink.intents())
	intents.sort_custom(func(a, b): return a.canonical_key() < b.canonical_key())
	_record_boundary(&"hour.collect", collect_started, absolute_hour, {"contributors":contributor_ids.size(), "intents":intents.size()})
	var reduce_started := Time.get_ticks_usec()
	var seen := {}
	var grouped := {}
	for intent in intents:
		if seen.has(intent.intent_id):
			_active = false
			return _reject("duplicate_intent", intent.intent_id, pre_version, intents)
		seen[intent.intent_id] = true
		if not _reducers.has(intent.target_domain):
			_active = false
			return _reject("unknown_domain", String(intent.target_domain), pre_version, intents)
		var reducer: Dictionary = _reducers[intent.target_domain]
		if not reducer.allowed.has(intent.operation):
			_active = false
			return _reject("unknown_operation", String(intent.operation), pre_version, intents)
		if not grouped.has(intent.target_domain): grouped[intent.target_domain] = []
		grouped[intent.target_domain].append(intent)
	var plans: Array = []
	var changed_domains: Array = [&"clock"]
	var reducer_domains: Array = grouped.keys()
	reducer_domains.sort_custom(func(a, b):
		var ap := int(_reducers[a].phase); var bp := int(_reducers[b].phase)
		return ap < bp if ap != bp else String(a) < String(b))
	for domain in reducer_domains:
		var reducer: Dictionary = _reducers[domain]
		var reduced: Dictionary = reducer.reduce.call(grouped[domain], context)
		if not bool(reduced.get("ok", false)):
			_active = false
			return _reject(String(reduced.get("reason_code", "reducer_failure")), String(domain), pre_version, intents)
		plans.append({"domain": domain, "plan": reduced.get("plan", {}), "commit": reducer.commit})
		changed_domains.append_array(reduced.get("domains", [domain]))
	_record_boundary(&"hour.validate_reduce", reduce_started, absolute_hour, {"reducers":plans.size(), "intents":intents.size()})
	# Every reducer has succeeded before authority is touched.
	var commit_started := Time.get_ticks_usec()
	for entry in plans:
		var reducer_started := Time.get_ticks_usec()
		var committed: Variant = entry.commit.call(entry.plan, context)
		_record_boundary(&"hour.commit", reducer_started, absolute_hour,
			{"reducer":String(entry.domain), "intents":grouped.get(entry.domain, []).size()})
		if committed is Dictionary and not bool(committed.get("ok", false)):
			_active = false
			return _reject(String(committed.get("reason_code", "commit_precondition_failed")), String(entry.domain), pre_version, intents)
	var post_version := GameState.commit_state_version(pre_version)
	if post_version < 0:
		_active = false
		return _reject("commit_precondition_failed", "state_version", pre_version, intents)
	var change_set = ChangeSet.create("change:%s" % transaction_id, &"hourly_transaction",
		transaction_id, pre_version, post_version, Domains.canonicalize(changed_domains), {}, {}, dependency_revisions)
	var ledger := _append_ledger(transaction_id, intents, Ledger.DISPOSITION_COMMITTED,
		Ledger.REASON_OK, pre_version, post_version)
	_active = false
	_record_boundary(&"hour.commit", commit_started, absolute_hour, {"reducers":plans.size(), "intents":intents.size()})
	var summary := _ledger_summary(ledger)
	var notify_started := Time.get_ticks_usec()
	transaction_committed.emit(change_set, summary)
	_record_boundary(&"hour.notify", notify_started, absolute_hour, {"listeners":transaction_committed.get_connections().size()})
	_record_boundary(&"hour.total", total_started, absolute_hour, {"contributors":contributor_ids.size(), "intents":intents.size()})
	return {"ok": true, "transaction_id": transaction_id, "context": context,
		"change_set": change_set, "ledger": ledger, "ledger_summary": summary}

func get_ledger() -> Array: return _ledger.duplicate(true)

func ledger_hash() -> String:
	# A rolling digest keeps the audit identity deterministic without serializing
	# the entire bounded ledger at every hourly commit. It intentionally covers
	# every accepted row, including rows later evicted from the inspection window.
	return _ledger_hash_state

func _reject(reason_code: String, detail: String, version: int, intents: Array = []) -> Dictionary:
	var transaction_id := "rejected:version:%d" % version
	var ledger := _append_ledger(transaction_id, intents, Ledger.DISPOSITION_REJECTED,
		StringName(reason_code), version, version)
	var failure := {"reason_code": reason_code, "detail": detail, "pre_state_version": version}
	var summary := _ledger_summary(ledger)
	transaction_rejected.emit(failure, summary)
	return {"ok": false, "failure": failure, "ledger": ledger, "ledger_summary": summary}

func _append_ledger(transaction_id: String, intents: Array, disposition: StringName,
		reason: StringName, pre_version: int, post_version: int) -> Array:
	var rows: Array = []
	for index in intents.size():
		var row: Dictionary = Ledger.from_intent(transaction_id, index, intents[index], disposition,
			reason, pre_version, post_version)
		rows.append(row)
		_ledger_hash_state = ("%s|%s" % [_ledger_hash_state, JSON.stringify(row)]).sha256_text()
	_ledger.append_array(rows)
	if _ledger.size() > MAX_LEDGER_ENTRIES:
		_ledger = _ledger.slice(_ledger.size() - MAX_LEDGER_ENTRIES)
	return rows

func _ledger_summary(rows: Array) -> Dictionary:
	var dispositions := {}
	for row in rows:
		dispositions[row.disposition] = int(dispositions.get(row.disposition, 0)) + 1
	return {"entries": rows.size(), "dispositions": dispositions, "ledger_hash": ledger_hash()}

func _authority_fingerprint() -> String:
	# Collection guards must remain cheaper than the work they protect. Track the
	# authoritative scalar/container revisions collectors could mutate; detailed
	# record parity is covered by reducer preconditions and replay hashes.
	var payload := {"version": GameState.get_state_version(),
		"registry_size": GameState.building_registry.size(),
		"cell_count": GameState.cell_to_building.size(), "next_building_id":GameState._next_building_id}
	if GameState.map:
		payload["map"] = {"cash":GameState.map.cash,
			"demand_totals":JSON.stringify(GameState.map.demand_totals),
			"resident_count":GameState.map.community_residents.size(),
			"programmes":JSON.stringify(GameState.map.community_programmes),
			"structure_count":GameState.map.structures.size()}
	return JSON.stringify(payload).sha256_text()

func _authority_guard() -> Dictionary:
	if GameState.map == null: return {}
	return {"cash":GameState.map.cash, "demand_totals":GameState.map.demand_totals.duplicate(true),
		"community_programmes":GameState.map.community_programmes.duplicate(true)}

func _restore_authority_guard(guard: Dictionary) -> void:
	if GameState.map == null or guard.is_empty(): return
	GameState.map.cash = int(guard.cash)
	GameState.map.demand_totals = guard.demand_totals.duplicate(true)
	GameState.map.community_programmes = guard.community_programmes.duplicate(true)

func _record_boundary(boundary: StringName, started: int, absolute_hour: int, counts: Dictionary) -> void:
	if _performance_monitor:
		_performance_monitor.record(boundary, Time.get_ticks_usec() - started, counts, absolute_hour)
