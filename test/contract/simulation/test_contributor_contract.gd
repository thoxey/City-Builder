extends GutTest

const Coordinator := preload("res://plugins/simulation/simulation_transaction_plugin.gd")

func test_registration_rejects_duplicate_and_supports_unregistration() -> void:
	var coordinator = Coordinator.new()
	var collect := func(_context, _sink): pass
	assert_true(coordinator.register_contributor(&"economy", [&"economy"], collect).ok)
	var duplicate: Dictionary = coordinator.register_contributor(&"economy", [&"economy"], collect)
	assert_false(duplicate.ok)
	assert_eq(duplicate.reason_code, "duplicate_contributor")
	assert_true(coordinator.unregister_contributor(&"economy").ok)
	assert_true(coordinator.register_contributor(&"economy", [&"economy"], collect).ok)
	coordinator.free()

func test_registration_rejects_unknown_or_empty_domains() -> void:
	var coordinator = Coordinator.new()
	var collect := func(_context, _sink): pass
	assert_false(coordinator.register_contributor(&"bad", [], collect).ok)
	assert_false(coordinator.register_contributor(&"bad", [&"invented"], collect).ok)
	coordinator.free()
