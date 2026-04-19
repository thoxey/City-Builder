extends GutTest

## Unit tests for the Nameplate plugin.
##
## The plugin listens to GameEvents.structure_placed / structure_demolished
## and maintains a Vector2i-anchored dictionary of Label3D billboards.
## Tests stub BuildingCatalog's summary lookup and fire GameEvents directly.

const NameplatePluginCls := preload("res://plugins/nameplate/nameplate_plugin.gd")

var _plate: Node
var _stub_catalog: Object
var _saved_registry: Dictionary

func before_each() -> void:
	_saved_registry = GameState.building_registry.duplicate(true)
	GameState.building_registry = {}

	_stub_catalog = _StubCatalog.new()
	_plate = NameplatePluginCls.new()
	_plate._catalog = _stub_catalog
	add_child(_plate)
	# Full _plugin_ready does the container setup + GameEvents wiring — we want
	# both for these tests so that placed/demolished signals take effect.
	_plate._plugin_ready()

func after_each() -> void:
	if _plate and is_instance_valid(_plate):
		# Disconnect before free to avoid dangling signal hits from later tests.
		if GameEvents.structure_placed.is_connected(_plate._on_structure_placed):
			GameEvents.structure_placed.disconnect(_plate._on_structure_placed)
		if GameEvents.structure_demolished.is_connected(_plate._on_structure_demolished):
			GameEvents.structure_demolished.disconnect(_plate._on_structure_demolished)
		if GameEvents.map_loaded.is_connected(_plate._on_map_loaded):
			GameEvents.map_loaded.disconnect(_plate._on_map_loaded)
		_plate.queue_free()
	_plate = null
	GameState.building_registry = _saved_registry

# ── Placement creates labels ──────────────────────────────────────────────────

func test_place_unique_creates_label() -> void:
	_stub_catalog.register(0, "building_pub", "Pub", "unique")

	GameEvents.structure_placed.emit(Vector3i(3, 0, 4), 0, 0)

	assert_eq(_plate.label_count(), 1, "one label per placement")
	assert_true(_plate.has_label_at(Vector2i(3, 4)))
	assert_eq(_plate.label_text_at(Vector2i(3, 4)), "Pub")

func test_place_generic_creates_label() -> void:
	_stub_catalog.register(0, "building_small_a", "House", "generic")

	GameEvents.structure_placed.emit(Vector3i(1, 0, 2), 0, 0)

	assert_eq(_plate.label_count(), 1, "generics get labels")

# ── Placement skips road + nature ─────────────────────────────────────────────

func test_place_road_skipped() -> void:
	_stub_catalog.register(0, "road_straight", "Road", "road")

	GameEvents.structure_placed.emit(Vector3i(0, 0, 0), 0, 0)

	assert_eq(_plate.label_count(), 0, "roads never get labels")

func test_place_nature_skipped() -> void:
	_stub_catalog.register(0, "grass", "Grass", "nature")

	GameEvents.structure_placed.emit(Vector3i(5, 0, 5), 0, 0)

	assert_eq(_plate.label_count(), 0, "nature never gets labels")

# ── Demolition removes labels ─────────────────────────────────────────────────

func test_demolish_removes_label() -> void:
	_stub_catalog.register(0, "building_pub", "Pub", "unique")
	GameEvents.structure_placed.emit(Vector3i(3, 0, 4), 0, 0)
	assert_eq(_plate.label_count(), 1)

	GameEvents.structure_demolished.emit(Vector3i(3, 0, 4))

	assert_eq(_plate.label_count(), 0, "label cleared on demolish")
	assert_false(_plate.has_label_at(Vector2i(3, 4)))

func test_demolish_unknown_cell_is_noop() -> void:
	GameEvents.structure_demolished.emit(Vector3i(99, 0, 99))
	assert_eq(_plate.label_count(), 0, "ignores cells we never labelled")

# ── Overbuild replaces label ──────────────────────────────────────────────────

func test_overbuild_replaces_label() -> void:
	_stub_catalog.register(0, "building_pub", "Pub", "unique")
	_stub_catalog.register(1, "building_medical", "Medical Centre", "unique")

	GameEvents.structure_placed.emit(Vector3i(3, 0, 4), 0, 0)
	GameEvents.structure_placed.emit(Vector3i(3, 0, 4), 1, 0)

	assert_eq(_plate.label_count(), 1, "same anchor holds one label")
	assert_eq(_plate.label_text_at(Vector2i(3, 4)), "Medical Centre")

# ── Visibility toggle ─────────────────────────────────────────────────────────

func test_toggle_flips_container_visibility() -> void:
	_stub_catalog.register(0, "building_pub", "Pub", "unique")
	GameEvents.structure_placed.emit(Vector3i(3, 0, 4), 0, 0)

	assert_true(_plate.is_visible(), "default on")
	_plate._set_visible(false)
	assert_false(_plate.is_visible())
	assert_false(_plate._container.visible, "container follows flag")

	_plate._set_visible(true)
	assert_true(_plate._container.visible)

# ── Rebuild from registry ─────────────────────────────────────────────────────

func test_rebuild_from_registry_restores_labels() -> void:
	_stub_catalog.register(0, "building_pub", "Pub", "unique")
	_stub_catalog.register(1, "grass", "Grass", "nature")

	GameState.building_registry = {
		1: {"anchor": Vector2i(2, 3), "structure": 0, "orientation": 0, "cells": []},
		2: {"anchor": Vector2i(5, 5), "structure": 1, "orientation": 0, "cells": []},  # nature — skipped
	}

	_plate._rebuild_from_registry()

	assert_eq(_plate.label_count(), 1, "one building labelled, nature skipped")
	assert_true(_plate.has_label_at(Vector2i(2, 3)))
	assert_false(_plate.has_label_at(Vector2i(5, 5)))

# ── Unknown struct_idx is tolerated ───────────────────────────────────────────

func test_unknown_struct_idx_skipped() -> void:
	# No register() call → stub returns {}
	GameEvents.structure_placed.emit(Vector3i(0, 0, 0), 42, 0)
	assert_eq(_plate.label_count(), 0, "missing summary → no label, no crash")

# ── Stub catalog ──────────────────────────────────────────────────────────────

## Minimal BuildingCatalog stand-in exposing only get_summary_by_index.
## Extends PluginBase so the plugin's `_catalog: PluginBase` field accepts it.
class _StubCatalog extends PluginBase:
	var summaries: Dictionary = {}  # int index -> summary dict

	func get_plugin_name() -> String: return "_StubCatalog"

	func register(idx: int, bid: String, display_name: String, category: String) -> void:
		summaries[idx] = {
			"building_id": bid,
			"display_name": display_name,
			"category": category,
		}

	func get_summary_by_index(idx: int) -> Dictionary:
		return summaries.get(idx, {})
