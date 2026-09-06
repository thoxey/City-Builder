class_name OpeningBalanceAgent
extends RefCounted

const SCENARIO_ID := "first_town/opening_balance"
const NATURE_ID := "building_nature_patch"
const HOME_ID := "building_small_a"
const WORK_ID := "building_garage"
const SHOP_ID := "building_small_b"
const TERRACE_ID := "building_postwar_terrace"

var _records: Array = []
var _milestones: Dictionary = {}
var _failures: Array[String] = []
var _candidate_cursor := 0
var _request_number := 0
var _beauty_established := false

func run(playtest: Object, seed: int, config: Dictionary, label := "") -> Dictionary:
	_records.clear()
	_milestones.clear()
	_failures.clear()
	_candidate_cursor = 0
	_request_number = 0
	_beauty_established = false
	var started: Dictionary = playtest.start_session({
		"scenario_id": SCENARIO_ID, "seed": seed,
		"narrative_mode": "presentation_disabled",
	})
	if started.has("error"):
		_failures.append("session_start_failed:%s" % started)
		return _report(seed, label, {}, config)
	var snapshot: Dictionary = started.get("snapshot", {})
	_observe_milestones(snapshot, config)
	while not endpoint_reached(snapshot, config):
		if _records.size() >= int(config.get("max_actions", 1000)):
			_failures.append("max_actions_exceeded")
			break
		if _hour(snapshot) >= int(config.get("max_hours", 240)):
			_failures.append("max_hours_exceeded")
			break
		var choices: Array = playtest.get_choices().get("choices", [])
		var decision: Dictionary = _decide(snapshot, choices, config)
		var before: Dictionary = state_slice(snapshot)
		var outcome: Dictionary
		if decision["kind"] == "advance":
			outcome = _command(playtest, "advance", {"hours": 1})
		else:
			outcome = _place_next_candidate(playtest, String(decision["building_id"]), config,
				bool(decision.get("fixed", false)), decision.get("anchor", {}))
		var after: Dictionary = playtest.get_snapshot()
		_record(decision, before, state_slice(after), outcome)
		if String(outcome.get("status", "")) == PlaytestActionResult.STATUS_REJECTED and bool(decision.get("fixed", false)):
			_failures.append("fixed_placement_rejected:%s:%s" % [decision.get("building_id", ""), outcome.get("reason", "unknown")])
			break
		if decision["kind"] == "advance" and int(outcome.get("details", {}).get("requested_hours", 0)) != 1:
			_failures.append("non_unit_wait")
		if String(outcome.get("status", "")) not in [PlaytestActionResult.STATUS_APPLIED, PlaytestActionResult.STATUS_REJECTED]:
			_failures.append("unexpected_outcome:%s" % outcome)
		if String(outcome.get("status", "")) == PlaytestActionResult.STATUS_REJECTED and before.get("state_hash") != state_slice(after).get("state_hash"):
			_failures.append("rejection_changed_state")
		snapshot = after
		_observe_milestones(snapshot, config)
	if not endpoint_reached(snapshot, config) and _failures.is_empty():
		_failures.append("endpoint_not_reached")
	return _report(seed, label, snapshot, config)

func _decide(snapshot: Dictionary, choices: Array, config: Dictionary) -> Dictionary:
	var ids: Array = _building_ids(snapshot)
	if "building_town_hall" not in ids:
		return {"kind":"place", "building_id":"building_town_hall", "anchor":config.get("town_hall", {}),
			"fixed":true, "reason":"Establish the rooted town authority", "blockers":[]}
	for road_cell in config.get("road_cells", []):
		if not _building_at(snapshot, road_cell, "road"):
			return {"kind":"place", "building_id":"road", "anchor":road_cell, "fixed":true,
				"reason":"Extend the declared reusable rooted road grid", "blockers":[]}
	var beauty := int(snapshot.get("attractiveness", {}).get("total", 0))
	var beauty_floor := int(config.get("beauty_floor", 200))
	var beauty_target := beauty_floor + int(config.get("beauty_reserve", 0))
	if beauty < beauty_target:
		return {"kind":"place", "building_id":NATURE_ID,
			"reason":"Raise Beauty from %d toward the %d operating target (floor %d)" % [beauty, beauty_target, beauty_floor], "blockers":[]}
	_beauty_established = true
	if HOME_ID not in ids and _building_available(choices, HOME_ID):
		return {"kind":"place", "building_id":HOME_ID,
			"reason":"Exercise the first affordable Homes choice", "blockers":[]}
	if WORK_ID not in ids and _building_available(choices, WORK_ID):
		return {"kind":"place", "building_id":WORK_ID,
			"reason":"Exercise the first affordable Work choice", "blockers":[]}
	if SHOP_ID not in ids and _building_available(choices, SHOP_ID):
		return {"kind":"place", "building_id":SHOP_ID,
			"reason":"Exercise the first affordable Shops choice", "blockers":[]}
	if TERRACE_ID not in ids and _building_available(choices, TERRACE_ID):
		return {"kind":"place", "building_id":TERRACE_ID,
			"reason":"Place the live prerequisite for the 75-Homes mid-block gate", "blockers":[]}
	return {"kind":"advance", "reason":"No intended placement is currently legal and affordable; advance one hour",
		"blockers":wait_blockers(snapshot, choices, config)}

