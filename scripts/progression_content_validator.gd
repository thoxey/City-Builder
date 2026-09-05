class_name ProgressionContentValidator
extends RefCounted

const CHARACTER_DIR := "res://data/characters"
const PATRON_DIR := "res://data/patrons"
const BUILDING_DIR := "res://data/buildings"
const PROGRESSION_BUCKETS := ["residential", "industrial", "commercial"]

static func validate_repository() -> Dictionary:
	return validate_documents(
		_load_json_directory(CHARACTER_DIR, false, "character_id"),
		_load_json_directory(PATRON_DIR, false, "patron_id"),
		_load_json_directory(BUILDING_DIR, true, "building_id")
	)

static func validate_documents(characters: Array, patrons: Array, buildings: Array) -> Dictionary:
	var errors: Array[Dictionary] = []
	var character_by_id := _index(characters, "character_id", errors)
	var patron_by_id := _index(patrons, "patron_id", errors)
	var building_by_id := _index(buildings, "building_id", errors)
	var unique_by_id := {}
	for building in buildings:
		var unique := _profile(building, "UniqueProfile")
		if not unique.is_empty(): unique_by_id[String(building.get("building_id", ""))] = unique

	for character in characters:
		if String(character.get("character_type", "character")) != "character": continue
		var path := String(character.get("_source_path", "<character>"))
		var character_id := String(character.get("character_id", ""))
		var patron_id := String(character.get("patron_id", ""))
		var bucket := String(character.get("associated_bucket", ""))
		var want_id := String(character.get("want_building_id", ""))
		if not patron_by_id.has(patron_id): _error(errors, path, "patron_id", "unknown patron_id %s" % patron_id)
		if bucket not in PROGRESSION_BUCKETS: _error(errors, path, "associated_bucket", "unknown progression bucket %s" % bucket)
		if int(character.get("arrival_requires_tier", 0)) not in [1, 2, 3]: _error(errors, path, "arrival_requires_tier", "must be 1, 2, or 3")
		if not building_by_id.has(want_id):
			_error(errors, path, "want_building_id", "unknown building_id %s" % want_id)
		elif not unique_by_id.has(want_id):
			_error(errors, path, "want_building_id", "%s has no UniqueProfile" % want_id)
		else:
			var want: Dictionary = unique_by_id[want_id]
			if String(want.get("chain_role", "")) != "want": _error(errors, path, "want_building_id", "%s must have chain_role=want" % want_id)
			if String(want.get("character_id", "")) != character_id: _error(errors, path, "want_building_id", "%s must reference character_id %s" % [want_id, character_id])
			if String(want.get("bucket", "")) != bucket: _error(errors, path, "want_building_id", "%s must use associated_bucket %s" % [want_id, bucket])

	for patron in patrons:
		var path := String(patron.get("_source_path", "<patron>"))
		var patron_id := String(patron.get("patron_id", ""))
		var character_ids: Array = patron.get("character_ids", [])
		if character_ids.size() != 3: _error(errors, path, "character_ids", "must contain exactly three characters")
		var buckets := {}
		for cid_v in character_ids:
			var cid := String(cid_v)
			if not character_by_id.has(cid):
				_error(errors, path, "character_ids", "unknown character_id %s" % cid)
				continue
			var character: Dictionary = character_by_id[cid]
			if String(character.get("patron_id", "")) != patron_id: _error(errors, path, "character_ids", "%s must reference patron_id %s" % [cid, patron_id])
			var bucket := String(character.get("associated_bucket", ""))
			if bucket not in PROGRESSION_BUCKETS:
				_error(errors, path, "character_ids", "%s has unknown associated_bucket %s" % [cid, bucket])
				continue
			if buckets.has(bucket): _error(errors, path, "character_ids", "duplicate associated_bucket %s" % bucket)
			buckets[bucket] = true
		for required_bucket in PROGRESSION_BUCKETS:
			if not buckets.has(required_bucket): _error(errors, path, "character_ids", "must include the %s bucket" % required_bucket)
		var landmark_id := String(patron.get("landmark_building_id", ""))
		if not unique_by_id.has(landmark_id):
			_error(errors, path, "landmark_building_id", "unknown unique building_id %s" % landmark_id)
		else:
			var landmark: Dictionary = unique_by_id[landmark_id]
			if String(landmark.get("chain_role", "")) != "landmark": _error(errors, path, "landmark_building_id", "%s must have chain_role=landmark" % landmark_id)
			if String(landmark.get("patron_id", "")) != patron_id: _error(errors, path, "landmark_building_id", "%s must reference patron_id %s" % [landmark_id, patron_id])
		var area: Dictionary = patron.get("donation_area", {})
		var rect: Array = area.get("rect", [])
		if String(area.get("shape", "")) != "rect" or rect.size() != 4 or int(rect[2]) <= 0 or int(rect[3]) <= 0:
			_error(errors, path, "donation_area", "must be a positive [x,z,width,height] rect")

	for building_id in unique_by_id:
		var profile: Dictionary = unique_by_id[building_id]
		var building: Dictionary = building_by_id[building_id]
		var path := String(building.get("_source_path", "<building>"))
		for prerequisite_v in profile.get("prerequisite_ids", []):
			var prerequisite := String(prerequisite_v)
			if not building_by_id.has(prerequisite): _error(errors, path, "profiles.UniqueProfile.prerequisite_ids", "unknown building_id %s" % prerequisite)
		var character_id := String(profile.get("character_id", ""))
		if not character_id.is_empty() and not character_by_id.has(character_id): _error(errors, path, "profiles.UniqueProfile.character_id", "unknown character_id %s" % character_id)
		var patron_id := String(profile.get("patron_id", ""))
		if not patron_id.is_empty() and not patron_by_id.has(patron_id): _error(errors, path, "profiles.UniqueProfile.patron_id", "unknown patron_id %s" % patron_id)
	return {"errors":errors, "warnings":[]}

static func _load_json_directory(path: String, recursive: bool = false, id_field: String = "") -> Array:
	var result: Array = []
	var dir := DirAccess.open(path)
	if dir == null: return result
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		var child := path.path_join(name)
		if dir.current_is_dir() and recursive:
			result.append_array(_load_json_directory(child, true, id_field))
		elif name.ends_with(".json") and not name.begins_with("_"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(child))
			if parsed is Dictionary and (id_field.is_empty() or parsed.has(id_field)):
				parsed["_source_path"] = child
				result.append(parsed)
		name = dir.get_next()
	dir.list_dir_end()
	return result

static func _index(documents: Array, id_field: String, errors: Array[Dictionary]) -> Dictionary:
	var result := {}
	for document in documents:
		var id := String(document.get(id_field, ""))
		var path := String(document.get("_source_path", "<document>"))
		if id.is_empty():
			_error(errors, path, id_field, "is required")
		elif result.has(id):
			_error(errors, path, id_field, "duplicate id %s" % id)
		else:
			result[id] = document
	return result

static func _profile(building: Dictionary, type: String) -> Dictionary:
	for profile in building.get("profiles", []):
		if profile is Dictionary and String(profile.get("type", "")) == type: return profile
	return {}

static func _error(errors: Array[Dictionary], path: String, field: String, message: String) -> void:
	errors.append({"file":path, "field":field, "message":message})
