extends GutTest

const Runner := preload("res://scripts/run_rendered_performance_profile.gd")

func test_rendered_profile_records_identity_warmup_ui_entities_and_attribution() -> void:
	var record := Runner.build_profile_record(
		[15000, 16000, 20000, 12000], [1000, 1200, 1800, 900],
		{"buildings":135, "residents":140, "vehicles":16, "ui_presenters":3},
		{"run":1, "warmup_frames":120, "measured_frames":4, "state_hash":"state", "ledger_hash":"ledger"})
	assert_eq(record.workload.buildings, 135)
	assert_eq(record.warmup_frames, 120)
	assert_eq(record.measured_frames, 4)
	assert_eq(record.frame_total.median_usec, 15000)
	assert_eq(record.frame_total.p95_usec, 20000)
	assert_true(record.frame_accounting.coverage_ratio >= 0.95)
	assert_eq(record.state_hash, "state")
	assert_eq(record.ledger_hash, "ledger")

func test_rendered_profile_fails_the_exact_exceeded_boundary() -> void:
	var record := Runner.build_profile_record(
		[17000, 17000, 51000], [1000, 1000, 1000], {"buildings":135},
		{"run":1, "warmup_frames":120, "measured_frames":3, "state_hash":"s", "ledger_hash":"l"})
	assert_has(record.failures, "frame.total:median")
	assert_has(record.failures, "frame.total:max")