func _place_next_candidate(playtest: Object, building_id: String, config: Dictionary,
		fixed: bool, fixed_anchor: Dictionary) -> Dictionary:
	if fixed:
		return _command(playtest, "place", {"building_id":building_id, "anchor":fixed_anchor})
	var cells: Array = config.get("candidate_cells", [])
	while _candidate_cursor < cells.size():
		var anchor: Dictionary = cells[_candidate_cursor]
		_candidate_cursor += 1
		var outcome: Dictionary = _command(playtest, "place", {"building_id":building_id, "anchor":anchor})
		if String(outcome.get("status", "")) == PlaytestActionResult.STATUS_APPLIED:
			return outcome
		# Candidate rejection is retained by the Playtest trace. Continue scanning
		# before allowing time to advance, because another legal cell may exist.
	return PlaytestActionResult.rejected("no_candidate_cell", {"building_id":building_id})

func _command(playtest: Object, operation: String, params: Dictionary) -> Dictionary:
	_request_number += 1
	params = params.duplicate(true)
	params["request_id"] = "opening-%04d" % _request_number
	params["snapshot_mode"] = "none"
	return playtest.handle_command(operation, params)

func _record(decision: Dictionary, before: Dictionary, after: Dictionary, outcome: Dictionary) -> void:
	var request := {"operation":decision.get("kind", ""), "building_id":decision.get("building_id")}
	var outcome_anchor: Variant = outcome.get("details", {}).get("anchor")
	if outcome_anchor != null:
		request["anchor"] = outcome_anchor
	elif decision.has("anchor"):
		request["anchor"] = decision.get("anchor", {}).duplicate(true)
	_records.append({
		"index":_records.size() + 1,
		"sequence":outcome.get("sequence", -1),
		"absolute_hour":after.get("absolute_hour", 0),
		"decision":decision.get("kind", ""),
		"reason":decision.get("reason", ""),
		"blockers":decision.get("blockers", []).duplicate(true),
		"request":request,
		"outcome":{"status":outcome.get("status", ""), "reason":outcome.get("reason"), "details":outcome.get("details", {}).duplicate(true)},
		"before":before, "after":after, "delta":state_delta(before, after),
	})

func _observe_milestones(snapshot: Dictionary, config: Dictionary) -> void:
	var ids: Array = _building_ids(snapshot)
	var checks: Dictionary = {
		"town_hall_placed":"building_town_hall" in ids,
		"rooted_grid_complete":_road_grid_complete(snapshot, config),
		"beauty_200":int(snapshot.get("attractiveness", {}).get("total", 0)) >= int(config.get("beauty_floor", 200)),
		"first_home":HOME_ID in ids,
		"first_work":WORK_ID in ids,
		"first_shop":SHOP_ID in ids,
		"terrace_placed":TERRACE_ID in ids,
		"homes_total_75":_homes_total(snapshot) >= float(config.get("endpoint_total_homes", 75)),
		"midblock_unlocked":endpoint_reached(snapshot, config),
	}
	for milestone_id in checks:
		if checks[milestone_id] and not _milestones.has(milestone_id):
			_milestones[milestone_id] = {
				"milestone_id":milestone_id, "absolute_hour":_hour(snapshot),
				"sequence":snapshot.get("sequence", 0), "decision_index":_records.size(),
				"state_hash":snapshot.get("state_hash", ""),
				"beauty":snapshot.get("attractiveness", {}).get("total", 0),
				"demand":snapshot.get("demand", {}).duplicate(true),
			}

