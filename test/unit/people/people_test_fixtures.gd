class_name PeopleTestFixtures
extends RefCounted

class CommunityDouble:
	extends RefCounted
	var intents: Array[Dictionary] = []
	var revision := 1
	func get_civilian_intents(_include_unhoused := true) -> Array:
		return intents.duplicate(true)
	func get_civilian_intent(resident_id: int) -> Dictionary:
		for intent in intents:
			if int(intent.get("resident_id", -1)) == resident_id:
				return intent.duplicate(true)
		return {}
	func get_assignment_revision() -> int: return revision
	func get_resident_records(_include_effects := false) -> Array:
		return intents.duplicate(true)

class ClockDouble:
	extends RefCounted
	var absolute_hour := 8
	func get_absolute_hour() -> int: return absolute_hour
	func current_hour() -> int: return absolute_hour % 24

class RouteDouble:
	extends RefCounted
	var revision := 1
	var routes: Dictionary = {}
	func get_revision() -> int: return revision
	func resolve_civilian_route(origin: Vector2i, destination: Vector2i) -> Dictionary:
		return routes.get("%d,%d>%d,%d" % [origin.x, origin.y, destination.x, destination.y], {
			"ok": false, "road_revision": revision, "blocked_reason": "disconnected"
		}).duplicate(true)

static func intent(resident_id: int, home: Vector2i, destination: Variant,
		purpose := "home", revision := 1, absolute_hour := 8) -> Dictionary:
	return {
		"resident_id": resident_id,
		"resident_seed": resident_id * 97,
		"home_anchor": {"x": home.x, "z": home.y},
		"assignment_revision": revision,
		"absolute_hour": absolute_hour,
		"purpose": purpose,
		"destination_anchor": null if destination == null else {"x": destination.x, "z": destination.y},
		"destination_building_id": "" if destination == null else "fixture_destination",
		"source_effect_ids": [],
		"active": purpose in ["work", "activity"],
		"valid_until_hour": absolute_hour + 1,
		"reachable": destination != null,
		"blocked_reason": "resident_unhoused" if destination == null else "",
	}
