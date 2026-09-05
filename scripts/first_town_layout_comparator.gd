extends RefCounted
class_name FirstTownLayoutComparator

const SCHEMA_VERSION := 1
const DEFAULT_PERMITTED := ["anchors", "road_cells"]

static func validate_manifest(manifest: Dictionary, left: Dictionary, right: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if int(manifest.get("schema_version", 0)) != SCHEMA_VERSION: errors.append("unsupported_schema_version")
	if String(manifest.get("pair_id", "")).is_empty(): errors.append("missing_pair_id")
	if String(left.get("scenario_id", "")) != String(manifest.get("left_scenario", "")): errors.append("left_scenario_mismatch")
	if String(right.get("scenario_id", "")) != String(manifest.get("right_scenario", "")): errors.append("right_scenario_mismatch")
	var permitted: Array = manifest.get("permitted_differences", DEFAULT_PERMITTED)
	for value in permitted:
		if value not in ["anchors", "road_cells", "non_road_building_multiset", "nature_multiset", "resident_cohorts"]:
			errors.append("unknown_permitted_difference:%s" % value)
	var left_constants := canonical_constants(left)
	var right_constants := canonical_constants(right)
	for field in left_constants:
		if field in permitted: continue
		if left_constants[field] != right_constants.get(field): errors.append("held_constant_mismatch:%s" % field)
	var declared: Dictionary = manifest.get("held_constant", {})
	for field in declared:
		if left_constants.get(field) != declared[field]: errors.append("declared_constant_mismatch:%s" % field)
	errors.sort()
	return {"admissible": errors.is_empty(), "errors": errors, "left": left_constants, "right": right_constants}

static func canonical_constants(scenario: Dictionary) -> Dictionary:
	var non_road := {}
	var nature := {}
	var anchors: Array = []
	var roads: Array = []
	for raw in scenario.get("layout", []):
		var item: Dictionary = raw
		var kind := String(item.get("kind", "building"))
		var building_id := String(item.get("building_id", ""))
		var anchor := _coordinate(item.get("anchor", {}))
		if kind == "road": roads.append(anchor)
		else:
			non_road[building_id] = int(non_road.get(building_id, 0)) + 1
			anchors.append({"building_id": building_id, "anchor": anchor})
			if kind == "nature": nature[building_id] = int(nature.get(building_id, 0)) + 1
	anchors.sort_custom(func(a: Dictionary, b: Dictionary): return String(a["building_id"]) < String(b["building_id"]) if a["building_id"] != b["building_id"] else JSON.stringify(a["anchor"]) < JSON.stringify(b["anchor"]))
	roads.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["x"]) < int(b["x"]) if a["x"] != b["x"] else int(a["z"]) < int(b["z"]))
	var stream: Array = []
	var cohorts: Array = []
	for raw in scenario.get("fixture", {}).get("residents", []):
		var resident: Dictionary = raw
		stream.append({"resident_id": int(resident.get("resident_id", 0)), "seed": int(resident.get("seed", 0))})
		cohorts.append({"resident_id": int(resident.get("resident_id", 0)), "cohort_id": String(resident.get("cohort_id", "general"))})
	stream.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["resident_id"]) < int(b["resident_id"]))
	cohorts.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["resident_id"]) < int(b["resident_id"]))
	var initial: Dictionary = scenario.get("initial_state", {})
	return {
		"non_road_building_multiset": non_road,
		"nature_multiset": nature,
		"capacities": scenario.get("capacities", {}).duplicate(true),
		"starting_cash": int(initial.get("cash", 0)),
		"starting_demand": initial.get("demand", {}).duplicate(true),
		"resident_stream": stream,
		"resident_cohorts": cohorts,
		"seed": int(scenario.get("seed", 0)),
		"duration_hours": int(scenario.get("duration_hours", 168)),
		"story_enabled": bool(scenario.get("story_enabled", false)),
		"anchors": anchors,
		"road_cells": roads,
	}

static func compare(manifest: Dictionary, left_scenario: Dictionary, right_scenario: Dictionary, left_trace: Dictionary, right_trace: Dictionary) -> Dictionary:
	var validation := validate_manifest(manifest, left_scenario, right_scenario)
	var result := {"pair_id": manifest.get("pair_id", ""), "admissible": validation["admissible"], "errors": validation["errors"], "expectations": [], "passed": false}
	if not validation["admissible"]: return result
	if not bool(left_trace.get("success", false)) or not bool(right_trace.get("success", false)):
		result["errors"].append("non_canonical_trace")
		return result
	var all_pass := true
	for raw in manifest.get("expectations", []):
		var expectation: Dictionary = raw
		var path := String(expectation.get("path", ""))
		var left_value: Variant = _path_value(left_trace.get("final", {}), path)
		var right_value: Variant = _path_value(right_trace.get("final", {}), path)
		var relation := String(expectation.get("relation", "equal"))
		var passed := _relation(left_value, right_value, relation, float(expectation.get("margin", 0.0)))
		all_pass = all_pass and passed
		result["expectations"].append({"path": path, "relation": relation, "left": left_value, "right": right_value, "passed": passed})
	result["passed"] = all_pass
	result["left_hash"] = left_trace.get("state_hash", "")
	result["right_hash"] = right_trace.get("state_hash", "")
	return result

static func _relation(left: Variant, right: Variant, relation: String, margin: float) -> bool:
	match relation:
		"right_gt_left": return float(right) > float(left) if margin <= 0.0 else float(right) >= float(left) + margin
		"right_lt_left": return float(right) < float(left) if margin <= 0.0 else float(right) <= float(left) - margin
		"right_gte_left": return float(right) + 0.000001 >= float(left) + margin
		"right_lte_left": return float(right) - 0.000001 <= float(left) - margin
		"both_gt_zero": return float(left) > 0.0 and float(right) > 0.0
		"not_equal": return left != right
		_: return left == right

static func _path_value(value: Variant, path: String) -> Variant:
	var current: Variant = value
	for segment in path.split("."):
		if not current is Dictionary or not current.has(segment): return null
		current = current[segment]
	return current

static func _coordinate(value: Variant) -> Dictionary:
	return {"x": int(value.get("x", 0)), "z": int(value.get("z", value.get("y", 0)))} if value is Dictionary else {"x": 0, "z": 0}
