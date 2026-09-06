extends GutTest

const Registry := preload("res://plugins/presentation/projection_registry.gd")

func test_operational_projection_is_cached_by_dependency_revision_and_detached() -> void:
	var registry = Registry.new()
	var state := {"calls": 0}
	registry.register_projection(&"dashboard.summary", [&"economy"], func(version, revisions):
		state.calls += 1; return {"version": version, "revision": revisions.economy, "rows": [1]})
	registry.set_domain_revision(&"economy", 3)
	var first: Dictionary = registry.get_projection(&"dashboard.summary", 7)
	first.rows.append(2)
	var second: Dictionary = registry.get_projection(&"dashboard.summary", 7)
	assert_eq(state.calls, 1)
	assert_eq(second.rows, [1])
	registry.set_domain_revision(&"economy", 4)
	registry.get_projection(&"dashboard.summary", 8)
	assert_eq(state.calls, 2)
	registry.free()

func test_diagnostic_projection_is_explicit_and_never_called_operationally() -> void:
	var registry = Registry.new()
	var state := {"diagnostics": 0}
	registry.register_projection(&"community.summary", [&"community"], func(_v, _r): return {"population": 2})
	registry.register_diagnostic_projection(&"community.residents", [&"community"], func(_v, _r): state.diagnostics += 1; return [1, 2])
	registry.get_projection(&"community.summary", 1)
	assert_eq(state.diagnostics, 0)
	assert_eq(registry.get_diagnostic_projection(&"community.residents", 1), [1, 2])
	assert_eq(state.diagnostics, 1)
	registry.free()
