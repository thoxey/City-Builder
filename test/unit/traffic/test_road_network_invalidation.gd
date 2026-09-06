extends GutTest

const RoadNetworkPlugin := preload("res://plugins/traffic/road_network_plugin.gd")

var _saved_gridmap: GridMap
var _saved_structures: Array[Structure]
var _saved_registry: Dictionary
var _gridmap: GridMap
var _network: Node

func before_each() -> void:
	_saved_gridmap = GameState.gridmap
	_saved_structures = GameState.structures
	_saved_registry = GameState.building_registry
	_gridmap = GridMap.new()
	add_child(_gridmap)
	GameState.gridmap = _gridmap
	GameState.structures = []
	GameState.building_registry = {}
	_network = RoadNetworkPlugin.new()
	add_child(_network)
	_network._plugin_ready()

func after_each() -> void:
	_network.queue_free()
	_gridmap.queue_free()
	GameState.gridmap = _saved_gridmap
	GameState.structures = _saved_structures
	GameState.building_registry = _saved_registry

func test_place_demolish_replace_load_and_clear_advance_revision() -> void:
	var initial: int = _network.get_revision()
	GameEvents.structure_placed.emit(Vector3i.ZERO, 0, 0)
	assert_eq(_network.get_revision(), initial + 1)
	GameEvents.structure_demolished.emit(Vector3i.ZERO)
	assert_eq(_network.get_revision(), initial + 2)
	# Replacement is the canonical demolish + place event pair.
	GameEvents.structure_demolished.emit(Vector3i.ZERO)
	GameEvents.structure_placed.emit(Vector3i.ZERO, 0, 0)
	assert_eq(_network.get_revision(), initial + 4)
	GameEvents.map_loaded.emit(DataMap.new())
	assert_eq(_network.get_revision(), initial + 5)
	GameEvents.map_loaded.emit(DataMap.new())
	assert_eq(_network.get_revision(), initial + 6)

func test_every_topology_event_clears_route_and_anchor_query_caches() -> void:
	_prime_query_caches()
	GameEvents.structure_placed.emit(Vector3i.ZERO, 0, 0)
	_assert_query_caches_cleared()
	_prime_query_caches()
	GameEvents.structure_demolished.emit(Vector3i.ZERO)
	_assert_query_caches_cleared()
	# Replacement is a demolition followed by placement; both halves rebuild.
	_prime_query_caches()
	GameEvents.structure_demolished.emit(Vector3i.ZERO)
	_assert_query_caches_cleared()
	_prime_query_caches()
	GameEvents.structure_placed.emit(Vector3i.ZERO, 0, 0)
	_assert_query_caches_cleared()
	_prime_query_caches()
	GameEvents.map_loaded.emit(DataMap.new())
	_assert_query_caches_cleared()

func _prime_query_caches() -> void:
	_network._route_cache["fixture"] = {"reachable":true}
	_network._internal_id_by_anchor[Vector2i.ZERO] = 1
	_network._route_cache_hits = 2
	_network._route_cache_misses = 3

func _assert_query_caches_cleared() -> void:
	assert_eq(_network.get_route_cache_stats(), {"hits":0,"misses":0,"entries":0,"anchor_entries":0})
