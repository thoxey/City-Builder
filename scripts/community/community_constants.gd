extends RefCounted
class_name CommunityConstants

const QUALITIES := ["opportunity", "liveability", "beauty", "belonging"]
const LENSES := ["identity", "freedom", "care"]
const MANIFESTATIONS := ["identity", "freedom", "care", "neutral"]
const SCOPES := ["local", "participant", "resident", "city"]

static func normalized(values: Dictionary, keys: Array, fallback: float = 0.0) -> Dictionary:
	var result := {}
	var total := 0.0
	for key in keys:
		var value := maxf(0.0, float(values.get(key, fallback)))
		result[key] = value
		total += value
	if total <= 0.0:
		var equal := 1.0 / float(keys.size()) if not keys.is_empty() else 0.0
		for key in keys:
			result[key] = equal
		return result
	for key in keys:
		result[key] = float(result[key]) / total
	return result

static func rounded(value: float) -> float:
	return snappedf(value, 0.0001)

static func rounded_map(values: Dictionary) -> Dictionary:
	var result := {}
	var keys := values.keys()
	keys.sort()
	for key in keys:
		var value: Variant = values[key]
		if value is float:
			result[str(key)] = rounded(value)
		elif value is Dictionary:
			result[str(key)] = rounded_map(value)
		else:
			result[str(key)] = value
	return result

static func coordinate(value: Variant) -> Variant:
	if value is Vector2i:
		return value
	if value is Vector3i:
		return Vector2i(value.x, value.z)
	if value is Dictionary and value.has("x") and value.has("z"):
		return Vector2i(int(value["x"]), int(value["z"]))
	return null

static func coordinate_record(value: Variant) -> Variant:
	var cell: Variant = coordinate(value)
	return null if cell == null else {"x": cell.x, "z": cell.y}

static func coordinate_key(value: Variant) -> String:
	var cell: Variant = coordinate(value)
	return "none" if cell == null else "%d,%d" % [cell.x, cell.y]

static func manhattan(a: Variant, b: Variant) -> int:
	var ca: Variant = coordinate(a)
	var cb: Variant = coordinate(b)
	return 2147483647 if ca == null or cb == null else absi(ca.x - cb.x) + absi(ca.y - cb.y)
