extends PluginBase

## Residential building plugin.
## Scans for structures with BuildingProfile.category == "residential" and
## registers one CityStatSource per building with CityStats.
##
## Residential buildings supply "population" (available residents) all day.
## The active window in BuildingProfile is ignored for sources — residents are
## always potentially available; sinks (workplaces, commercial) control when
## they draw on that pool.

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

		var source := _ResidentialSource.new(profile.capacity)
		_sources.append(source)

	for s in _sources:
		_city_stats.register_source(s)

	print("[Residential] %d buildings registered as population sources" % _sources.size())

# ── Inner source ──────────────────────────────────────────────────────────────

class _ResidentialSource extends CityStatSource:
	var capacity: int

	func _init(cap: int) -> void:
		capacity = cap

	func get_type_id() -> String:
		return "population"

	func tick(_hour: float) -> int:
		return capacity  # residents always available as a pool
