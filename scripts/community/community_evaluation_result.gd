extends RefCounted
class_name CommunityEvaluationResult

var quality_totals := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var provenance_handles := PackedInt32Array()
var runtime_revision := 0
var _stack_counts: Dictionary = {}
var _scratch_totals := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])

func reset(revision: int, include_provenance: bool = false) -> void:
	runtime_revision = revision
	for index in quality_totals.size(): quality_totals[index] = 0.0
	for index in _scratch_totals.size(): _scratch_totals[index] = 0.0
	_stack_counts.clear()
	if include_provenance: provenance_handles.clear()

func to_totals_dictionary() -> Dictionary:
	var result := {}
	for index in CommunityConstants.QUALITIES.size():
		result[CommunityConstants.QUALITIES[index]] = CommunityConstants.rounded(float(quality_totals[index]))
	return result

func to_operational_dict() -> Dictionary:
	return {"quality_totals":to_totals_dictionary(),"runtime_revision":runtime_revision,
		"provenance_count":provenance_handles.size()}
