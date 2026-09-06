extends SceneTree

const OUTPUT := "res://specs/018-live-placement-consequences/validation/screenshots"
const VIEWPORTS := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const DockCls := preload("res://plugins/player_ui/tool_dock.gd")
const ConsequencesCls := preload("res://plugins/player_ui/placement_consequences_panel.gd")

var _stage: Control
var _dock: PlayerToolDock
var _panel: PlacementConsequencesPanel
var _captures: Array = []

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.theme = load("res://themes/player_ui_theme.tres")
	root.add_child(_stage)
	for viewport_size in VIEWPORTS:
		root.size = viewport_size
		DisplayServer.window_set_size(viewport_size)
		_build_stage(viewport_size)
		_panel.show_quote(_valid_quote())
		await _frames(4)
		await _shot(viewport_size, "valid-location")
		_panel.show_quote(_replacement_quote())
		await _frames(3)
		await _shot(viewport_size, "replacement-uncertain")
	_panel.show_quote({"status":"invalid", "reason":"outside_buildable_area"})
	await _frames(3)
	await _shot(VIEWPORTS[-1], "invalid-location")
	var file := FileAccess.open(OUTPUT.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"feature":"018-live-placement-consequences","renderer":"normal","captures":_captures}, "  "))
	file.close()
	print("PLACEMENT_CONSEQUENCES_CAPTURE success=true files=%d" % _captures.size())
	quit()

func _build_stage(viewport_size: Vector2i) -> void:
	for child in _stage.get_children():
		_stage.remove_child(child)
		child.queue_free()
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("397f73")
	_stage.add_child(background)
	for index in 18:
		var block := ColorRect.new()
		block.position = Vector2(45 + (index % 9) * viewport_size.x / 9.5, 75 + (index / 9) * viewport_size.y * 0.48)
		block.size = Vector2(85 + (index % 3) * 18, 65 + (index % 4) * 12)
		block.color = Color("6f6651") if index % 2 == 0 else Color("4d5964")
		block.rotation = deg_to_rad(-4.0 + float(index % 5) * 2.0)
		background.add_child(block)
	_dock = DockCls.new()
	_stage.add_child(_dock)
	_dock.setup()
	_dock.set_model({"entries_by_id":{"garage":{
		"display_name":"Garage", "icon_key":"workshop", "representative_cash_cost":120,
		"representative_demand_cost":{"bucket_id":"industrial","cost":5.0},
		"authored_effects":[
			{"quality":"opportunity","amount":8.0,"scope":"participant","reason":"Garage employment"},
			{"quality":"liveability","amount":-6.0,"scope":"local","reason":"Garage noise"},
			{"quality":"beauty","amount":-4.0,"scope":"local","reason":"Garage visual impact"},
		],
	}}})
	_dock.show_placement("garage")
	_panel = ConsequencesCls.new()
	_stage.add_child(_panel)
	_panel.setup()
	_panel.apply_compact_layout(viewport_size.x)

func _valid_quote() -> Dictionary:
	return {
		"status":"valid", "access":{"ok":true}, "same_type_neighbours":1,
		"community":{"quality_deltas":{"opportunity":0.0,"liveability":-9.5,"beauty":-6.0,"belonging":0.0},"affected_resident_count":3,"affected_home_count":2,"effect_radii":[1]},
		"attractiveness":{"city_delta":-14,"affected_tile_count":5}, "uncertainties":[],
	}

func _replacement_quote() -> Dictionary:
	var quote := _valid_quote()
	quote.status = "replacement"
	quote.replacement = {"removed_buildings":[{"internal_id":2,"building_id":"home"}]}
	quote.uncertainties = ["reachable_assignment_after_commit"]
	return quote

func _shot(viewport_size: Vector2i, state: String) -> void:
	var image := root.get_texture().get_image()
	var name := "%dx%d-%s.png" % [viewport_size.x, viewport_size.y, state]
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(name)))
	if error != OK:
		push_error("placement_consequence_capture_failed:%s:%s" % [name, error])
		quit(1)
		return
	_captures.append({"file":name,"viewport":[viewport_size.x,viewport_size.y],"state":state})

func _frames(count: int) -> void:
	for _index in count:
		await process_frame
