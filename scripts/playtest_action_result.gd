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
const TOWN_HALL_REQUIRED := "town_hall_required"
const TOWN_HALL_ALREADY_PLACED := "town_hall_already_placed"
const NOT_CONNECTED_TO_TOWN_HALL := "not_connected_to_town_hall"
const FULFILLED_DEMAND_NOT_REACHED := "fulfilled_demand_not_reached"
const REQUIRED_TIER_NOT_REACHED := "required_tier_not_reached"
const WANT_NOT_REVEALED := "want_not_revealed"
const PATRON_NOT_READY := "patron_not_ready"
const UNKNOWN_CHARACTER := "unknown_character"
const UNKNOWN_DIALOGUE_EVENT := "unknown_dialogue_event"
const DIALOGUE_NOT_PENDING := "dialogue_not_pending"
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