func _report(seed: int, label: String, snapshot: Dictionary, config: Dictionary) -> Dictionary:
	var milestones: Array = _milestones.values()
	milestones.sort_custom(func(a, b): return int(a.get("decision_index", 0)) < int(b.get("decision_index", 0)))
	var summary: Dictionary = summarize(_records, snapshot, config)
	var semantic: Array = []
	for record in _records:
		semantic.append({"absolute_hour":record.absolute_hour, "decision":record.decision,
			"reason":record.reason, "blockers":record.blockers, "request":record.request,
			"outcome":record.outcome, "after_hash":record.after.state_hash})
	return {
		"seed":seed, "run_label":label, "success":_failures.is_empty() and endpoint_reached(snapshot, config),
		"failures":_failures.duplicate(), "decisions":_records.duplicate(true),
		"milestones":milestones, "summary":summary,
		"final":{"state":state_slice(snapshot), "buildings":snapshot.get("buildings", []).duplicate(true),
			"endpoint_gate":snapshot.get("progression", {}).get("story_buildings", {}).get(String(config.get("endpoint_building_id", "")), {}).duplicate(true)},
		"semantic_trace_hash":JSON.stringify(semantic).sha256_text(),
	}

static func endpoint_reached(snapshot: Dictionary, config: Dictionary) -> bool:
	var id := String(config.get("endpoint_building_id", "building_postwar_midblock"))
	var gate: Dictionary = snapshot.get("progression", {}).get("story_buildings", {}).get(id, {})
	return bool(gate.get("unlocked", false)) and _homes_total(snapshot) >= float(config.get("endpoint_total_homes", 75))

static func state_slice(snapshot: Dictionary) -> Dictionary:
	return {"absolute_hour":_hour(snapshot), "cash":snapshot.get("economy", {}).get("cash", 0),
		"beauty":snapshot.get("attractiveness", {}).get("total", 0),
		"demand":snapshot.get("demand", {}).duplicate(true),
		"building_count":snapshot.get("buildings", []).size(),
		"available_choice_count":snapshot.get("available_choice_count", 0),
		"state_hash":snapshot.get("state_hash", "")}

static func state_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var result: Dictionary = {"hours":int(after.get("absolute_hour", 0)) - int(before.get("absolute_hour", 0)),
		"cash":float(after.get("cash", 0)) - float(before.get("cash", 0)),
		"beauty":float(after.get("beauty", 0)) - float(before.get("beauty", 0)),
		"buildings":int(after.get("building_count", 0)) - int(before.get("building_count", 0)), "demand":{}}
	for bucket in ["residential", "industrial", "commercial"]:
		result["demand"][bucket] = {}
		for field in ["total", "fulfilled", "unserved"]:
			result["demand"][bucket][field] = float(after.get("demand", {}).get(bucket, {}).get(field, 0)) - float(before.get("demand", {}).get(bucket, {}).get(field, 0))
	return result

static func wait_blockers(snapshot: Dictionary, choices: Array, config: Dictionary) -> Array:
	var blockers: Array = []
	var endpoint := String(config.get("endpoint_building_id", "building_postwar_midblock"))
	var gate: Dictionary = snapshot.get("progression", {}).get("story_buildings", {}).get(endpoint, {})
	for reason in gate.get("reasons", []): blockers.append("endpoint:%s" % reason)
	if _homes_total(snapshot) < float(config.get("endpoint_total_homes", 75)):
		blockers.append("residential_total:%.1f/%.1f" % [_homes_total(snapshot), float(config.get("endpoint_total_homes", 75))])
	for building_id in [HOME_ID, WORK_ID, SHOP_ID, TERRACE_ID]:
		for choice in choices:
			if building_id in choice.get("variants", []) and not bool(choice.get("available", false)):
				blockers.append("%s:%s" % [building_id, ",".join(choice.get("reasons", []))])
	blockers.sort()
	if blockers.is_empty(): blockers.append("no_intended_placement")
	return blockers

