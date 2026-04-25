@tool
extends RefCounted

## ManifestExporter — editor-time scanner for res://data/** → _manifest.json.
##
## Plain RefCounted so it can be exercised both from the EditorPlugin menu item
## and from a headless SceneTree driver (tests, CI). Does not depend on
## EditorInterface beyond an optional filesystem-rescan nudge the plugin layer
## triggers after writing.

const MANIFEST_PATH := "res://data/events/_manifest.json"

const CHARACTERS_DIR := "res://data/characters"
const PATRONS_DIR    := "res://data/patrons"
const BUILDINGS_DIR  := "res://data/buildings"
const EVENTS_DIR     := "res://data/events"

# Keep this in sync with EventSystem.TRIGGER_SIGNALS. The SPA uses it to
# populate the trigger dropdown; `manual` is appended for fire_event-only flows.
const TRIGGERS := [
	"character_arrived",
	"character_want_revealed",
	"character_satisfied",
	"character_state_changed",
	"demand_fulfilled_changed",
	"demand_total_changed",
	"demand_unserved_changed",
	"patron_landmark_ready",
	"patron_landmark_completed",
	"unique_placed",
	"buildable_area_expanded",
	"manual",
]

const EVENT_TYPES := ["dialogue", "newspaper", "notification"]
const BUCKETS := ["residential", "commercial", "industrial"]
## Bucket type IDs as referenced by the demand system + trigger filters.
## Distinct from BUCKETS (which are building-side categories) — kept as its
## own list so the SPA's bucket-trigger picker has the canonical names.
const BUCKET_TYPE_IDS := ["housing_demand", "industrial_demand", "commercial_demand", "desirability"]
const CATEGORIES := ["road", "nature", "generic", "unique"]
const CHARACTER_STATES := ["NOT_ARRIVED", "ARRIVED", "WANT_REVEALED", "SATISFIED", "CONTRIBUTES_TO_LANDMARK"]
const PATRON_STATES := ["LOCKED", "LANDMARK_AVAILABLE", "COMPLETED"]


func build_manifest() -> Dictionary:
	var characters := _scan_characters()
	var patrons    := _scan_patrons()
	var buildings  := _scan_buildings()
	var events     := _scan_events()
	var flags      := _collect_flags(events)

	return {
		"exported_at": Time.get_datetime_string_from_system(true),
		"event_types": EVENT_TYPES,
		"triggers": TRIGGERS,
		"buckets": BUCKETS,
		"bucket_type_ids": BUCKET_TYPE_IDS,
		"categories": CATEGORIES,
		"character_states": CHARACTER_STATES,
		"patron_states": PATRON_STATES,
		"characters": characters,
		"patrons": patrons,
		"buildings": buildings,
		"events": events,
		"flags": flags,
	}


func write_manifest(manifest: Dictionary) -> int:
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if f == null: return FileAccess.get_open_error()
	f.store_string(JSON.stringify(manifest, "\t"))
	f.close()
	return OK


# ---- character / patron / building / event scanners ----

func _scan_characters() -> Array:
	var out: Array = []
	for path in _list_json(CHARACTERS_DIR, false):
		var d := _read_json(path)
		if d.is_empty(): continue
		out.append({
			"character_id":         String(d.get("character_id", "")),
			"display_name":         String(d.get("display_name", "")),
			"bio":                  String(d.get("bio", "")),
			"patron_id":            String(d.get("patron_id", "")),
			"associated_bucket":    String(d.get("associated_bucket", "")),
			"arrival_threshold":    float(d.get("arrival_threshold", 0)),
			"arrival_requires_tier": int(d.get("arrival_requires_tier", 1)),
			"want_building_id":     String(d.get("want_building_id", "")),
			"portrait":             String(d.get("portrait", "")),
			"_path":                path,
		})
	out.sort_custom(func(a, b): return a["character_id"] < b["character_id"])
	return out


func _scan_patrons() -> Array:
	var out: Array = []
	for path in _list_json(PATRONS_DIR, false):
		var d := _read_json(path)
		if d.is_empty(): continue
		out.append({
			"patron_id":            String(d.get("patron_id", "")),
			"display_name":         String(d.get("display_name", "")),
			"bio":                  String(d.get("bio", "")),
			"character_ids":        d.get("character_ids", []),
			"landmark_building_id": String(d.get("landmark_building_id", "")),
			"portrait":             String(d.get("portrait", "")),
			"donation_area":        d.get("donation_area", {}),
			"_path":                path,
		})
	out.sort_custom(func(a, b): return a["patron_id"] < b["patron_id"])
	return out


