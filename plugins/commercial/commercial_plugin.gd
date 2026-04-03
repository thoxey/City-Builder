extends PluginBase

## Commercial building plugin.
## Scans for structures with BuildingProfile.category == "commercial" and
## registers one CityStatSink per building with CityStats.
##
## Commercial buildings demand "population" (visitors/customers) during
## their active window — daytime for shops, evening for pubs.

func get_plugin_name() -> String: return "Commercial"
func get_dependencies() -> Array[String]: return ["CityStats"]

var _city_stats: PluginBase

func inject(deps: Dictionary) -> void:
	_city_stats = deps.get("CityStats")

# ── State ─────────────────────────────────────────────────────────────────────

var _sinks: Array = []  # _CommercialSink

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	GameEvents.structure_placed.connect(func(_a, _b, _c): _rebuild())
	GameEvents.structure_demolished.connect(func(_a): _rebuild())
	GameEvents.map_loaded.connect(func(_a): _rebuild())
	_rebuild()

# ── Build ─────────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	for s in _sinks:
		_city_stats.unregister_sink(s)
	_sinks.clear()

	for cell in GameState.gridmap.get_used_cells():
		var sid: int = GameState.gridmap.get_cell_item(cell)
		if sid < 0 or sid >= GameState.structures.size():
			continue
		var profile: BuildingProfile = GameState.structures[sid].find_metadata(BuildingProfile) as BuildingProfile
		if not profile or profile.category != "commercial":
			continue

		var sink := _CommercialSink.new(profile.capacity, profile.active_start, profile.active_end)
		_sinks.append(sink)

	for s in _sinks:
		_city_stats.register_sink(s)

	print("[Commercial] %d buildings registered as population sinks" % _sinks.size())

# ── Inner sink ────────────────────────────────────────────────────────────────

class _CommercialSink extends CityStatSink:
	var capacity: int
	var active_start: float
	var active_end: float
	var satisfaction: float = 1.0

	func _init(cap: int, start: float, end: float) -> void:
		capacity = cap
		active_start = start
		active_end = end

	func get_type_id() -> String:
		return "population"

	func tick(hour: float) -> int:
		return capacity if _in_window(hour) else 0

	func on_fulfilled(fulfilled: int, requested: int) -> void:
		satisfaction = float(fulfilled) / float(requested) if requested > 0 else 1.0

	func _in_window(hour: float) -> bool:
		if active_end >= active_start:
			return hour >= active_start and hour < active_end
		# Wraps midnight (e.g. 22–2)
		return hour >= active_start or hour < active_end
