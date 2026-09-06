extends GutTest

const Domains := preload("res://scripts/presentation/invalidation_domains.gd")
const Registration := preload("res://scripts/presentation/presenter_registration.gd")

func test_invalidation_vocabulary_is_finite_and_canonical() -> void:
	assert_true(Domains.is_valid(&"community"))
	assert_false(Domains.is_valid(&"community_everything"))
	assert_eq(Domains.canonicalize([&"traffic", &"clock", &"traffic"]), [&"clock", &"traffic"])

func test_source_mapping_rejects_unknown_sources() -> void:
	assert_eq(Domains.for_source(&"map_clear"), Domains.ALL)
	assert_true(Domains.for_source(&"unknown").is_empty())

func test_presenter_registration_coalesces_latest_version_and_retains_hidden_dirty_state() -> void:
	var visibility := {"value": false}
	var registration = Registration.create(&"community.panel", [&"community"], func(): return visibility["value"], func(_version, _domains): pass)
	assert_true(registration.is_valid())
	registration.invalidate([&"community"], 3)
	registration.invalidate([&"community"], 5)
	assert_eq(registration.target_version, 5)
	assert_eq(registration.state, Registration.State.DIRTY_HIDDEN)
	visibility["value"] = true
	assert_true(registration.queue_if_visible())
	assert_eq(registration.state, Registration.State.QUEUED)
