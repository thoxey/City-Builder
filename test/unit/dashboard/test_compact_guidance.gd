extends GutTest

const DashboardCls := preload("res://plugins/dashboard/dashboard_plugin.gd")
const VIEW_PATH := "res://plugins/dashboard/compact_guidance_view.gd"

var _dashboard: Node
var _characters := _GuidanceCharacters.new()


func before_each() -> void:
	_dashboard = DashboardCls.new()
	_dashboard._characters = _characters
	add_child(_dashboard)


func after_each() -> void:
	if _dashboard and is_instance_valid(_dashboard):
		_dashboard.queue_free()
	_dashboard = null


func test_generic_growth_direction_is_spoken_by_ambrose_semantically() -> void:
	var snap := DashboardCls.Snapshot.new()
	snap.next_step = {
		"kind":"fulfilled_demand", "subject_id":"aristocrat_commercial",
		"bucket_label":"commerce", "current":63, "required":100,
	}
	var untouched := snap.next_step.duplicate(true)
	var model: Dictionary = _dashboard.build_compact_guidance_model(snap)
	assert_eq(model.get("speaker_id"), "ambrose")
	assert_eq(model.get("speaker_name"), "Ambrose")
	assert_eq(model.get("expression"), "thoughtful")
	assert_eq(model.get("text"), "Place commerce until 100 demand is fulfilled. You're at 63.")
	assert_eq(snap.next_step, untouched, "presentation projection cannot mutate progression")


func test_line_art_request_owner_and_patron_speak_their_own_placement_direction() -> void:
	var request := DashboardCls.Snapshot.new()
	request.next_step = {
		"kind":"place_request", "subject_id":"building_pirate_radio",
		"subject_label":"Pirate Radio Station", "owner_character_id":"aristocrat_residential",
	}
	var request_model: Dictionary = _dashboard.build_compact_guidance_model(request)
	assert_eq(request_model.get("speaker_id"), "aristocrat_residential")
	assert_eq(request_model.get("speaker_name"), "Baba Soyink")
	assert_eq(request_model.get("expression"), "concerned")
	assert_eq(request_model.get("text"), "Place Pirate Radio Station next.")

	var landmark := DashboardCls.Snapshot.new()
	landmark.next_step = {
		"kind":"place_landmark", "subject_id":"building_theatre",
		"subject_label":"The Theatre", "owner_patron_id":"aristocrat",
	}
	var landmark_model: Dictionary = _dashboard.build_compact_guidance_model(landmark)
	assert_eq(landmark_model.get("speaker_id"), "aristocrat_patron")
	assert_eq(landmark_model.get("speaker_name"), "Sir William")
	assert_eq(landmark_model.get("text"), "Place The Theatre next.")


func test_character_without_approved_line_art_is_described_by_ambrose() -> void:
	var snap := DashboardCls.Snapshot.new()
	snap.next_step = {
		"kind":"place_request", "subject_id":"building_members_club",
		"subject_label":"Members Club", "owner_character_id":"aristocrat_commercial",
		"owner_character_label":"Flick",
	}
	var model: Dictionary = _dashboard.build_compact_guidance_model(snap)
	assert_eq(model.get("speaker_id"), "ambrose")
	assert_eq(model.get("text"), "Flick needs a Members Club. Place one next.")
	assert_false(String(model.get("portrait_path", "")).contains("aristocrat_commercial"), "Flick is not integrated yet")


