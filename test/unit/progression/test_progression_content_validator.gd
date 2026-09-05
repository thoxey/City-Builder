extends GutTest

const Validator := preload("res://scripts/progression_content_validator.gd")

func test_live_progression_content_has_no_broken_references() -> void:
	var result: Dictionary = Validator.validate_repository()
	assert_eq(result.errors, [], "progression content errors: %s" % [result.errors])

func test_reports_file_and_field_for_broken_character_want() -> void:
	var docs := _valid_docs()
	docs.characters[0].want_building_id = "building_missing"
	var result: Dictionary = Validator.validate_documents(docs.characters, docs.patrons, docs.buildings)
	assert_true(result.errors.any(func(error): return error.file == "res://character.json" and error.field == "want_building_id" and error.message.contains("building_missing")))

func test_reports_role_and_prerequisite_mismatches() -> void:
	var docs := _valid_docs()
	docs.buildings[0].profiles[0].chain_role = "chain"
	docs.buildings[0].profiles[0].prerequisite_ids = ["building_missing"]
	var result: Dictionary = Validator.validate_documents(docs.characters, docs.patrons, docs.buildings)
	assert_true(result.errors.any(func(error): return error.field == "want_building_id" and error.message.contains("chain_role=want")))
	assert_true(result.errors.any(func(error): return error.field.contains("prerequisite_ids") and error.message.contains("building_missing")))

func test_rejects_unknown_and_incomplete_bucket_sets_with_context() -> void:
	var docs := _valid_docs()
	docs.characters[2].associated_bucket = "cultural"
	var result: Dictionary = Validator.validate_documents(docs.characters, docs.patrons, docs.buildings)
	assert_true(result.errors.any(func(error): return error.file == "res://character_com.json" and error.field == "associated_bucket" and error.message.contains("cultural")))
	assert_true(result.errors.any(func(error): return error.file == "res://patron.json" and error.field == "character_ids" and error.message.contains("commercial")))

func test_rejects_want_bucket_that_disagrees_with_character() -> void:
	var docs := _valid_docs()
	docs.buildings[0].profiles[0].bucket = "commercial"
	var result: Dictionary = Validator.validate_documents(docs.characters, docs.patrons, docs.buildings)
	assert_true(result.errors.any(func(error): return error.file == "res://character.json" and error.field == "want_building_id" and error.message.contains("associated_bucket residential")))

func _valid_docs() -> Dictionary:
	var characters := [
		{"character_id":"c_res", "character_type":"character", "patron_id":"p", "associated_bucket":"residential", "arrival_requires_tier":1, "want_building_id":"want_res", "_source_path":"res://character.json"},
		{"character_id":"c_ind", "character_type":"character", "patron_id":"p", "associated_bucket":"industrial", "arrival_requires_tier":1, "want_building_id":"want_ind", "_source_path":"res://character_ind.json"},
		{"character_id":"c_com", "character_type":"character", "patron_id":"p", "associated_bucket":"commercial", "arrival_requires_tier":1, "want_building_id":"want_com", "_source_path":"res://character_com.json"},
	]
	var patrons := [{"patron_id":"p", "character_ids":["c_res", "c_ind", "c_com"], "landmark_building_id":"landmark", "donation_area":{"shape":"rect", "rect":[8,-8,12,16]}, "_source_path":"res://patron.json"}]
	var buildings := []
	for row in [["want_res","c_res"], ["want_ind","c_ind"], ["want_com","c_com"]]:
		buildings.append({"building_id":row[0], "profiles":[{"type":"UniqueProfile", "chain_role":"want", "character_id":row[1], "patron_id":"p", "prerequisite_ids":[]}], "_source_path":"res://%s.json" % row[0]})
	buildings.append({"building_id":"landmark", "profiles":[{"type":"UniqueProfile", "chain_role":"landmark", "character_id":"", "patron_id":"p", "prerequisite_ids":["want_res", "want_ind", "want_com"]}], "_source_path":"res://landmark.json"})
	return {"characters":characters, "patrons":patrons, "buildings":buildings}
