extends PluginBase

## BuildingCatalog — walks res://data/buildings/**/*.json and synthesises in-memory
## Structure resources for every building. Replaces the hardcoded structures array
## that main.tscn used to carry.
##
## Loading is eager and idempotent — the first caller triggers the directory walk;
## subsequent calls are no-ops. Builder calls ensure_loaded() early in its _ready()
## so structures are available before the MeshLibrary is built.

const DATA_ROOT := "res://data/buildings"

var _loaded: bool = false
var _structures: Array[Structure] = []
var _by_id: Dictionary = {}       # building_id -> Structure
var _index_by_id: Dictionary = {} # building_id -> int (MeshLibrary item ID)
var _summaries: Array = []        # Array[Dictionary] — editor/telemetry payload

func get_plugin_name() -> String:
	return "BuildingCatalog"

func get_dependencies() -> Array[String]:
	return []

## Kicked off early — Builder calls ensure_loaded() from its _ready(), which runs
## after PluginManager._ready() has already constructed this plugin.
func _plugin_ready() -> void:
	ensure_loaded()

## Idempotent. Safe to call multiple times.
func ensure_loaded(dir: String = DATA_ROOT) -> void:
	if _loaded:
		return
	_loaded = true
	_load_dir(dir)

func get_all() -> Array[Structure]:
	return _structures

func get_by_id(building_id: String) -> Structure:
	return _by_id.get(building_id)

## Look up the MeshLibrary item index assigned to a building_id.
## Renamed from get_index() to avoid shadowing Node.get_index().
func get_item_index(building_id: String) -> int:
	return _index_by_id.get(building_id, -1)

## Reverse lookup: MeshLibrary int index → building_id String.
## Used by the save path to record stable IDs instead of brittle indices.
func get_id_by_index(idx: int) -> String:
	if idx < 0 or idx >= _structures.size():
		return ""
	for bid in _index_by_id:
		if _index_by_id[bid] == idx:
			return bid
	return ""

func get_summary() -> Array:
	return _summaries

# ── Loading ───────────────────────────────────────────────────────────────────

func _load_dir(dir_root: String) -> void:
	print("[BuildingCatalog] loading: dir=%s" % dir_root)
	var files: Array[String] = []
	_walk(dir_root, files)

	var errors := 0
	var entries: Array = []  # {id, structure, summary}
	var seen_ids: Dictionary = {}

	for path: String in files:
		var entry: Dictionary = _load_one(path)
		if entry.is_empty():
			errors += 1
			continue
		var bid: String = entry["id"]
		if seen_ids.has(bid):
			push_error("[BuildingCatalog] duplicate_id: %s (path=%s)" % [bid, path])
			errors += 1
			continue
		seen_ids[bid] = true
		entries.append(entry)

	# Stable alphabetical order by building_id — same order every boot, same indices.
	entries.sort_custom(func(a, b): return a["id"] < b["id"])

	_structures.clear()
	_by_id.clear()
	_index_by_id.clear()
	_summaries.clear()

	for i in entries.size():
		var e: Dictionary = entries[i]
		var bid: String = e["id"]
		var s: Structure = e["structure"]
		_structures.append(s)
		_by_id[bid] = s
		_index_by_id[bid] = i
		_summaries.append(e["summary"])
		print("[BuildingCatalog] assigned: building_id=%s index=%d" % [bid, i])

	print("[BuildingCatalog] loaded: count=%d errors=%d" % [_structures.size(), errors])

## Recursively collect all *.json files under `root` into `out`.
func _walk(root: String, out: Array[String]) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		push_error("[BuildingCatalog] cannot_open_dir: %s" % root)
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var full := root.path_join(name)
		if dir.current_is_dir():
			_walk(full, out)
		elif name.ends_with(".json"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()

## Parse one JSON file into { id, structure, summary }.
## Returns empty Dictionary on error (error already pushed).
func _load_one(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("[BuildingCatalog] empty_or_unreadable: path=%s" % path)
		return {}

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("[BuildingCatalog] invalid_json: path=%s" % path)
		return {}
	var data: Dictionary = parsed

	var bid: String = data.get("building_id", "")
	if bid.is_empty():
		push_error("[BuildingCatalog] missing_building_id: path=%s" % path)
		return {}

	var model_path: String = data.get("model_path", "")
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		push_error("[BuildingCatalog] missing_model: building_id=%s path=%s" % [bid, model_path])
		return {}

	var structure := Structure.new()
	structure.model = load(model_path) as PackedScene
	structure.model_scale = float(data.get("model_scale", 1.0))
	structure.model_offset = _to_vec3(data.get("model_offset", [0, 0, 0]))
	structure.model_rotation_y = float(data.get("model_rotation_y", 0.0))
	structure.footprint = _to_cell_offsets(data.get("footprint", [[0, 0]]))

	var profiles_meta: Array[StructureMetadata] = []
	for profile_any in data.get("profiles", []):
		if typeof(profile_any) != TYPE_DICTIONARY:
			continue
		var profile: Dictionary = profile_any
		var m := _instantiate_profile(profile, bid)
		if m != null:
			profiles_meta.append(m)
	structure.metadata = profiles_meta

	var summary := {
		"building_id": bid,
		"display_name": data.get("display_name", bid),
		"category": data.get("category", ""),
		"tags": data.get("tags", []),
		"model_path": model_path,
	}

	return {"id": bid, "structure": structure, "summary": summary}

## Instantiate a StructureMetadata subclass from a profile dict.
## Unknown types log a warning and return null.
func _instantiate_profile(profile: Dictionary, bid: String) -> StructureMetadata:
	var type_name: String = profile.get("type", "")
	match type_name:
		"BuildingMetadata":
			return BuildingMetadata.new()
		"BuildingProfile":
			var p := BuildingProfile.new()
			p.category = profile.get("category", "")
			p.capacity = int(profile.get("capacity", 10))
			p.active_start = float(profile.get("active_start", 8.0))
			p.active_end = float(profile.get("active_end", 18.0))
			return p
		"PoliceMetadata":
			return PoliceMetadata.new()
		"MedicalMetadata":
			return MedicalMetadata.new()
		"RoadMetadata":
			var r := RoadMetadata.new()
			r.road_type = int(profile.get("road_type", 0))
			var conns: Array[Vector2i] = []
			for c in profile.get("connections", []):
				conns.append(_to_vec2i(c))
			r.connections = conns
			r.speed_limit = int(profile.get("speed_limit", 30))
			r.lanes = int(profile.get("lanes", 1))
			return r
		_:
			push_warning("[BuildingCatalog] unknown_profile_type: building_id=%s type=%s" % [bid, type_name])
			return null

# ── Helpers ───────────────────────────────────────────────────────────────────

static func _to_vec3(arr: Variant) -> Vector3:
	if typeof(arr) == TYPE_ARRAY and arr.size() >= 3:
		return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	return Vector3.ZERO

static func _to_vec2i(arr: Variant) -> Vector2i:
	if typeof(arr) == TYPE_ARRAY and arr.size() >= 2:
		return Vector2i(int(arr[0]), int(arr[1]))
	return Vector2i.ZERO

static func _to_cell_offsets(arr: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if typeof(arr) != TYPE_ARRAY:
		return [Vector2i(0, 0)]
	for item in arr:
		out.append(_to_vec2i(item))
	if out.is_empty():
		out.append(Vector2i(0, 0))
	return out