func test_compact_view_is_dismissible_transparent_and_responsive() -> void:
	var view_script: Variant = load(VIEW_PATH)
	assert_not_null(view_script, "compact guidance view exists")
	if view_script == null:
		return
	var view: Control = view_script.new()
	add_child(view)
	view.build()
	view.set_guidance({
		"speaker_id":"ambrose", "speaker_name":"Ambrose", "expression":"thoughtful",
		"text":"Place the Town Hall first.",
		"portrait_path":"res://data/characters/ambrose/expressions/line_art/thoughtful.png",
	})
	view.layout_for_viewport(Vector2(1280, 720))
	var portrait := view.control_for_test("portrait") as TextureRect
	var medallion := view.control_for_test("medallion") as ColorRect
	var bubble := view.control_for_test("bubble") as Panel
	var close_button := view.control_for_test("close_button") as Button
	assert_eq(view.mouse_filter, Control.MOUSE_FILTER_STOP, "surface clicks must be consumed")
	assert_eq(portrait.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(portrait.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	assert_not_null(portrait.material, "portrait material preserves source alpha")
	assert_eq(medallion.color, Color("#e7d3ad"))
	assert_not_null(medallion.material, "light medallion has the same print treatment")
	assert_null(view.control_for_test("emphasis"), "compact medallions have no active-emphasis overlay")
	assert_lt(bubble.size.x, 440.0, "bubble stays compact at 1280")
	assert_lte(bubble.size.y, 128.0, "bubble cannot expand below the compact HUD bounds")
	assert_not_null(close_button)
	assert_eq(close_button.text, "×")
	assert_false(view.find_children("*", "Button", true, false).any(func(button): return button.text in ["Continue", "Finish"]))
	view.layout_for_viewport(Vector2(3840, 2160))
	assert_eq(view.scale, Vector2(2.0, 2.0), "4K guidance scales with the HUD")
	view.set_suppressed(true)
	assert_false(view.visible)
	view.set_suppressed(false)
	assert_true(view.visible)


func test_surface_click_and_close_button_dismiss_only_the_current_direction() -> void:
	var view: Control = load(VIEW_PATH).new()
	add_child(view)
	view.build()
	var model := {
		"kind":"place_request", "target_id":"building_pirate_radio",
		"speaker_id":"aristocrat_residential", "speaker_name":"Baba Soyink",
		"expression":"concerned", "text":"Place Pirate Radio Station next.",
		"portrait_path":"res://data/characters/aristocrat_residential/expressions/line_art/concerned.png",
	}
	view.set_guidance(model)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	view._gui_input(click)
	assert_false(view.visible, "surface click closes the direction")
	view.set_guidance(model)
	assert_false(view.visible, "refreshing the same direction does not reopen it")
	var changed := model.duplicate(true)
	changed["target_id"] = "building_theatre"
	changed["text"] = "Place The Theatre next."
	view.set_guidance(changed)
	assert_true(view.visible, "a new canonical direction may appear")
	(view.control_for_test("close_button") as Button).pressed.emit()
	assert_false(view.visible, "the close button uses the same dismissal path")


func test_opening_tutorial_projection_has_priority_over_patron_guidance() -> void:
	_dashboard._opening_tutorial = _GuidanceTutorial.new()
	var snap := DashboardCls.Snapshot.new()
	snap.next_step = {"kind":"place_request", "subject_id":"later_patron_request"}
	var model: Dictionary = _dashboard.build_compact_guidance_model(snap)
	assert_eq(model.get("kind"), "opening_tutorial")
	assert_eq(model.get("speaker_id"), "ambrose")
	assert_eq(model.get("target_id"), "opening_tutorial|place_town_hall|B01|default")
	assert_eq(model.get("tutorial_step_id"), "place_town_hall")
	assert_true(String(model.get("text", "")).begins_with("AMBROSE PLACEHOLDER:"))


func test_progress_only_tutorial_refresh_keeps_semantic_dismissal_key_stable() -> void:
	var tutorial := _GuidanceTutorial.new()
	_dashboard._opening_tutorial = tutorial
	var snap := DashboardCls.Snapshot.new()
	var first: Dictionary = _dashboard.build_compact_guidance_model(snap)
	tutorial.projection.progress = {"current":1, "required":4, "unit":"road_cells"}
	var refreshed: Dictionary = _dashboard.build_compact_guidance_model(snap)
	assert_eq(first.get("target_id"), refreshed.get("target_id"))
	assert_ne(first.get("progress"), refreshed.get("progress"))


func test_completed_tutorial_returns_to_existing_patron_projection() -> void:
	var tutorial := _GuidanceTutorial.new()
	tutorial.complete = true
	_dashboard._opening_tutorial = tutorial
	var snap := DashboardCls.Snapshot.new()
	snap.next_step = {"kind":"grow"}
	assert_eq(_dashboard.build_compact_guidance_model(snap).get("kind"), "grow")


class _GuidanceCharacters:
	extends PluginBase
	var defs := {
		"ambrose": _definition("ambrose", "Ambrose", "res://data/characters/ambrose"),
		"aristocrat_residential": _definition("aristocrat_residential", "Baba Soyink", "res://data/characters/aristocrat_residential"),
		"aristocrat_patron": _definition("aristocrat_patron", "Sir William", "res://data/characters/william"),
		"aristocrat_commercial": {
			"character_id":"aristocrat_commercial", "display_name":"Flick",
			"portrait":"res://data/characters/aristocrat_commercial/portrait.png",
			"expressions":{"neutral":"res://data/characters/aristocrat_commercial/expressions/neutral.png"},
			"default_expression":"neutral",
		},
	}
	func get_def(character_id: String) -> Dictionary: return defs.get(character_id, {})
	static func _definition(character_id: String, display_name: String, root: String) -> Dictionary:
		return {
			"character_id":character_id, "display_name":display_name,
			"portrait":"%s/portrait.png" % root,
			"expressions":{
				"neutral":"%s/expressions/line_art/neutral.png" % root,
				"pleased":"%s/expressions/line_art/pleased.png" % root,
				"concerned":"%s/expressions/line_art/concerned.png" % root,
				"thoughtful":"%s/expressions/line_art/thoughtful.png" % root,
			},
			"default_expression":"neutral",
		}


class _GuidanceRoadNetwork:
	extends PluginBase
	func get_town_hall_internal_id() -> int: return -1


class _GuidanceTutorial:
	extends PluginBase
	var complete := false
	var projection := {
		"status":"active", "step_id":"place_town_hall", "beat_id":"B01",
		"projection_key":"opening_tutorial|place_town_hall|B01|default",
		"expression":"thoughtful",
		"text":"AMBROSE PLACEHOLDER: tell the player to place the Town Hall",
		"target":{"kind":"building", "id":"building_town_hall", "label":"Town Hall"},
		"progress":{"current":0, "required":1, "unit":"building"},
		"blocker":null,
	}
	func is_complete() -> bool: return complete
	func get_projection() -> Dictionary: return projection.duplicate(true)
