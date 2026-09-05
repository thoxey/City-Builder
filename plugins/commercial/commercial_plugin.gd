extends PluginBase

## Commercial building plugin — incremental registration.
##
## Per building, registers with CityStats:
##   • _VisitorSink ("population", priority 100) — customers during open hours
##
## Priority 100 means commercial is served after workplaces (priority 10),
## so residents fill jobs before filling leisure activities.

func get_plugin_name() -> String: return "Commercial"
func get_dependencies() -> Array[String]: return ["CityStats", "Community", "RoadNetwork"]

var _city_stats: PluginBase
var _community: PluginBase
var _road_network: PluginBase

func inject(deps: Dictionary) -> void:
	_city_stats = deps.get("CityStats")
	_community = deps.get("Community")
	_road_network = deps.get("RoadNetwork")

# ── State — keyed by anchor Vector2i ─────────────────────────────────────────

var _visitor_sinks: Dictionary = {}

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	GameEvents.structure_placed.connect(_on_placed)
	GameEvents.structure_demolished.connect(_on_demolished)
	GameEvents.map_loaded.connect(_on_map_loaded)
	_on_map_loaded(null)

# ── Incremental handlers ──────────────────────────────────────────────────────

func _on_placed(pos: Vector3i, idx: int, _orient: int) -> void:
	var profile := GameState.structures[idx].find_metadata(BuildingProfile) as BuildingProfile
	if not profile or profile.category != "commercial": return
	_register(Vector2i(pos.x, pos.z), profile.capacity, profile.active_start, profile.active_end)

func _on_demolished(pos: Vector3i) -> void:
	_unregister(Vector2i(pos.x, pos.z))

func _on_map_loaded(_map) -> void:
	for a in _visitor_sinks: _city_stats.unregister_sink(_visitor_sinks[a])
	_visitor_sinks.clear()

	for bid in GameState.building_registry:
		var entry: Dictionary = GameState.building_registry[bid]
		var sid: int = entry.get("structure", -1)
		if sid < 0 or sid >= GameState.structures.size(): continue
		var profile := GameState.structures[sid].find_metadata(BuildingProfile) as BuildingProfile
		if not profile or profile.category != "commercial": continue
		_register(entry["anchor"], profile.capacity, profile.active_start, profile.active_end)

func _register(anchor: Vector2i, capacity: int, start: float, end: float) -> void:
	var sink := _VisitorSink.new(anchor, capacity, start, end, _community)
	_visitor_sinks[anchor] = sink
	_city_stats.register_sink(sink)

func _unregister(anchor: Vector2i) -> void:
	if _visitor_sinks.has(anchor):
		_city_stats.unregister_sink(_visitor_sinks[anchor])
		_visitor_sinks.erase(anchor)

func get_operation_records(hour: int = -1) -> Array:
	var active_hour := hour
	if active_hour < 0:
		var clock = PluginManager.get_plugin("DayNight")
		active_hour = int(clock.current_hour()) if clock and clock.has_method("current_hour") else 0
	var canonical_by_anchor := {}
	if _community and _community.has_method("get_operation_records"):
		for record in _community.get_operation_records(active_hour):
			var point: Dictionary = record.get("anchor", {})
			if String(record.get("category", "")) == "commercial": canonical_by_anchor["%d,%d" % [point.get("x", 0), point.get("z", 0)]] = record
	var anchors := _visitor_sinks.keys()
	anchors.sort_custom(func(a: Vector2i, b: Vector2i): return a.x < b.x if a.x != b.x else a.y < b.y)
	var result: Array = []
	for anchor: Vector2i in anchors:
		var sink := _visitor_sinks[anchor] as _VisitorSink
		var row: Dictionary = canonical_by_anchor.get("%d,%d" % [anchor.x, anchor.y], {}).duplicate(true)
		row["anchor"] = {"x": anchor.x, "z": anchor.y}
		row["open_now"] = _active_window(active_hour, sink.active_start, sink.active_end)
		row["capacity"] = sink.capacity
		row["fulfilled"] = sink.last_fulfilled
		row["available_capacity"] = maxi(0, sink.capacity - sink.last_fulfilled)
		row["latest_activity"] = sink.last_fulfilled
		var internal_id := _internal_id_at(anchor)
		var proximity: Dictionary = _community.get_town_hall_proximity(internal_id) if _community and _community.has_method("get_town_hall_proximity") else {}
		var bonus := float(proximity.get("shop_activity_bonus", 0.0))
		row["town_hall_proximity"] = proximity
		row["activity_multiplier"] = 1.0 + bonus
		row["effective_activity"] = float(sink.last_fulfilled) * (1.0 + bonus)
		result.append(row)
	return result

func get_town_hall_bonus_income() -> int:
	var tuning := _read_proximity_tuning()
	var income_per_visit := int(tuning.get("commercial_income_per_bonus_visit", 2))
	var total := 0.0
	for anchor in _visitor_sinks:
		var sink := _visitor_sinks[anchor] as _VisitorSink
		var internal_id := _internal_id_at(anchor)
		var proximity: Dictionary = _community.get_town_hall_proximity(internal_id) if _community and _community.has_method("get_town_hall_proximity") else {}
		total += float(sink.last_fulfilled) * float(proximity.get("shop_activity_bonus", 0.0)) * income_per_visit
	return int(round(total))

func _internal_id_at(anchor: Vector2i) -> int:
	return int(GameState.cell_to_building.get(anchor, -1))

static func _read_proximity_tuning() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/community/balance.json"))
	return parsed.get("town_hall_proximity", {}) if parsed is Dictionary else {}

static func _active_window(hour: float, start: float, end: float) -> bool:
	var current := fposmod(hour, 24.0); start = fposmod(start, 24.0); end = fposmod(end, 24.0)
	if is_equal_approx(start, end): return true
	return current >= start and current < end if start < end else current >= start or current < end

# ── Inner class ───────────────────────────────────────────────────────────────

## Visitor demand — draws from population pool during commercial hours.
## Served after workers (priority 100 > 10).
class _VisitorSink extends CityStatSink:
	var anchor: Vector2i
	var capacity:     int
	var active_start: float
	var active_end:   float
	var last_fulfilled: int = 0
	var _community

	func _init(commercial_anchor: Vector2i, cap: int, start: float, end: float, community) -> void:
		anchor = commercial_anchor
		capacity     = cap
		active_start = start
		active_end   = end
		_community = community
		priority = 100

	func get_type_id() -> String: return "population"

	func tick(hour: float) -> int:
		if not _in_window(hour, active_start, active_end):
			return 0
		if _community and _community.has_method("get_fulfilled_activity"):
			return mini(capacity, int(_community.get_fulfilled_activity(anchor, int(hour) % 24)))
		return capacity

	func on_fulfilled(fulfilled: int, _requested: int) -> void:
		last_fulfilled = fulfilled
