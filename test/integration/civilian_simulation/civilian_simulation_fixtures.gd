class_name CivilianSimulationFixtures
extends RefCounted

const FIXED_DELTA := 1.0 / 30.0

static func step_visuals(people: Node, cars: Node, seconds: float,
		delta: float = FIXED_DELTA) -> void:
	var steps := maxi(0, int(ceil(seconds / delta)))
	for _index in steps:
		if cars and cars.has_method("_process"):
			cars._process(delta)
		if people and people.has_method("_process"):
			people._process(delta)

static func capture(playtest: Node) -> Dictionary:
	var snapshot: Dictionary = playtest.get_snapshot(false)
	return normalize(snapshot.get("civilian_simulation", {}))

static func normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			if String(key) in ["display_position", "wall_clock_ms", "frame_time_ms"]:
				continue
			result[key] = normalize(value[key])
		return result
	if value is Array:
		return value.map(func(entry): return normalize(entry))
	if value is float:
		return snappedf(value, 0.0001)
	return value
