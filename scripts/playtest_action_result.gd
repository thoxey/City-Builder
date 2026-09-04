class_name PlaytestActionResult
extends RefCounted

const SCHEMA_VERSION := 1

const STATUS_APPLIED := "applied"
const STATUS_REJECTED := "rejected"
const STATUS_DUPLICATE := "duplicate"
const STATUS_FAILED := "failed"

const UNKNOWN_CHOICE := "unknown_choice"
const UNKNOWN_BUILDING := "unknown_building"
const INVALID_COORDINATE := "invalid_coordinate"
const INVALID_ROTATION := "invalid_rotation"
const OUTSIDE_BUILDABLE_AREA := "outside_buildable_area"
const OCCUPIED_FOOTPRINT := "occupied_footprint"
const REPLACEMENT_REQUIRED := "replacement_required"
const INSUFFICIENT_CASH := "insufficient_cash"
const BELOW_DEMAND_THRESHOLD := "below_demand_threshold"
const INSUFFICIENT_DEMAND := "insufficient_demand"
const UNMET_PREREQUISITE := "unmet_prerequisite"
const UNIQUE_ALREADY_PLACED := "unique_already_placed"
const NOTHING_TO_DEMOLISH := "nothing_to_demolish"
const DEMOLITION_NOT_ALLOWED := "demolition_not_allowed"
const INVALID_HOURS := "invalid_hours"
const SEQUENCE_CONFLICT := "sequence_conflict"

static func applied(details: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"status": STATUS_APPLIED,
		"changed": true,
		"reason": null,
		"details": details,
	}

static func rejected(reason: String, details: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"status": STATUS_REJECTED,
		"changed": false,
		"reason": reason,
		"details": details,
	}
