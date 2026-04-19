extends Resource
class_name LandDonationPayload

## Payload attached to a patron landmark. Describes the set of cells added to
## the buildable area when the landmark is placed. Patron JSON authors express
## this as a Dictionary (`donation_area`); PatronSystem hands it to
## BuildableArea, which calls `cells_from_dict()` to expand into Vector2i cells.

## "rect" | "polygon"
@export var shape: String = "rect"

## Used when shape == "rect". Godot Rect2i: (x, y, width, height).
@export var rect: Rect2i = Rect2i()

## Used when shape == "polygon". Each Vector2i is a grid cell.
@export var polygon: PackedVector2Array = PackedVector2Array()

## Converts an authoring-side Dictionary (from patron JSON) into concrete cells.
##
## Accepts:
##   {"shape": "rect",    "rect": [x, y, w, h]}
##   {"shape": "polygon", "polygon": [[x, y], [x, y], ...]}
static func cells_from_dict(area: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var shape_name: String = area.get("shape", "rect")
	match shape_name:
		"rect":
			var arr: Variant = area.get("rect", [])
			if typeof(arr) != TYPE_ARRAY or arr.size() < 4:
				return out
			var r := Rect2i(int(arr[0]), int(arr[1]), int(arr[2]), int(arr[3]))
			for x in range(r.position.x, r.position.x + r.size.x):
				for y in range(r.position.y, r.position.y + r.size.y):
					out.append(Vector2i(x, y))
		"polygon":
			for pair in area.get("polygon", []):
				if typeof(pair) == TYPE_ARRAY and pair.size() >= 2:
					out.append(Vector2i(int(pair[0]), int(pair[1])))
	return out