func _scan_buildings() -> Array:
	var out: Array = []
	for path in _list_json(BUILDINGS_DIR, true, "_"):
		var d := _read_json(path)
		if d.is_empty(): continue
		var entry: Dictionary = {
			"building_id":  String(d.get("building_id", "")),
			"display_name": String(d.get("display_name", "")),
			"category":     String(d.get("category", "")),
			"pool_id":      String(d.get("pool_id", "")),
			"model_path":   String(d.get("model_path", "")),
			"_path":        path,
			"chain_role":   "",
			"patron_id":    "",
			"character_id": "",
			"bucket":       "",
			"tier":         0,
			# Full building body so the SPA can round-trip edits without a
			# second read — mirrors the events[].body embedding.
			"body":         d,
		}
		for p in d.get("profiles", []):
			var t := String(p.get("type", ""))
			if t == "UniqueProfile":
				entry["chain_role"]   = String(p.get("chain_role", ""))
				entry["patron_id"]    = String(p.get("patron_id", ""))
				entry["character_id"] = String(p.get("character_id", ""))
				entry["bucket"]       = String(p.get("bucket", ""))
				entry["tier"]         = int(p.get("tier", 0))
				break
		out.append(entry)
	out.sort_custom(func(a, b): return a["building_id"] < b["building_id"])
	return out


func _scan_events() -> Array:
	var out: Array = []
	for path in _list_json(EVENTS_DIR, true):
		if path.ends_with("_manifest.json"): continue
		var d := _read_json(path)
		if d.is_empty(): continue
		var trigger: Dictionary = d.get("trigger", {})
		out.append({
			"event_id":             String(d.get("event_id", "")),
			"event_type":           String(d.get("event_type", "")),
			"trigger_event":        String(trigger.get("event", "")),
			"trigger_character_id": String(trigger.get("character_id", "")),
			"trigger_patron_id":    String(trigger.get("patron_id", "")),
			"trigger_building_id":  String(trigger.get("building_id", "")),
			"enabled_if":           String(d.get("enabled_if", "")),
			"category":             _category_from_path(path),
			"_path":                path,
			# Full event body so the SPA can open any event without a second
			# disk round-trip — critical for the download-mode fallback where
			# the user can't read arbitrary paths after uploading the manifest.
			"body":                 d,
		})
	out.sort_custom(func(a, b): return a["event_id"] < b["event_id"])
	return out


func _collect_flags(events: Array) -> Array:
	var seen: Dictionary = {}
	for ev in events:
		var path: String = ev.get("_path", "")
		if path == "": continue
		var d := _read_json(path)
		_walk_effects_for_flags(d.get("payload", {}), seen)
	var arr: Array = seen.keys()
	arr.sort()
	return arr


func _walk_effects_for_flags(payload, seen: Dictionary) -> void:
	if payload is Dictionary:
		for k in payload.keys():
			_walk_effects_for_flags(payload[k], seen)
	elif payload is Array:
		for item in payload:
			if item is Dictionary and String(item.get("kind", "")) == "set_flag":
				var target := String(item.get("target", ""))
				if target != "": seen[target] = true
			_walk_effects_for_flags(item, seen)


# ---- filesystem helpers ----

## Walks `dir`. When `recurse` is true, descends into subdirectories. Any
## directory whose name begins with `skip_prefix` (and its children) is
## skipped — mirrors BuildingCatalog's "_pools" sidecar convention.
func _list_json(dir: String, recurse: bool, skip_prefix: String = "") -> Array:
	var out: Array = []
	_walk_dir(dir, recurse, skip_prefix, out)
	out.sort()
	return out

func _walk_dir(dir: String, recurse: bool, skip_prefix: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null: return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name == "." or name == "..":
			name = d.get_next(); continue
		var full := dir.path_join(name)
		if d.current_is_dir():
			if recurse and (skip_prefix == "" or not name.begins_with(skip_prefix)):
				_walk_dir(full, true, skip_prefix, out)
		elif name.ends_with(".json"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()

func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("[DataEditorTools] cannot open %s" % path)
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[DataEditorTools] non-dict JSON at %s" % path)
		return {}
	return parsed

func _category_from_path(path: String) -> String:
	var rel := path.trim_prefix(EVENTS_DIR + "/")
	var parts := rel.split("/")
	if parts.size() >= 2: return parts[0]
	return ""
