extends PluginBase

## Residential building plugin.
## Scans for structures with BuildingProfile.category == "residential" and
## registers one CityStatSource per building with CityStats.
##
## Residential buildings supply "workers" (residents heading out) during their
## active window (default 06:00–09:00 morning rush).

func get_plugin_name() -> String: return "Residential"
func get_dependencies() -> Array[String]: return ["CityStats"]

var _city_stats: PluginBase

func inject(deps: Dictionary) -> void:
	_city_stats = deps.get("CityStats")

# ── State ─────────────────────────────────────────────────────────────────────

var _sources: Array = []  # _ResidentialSource

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	GameEvents.structure_placed.connect(func(_a, _b, _c): _rebuild())
	GameEvents.structure_demolished.connect(func(_a): _rebuild())
	GameEvents.map_loaded.connect(func(_a): _rebuild())
	_rebuild()

# ── Build ─────────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	for s in _sources:
		_city_stats.unregister_source(s)
	_sources.clear()

	for cell in GameState.gridmap.get_used_cells():
		var sid: int = GameState.gridmap.get_cell_item(cell)
		if sid < 0 or sid >= GameState.structures.size():
			continue
		var profile: BuildingProfile = GameState.structures[sid].find_metadata(BuildingProfile) as BuildingProfile
		if not profile or profile.category != "residential":
			continue

		var source := _ResidentialSource.new(profile.capacity, profile.active_start, profile.active_end)
		_sources.append(source)

	for s in _sources:
		_city_stats.register_source(s)

	print("[Residential] %d buildings registered as worker sources" % _sources.size())

# ── Inner source ──────────────────────────────────────────────────────────────

class _ResidentialSource extends CityStatSource:
	var capacity: int
	var active_start: float
	var active_end: float

	func _init(cap: int, start: float, end: float) -> void:
		capacity = cap
		active_start = start
		active_end = end

	func get_type_id() -> String:
		return "workers"

	func tick(hour: float) -> int:
		return capacity if _in_window(hour) else 0

	func _in_window(hour: float) -> bool:
		if active_end >= active_start:
			return hour >= active_start and hour < active_end
		# Wraps midnight (e.g. active_start=22, active_end=6)
		return hour >= active_start or hour < active_end
