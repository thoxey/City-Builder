extends GutTest

func test_same_bounding_box_can_produce_different_local_coverage() -> void:
	var resident := CommunityResident.new()
	resident.resident_id = 1
	resident.home_anchor = Vector2i.ZERO
	var effect := CommunityEffectProfile.normalize_effect({
		"effect_id": "same_box_greenery", "quality": "beauty", "manifestation": "neutral",
		"amount": 5.0, "scope": "local", "radius": 2,
		"stacking_group": "same_box_greenery", "reason": "Same-box test greenery",
	})
	var covered := CommunityEffectEvaluator.evaluate(resident, [{"building_id": "nature", "anchor": Vector2i(2, 0), "active": true, "effects": [effect]}])
	var uncovered := CommunityEffectEvaluator.evaluate(resident, [{"building_id": "nature", "anchor": Vector2i(2, 2), "active": true, "effects": [effect]}])
	var layout_a := [Vector2i.ZERO, Vector2i(2, 0), Vector2i(2, 2)]
	var layout_b := [Vector2i.ZERO, Vector2i(2, 2), Vector2i(2, 0)]
	assert_eq(_extent(layout_a), _extent(layout_b))
	assert_gt(float(covered["totals"]["beauty"]), float(uncovered["totals"]["beauty"]))

func _extent(cells: Array) -> int:
	var min_x: int = cells.map(func(cell: Vector2i): return cell.x).min()
	var max_x: int = cells.map(func(cell: Vector2i): return cell.x).max()
	var min_y: int = cells.map(func(cell: Vector2i): return cell.y).min()
	var max_y: int = cells.map(func(cell: Vector2i): return cell.y).max()
	return (max_x - min_x + 1) * (max_y - min_y + 1)
