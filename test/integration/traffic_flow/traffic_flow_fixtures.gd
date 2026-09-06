class_name TrafficFlowFixtures
extends RefCounted

const FIXED_DELTA := 1.0 / 30.0
const CarFixtures := preload("res://test/unit/traffic/car_manager_test_fixtures.gd")

static func straight_path(length: int, z := 0, reverse := false) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for x in range(length):
		result.append(Vector3i(x, 0, z))
	if reverse:
		result.reverse()
	return result

static func step_cars(cars: Node, count := 1, delta := FIXED_DELTA) -> void:
	for _index in count:
		cars._process(delta)

static func step_visuals(people: Node, cars: Node, count := 1,
		delta := FIXED_DELTA) -> void:
	for _index in count:
		if cars:
			cars._process(delta)
		if people:
			people._process(delta)

static func snapshot(cars: Node) -> Dictionary:
	return cars.get_traffic_flow_snapshot() if cars.has_method("get_traffic_flow_snapshot") \
		else cars.get_civilian_snapshot()

static func normalized(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			result[key] = normalized(value[key])
		return result
	if value is Array:
		return value.map(func(entry): return normalized(entry))
	if value is float:
		return snappedf(value, 0.0001)
	return value
