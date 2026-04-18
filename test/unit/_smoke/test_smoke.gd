extends GutTest

## Smoke test — proves the GUT runner is working.
## If this fails, nothing below is trustworthy.

func test_true_is_true() -> void:
	assert_true(true, "true should be true")

func test_arithmetic() -> void:
	assert_eq(2 + 2, 4, "basic math")

func test_gut_test_extends_works() -> void:
	# Proves GutTest base class is reachable — an import/wiring issue would fail before this.
	assert_not_null(self, "test instance should exist")
