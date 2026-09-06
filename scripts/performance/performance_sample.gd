extends RefCounted
class_name PerformanceSample

const BOUNDARIES := [&"hour.total", &"hour.collect", &"hour.validate_reduce", &"hour.commit",
	&"hour.notify", &"projection.operational", &"projection.diagnostic", &"presentation.flush",
	&"building.command", &"building.index_update", &"migration.context", &"migration.candidates",
	&"people.process", &"traffic.admission", &"traffic.process", &"render.submit",
	&"frame.total", &"engine_unattributed"]

var boundary: StringName
var parent_boundary: StringName
var started_usec: int
var elapsed_usec: int
var state_version: int
var absolute_hour: int
var frame_index: int
var build_mode: String
var engine_version: String
var machine_id: String
var seed: int
var town_id: String
var excluded_reason: String
var _workload_counts: Dictionary

static func create(p_boundary: StringName, p_started_usec: int, p_elapsed_usec: int,
		p_state_version: int, p_absolute_hour: int, p_frame_index: int,
		p_workload_counts: Dictionary, p_build_mode: String, p_engine_version: String,
		p_machine_id: String, p_seed: int, p_town_id: String,
		p_parent: StringName = &"", p_excluded_reason: String = "") -> Variant:
	var value = (load("res://scripts/performance/performance_sample.gd") as GDScript).new()
	value.boundary = p_boundary; value.parent_boundary = p_parent
	value.started_usec = p_started_usec; value.elapsed_usec = p_elapsed_usec
	value.state_version = p_state_version; value.absolute_hour = p_absolute_hour
	value.frame_index = p_frame_index; value._workload_counts = p_workload_counts.duplicate(true)
	value.build_mode = p_build_mode; value.engine_version = p_engine_version
	value.machine_id = p_machine_id; value.seed = p_seed; value.town_id = p_town_id
	value.excluded_reason = p_excluded_reason
	return value

func is_valid() -> bool:
	return boundary in BOUNDARIES and started_usec >= 0 and elapsed_usec >= 0 and state_version >= 0

func get_workload_counts() -> Dictionary: return _workload_counts.duplicate(true)

func to_dict() -> Dictionary:
	return {"boundary":String(boundary), "parent_boundary":String(parent_boundary),
		"started_usec":started_usec, "elapsed_usec":elapsed_usec, "state_version":state_version,
		"absolute_hour":absolute_hour, "frame_index":frame_index,
		"workload_counts":get_workload_counts(), "build_mode":build_mode,
		"engine_version":engine_version, "machine_id":machine_id, "seed":seed,
		"town_id":town_id, "excluded_reason":excluded_reason}