static func summarize(records: Array, snapshot: Dictionary, config: Dictionary) -> Dictionary:
	var idle_hours := 0
	var wait_spans: Array = []
	var active_wait_span: Dictionary = {}
	var rejection_count := 0
	var constraints := {}
	var beauty_history: Array = []
	var minimum_beauty := 1_000_000
	var minimum_after_floor := 1_000_000
	var floor_established := false
	var demand_earned := {"residential":0.0, "industrial":0.0, "commercial":0.0}
	var demand_spent := {"residential":0.0, "industrial":0.0, "commercial":0.0}
	for record in records:
		if record.decision == "advance":
			var waited := int(record.delta.hours)
			idle_hours += waited
			if active_wait_span.is_empty():
				active_wait_span = {"start_hour":int(record.before.absolute_hour), "end_hour":int(record.after.absolute_hour),
					"hours":waited, "start_decision_index":int(record.index), "end_decision_index":int(record.index),
					"initial_blockers":record.blockers.duplicate(true), "final_blockers":record.blockers.duplicate(true)}
			else:
				active_wait_span["end_hour"] = int(record.after.absolute_hour)
				active_wait_span["hours"] = int(active_wait_span.hours) + waited
				active_wait_span["end_decision_index"] = int(record.index)
				active_wait_span["final_blockers"] = record.blockers.duplicate(true)
		elif not active_wait_span.is_empty():
			wait_spans.append(active_wait_span)
			active_wait_span = {}
		if record.outcome.status == PlaytestActionResult.STATUS_REJECTED: rejection_count += 1
		for blocker in record.blockers: constraints[blocker] = int(constraints.get(blocker, 0)) + 1
		beauty_history.append({"absolute_hour":record.absolute_hour, "value":record.after.beauty})
		minimum_beauty = mini(minimum_beauty, int(record.after.beauty))
		if int(record.after.beauty) >= int(config.get("beauty_floor", 200)):
			floor_established = true
		if floor_established:
			minimum_after_floor = mini(minimum_after_floor, int(record.after.beauty))
		for bucket in demand_earned:
			var total_delta := float(record.delta.demand[bucket].total)
			var fulfilled_delta := float(record.delta.demand[bucket].fulfilled)
			demand_earned[bucket] += maxf(0.0, total_delta)
			demand_spent[bucket] += maxf(0.0, fulfilled_delta)
	if not active_wait_span.is_empty(): wait_spans.append(active_wait_span)
	return {"elapsed_hours":_hour(snapshot), "idle_hours":idle_hours, "wait_spans":wait_spans,
		"action_count":records.size(), "placement_rejections":rejection_count,
		"demand_earned":demand_earned, "demand_spent":demand_spent,
		"beauty_floor":config.get("beauty_floor", 200), "minimum_observed_beauty":0 if records.is_empty() else minimum_beauty,
		"minimum_after_floor_established":null if minimum_after_floor == 1_000_000 else minimum_after_floor,
		"beauty_history":beauty_history, "resource_constraints":constraints,
		"final_homes_total":_homes_total(snapshot), "endpoint_reached":endpoint_reached(snapshot, config)}

static func _building_available(choices: Array, building_id: String) -> bool:
	for choice in choices:
		if building_id in choice.get("variants", []): return bool(choice.get("available", false))
	return false

static func _building_ids(snapshot: Dictionary) -> Array:
	var result: Array = []
	for building in snapshot.get("buildings", []): result.append(String(building.get("building_id", "")))
	return result

static func _building_at(snapshot: Dictionary, point: Dictionary, building_id: String) -> bool:
	for building in snapshot.get("buildings", []):
		var actual_id := String(building.get("building_id", ""))
		var matches := actual_id == building_id
		if building_id == "road":
			matches = building.get("category", "") == "road" or building.get("pool_id", "") == "road" or actual_id.begins_with("road_")
		if not matches: continue
		var anchor: Dictionary = building.get("anchor", {})
		if int(anchor.get("x", 0)) == int(point.get("x", 0)) and int(anchor.get("z", 0)) == int(point.get("z", 0)): return true
	return false

static func _road_grid_complete(snapshot: Dictionary, config: Dictionary) -> bool:
	for cell in config.get("road_cells", []):
		if not _building_at(snapshot, cell, "road"): return false
	return true

static func _homes_total(snapshot: Dictionary) -> float:
	return float(snapshot.get("demand", {}).get("residential", {}).get("total", 0.0))

static func _hour(snapshot: Dictionary) -> int:
	return int(snapshot.get("simulation", {}).get("absolute_hour", snapshot.get("absolute_hour", 0)))
