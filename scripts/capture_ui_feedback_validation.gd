extends SceneTree

const OUTPUT := "res://specs/017-ui-feedback-improvements/validation/screenshots"
const VIEWPORTS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3840, 2160)]
const DialogueView := preload("res://plugins/dialogue/dialogue_thread_view.gd")

var _stage: Control
var _viewport: SubViewport
var _manifest: Array = []


func _initialize() -> void:
	call_deferred("_capture_matrix")


func _capture_matrix() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_viewport = SubViewport.new()
	_viewport.name = "UIFeedbackCaptureViewport"
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	root.add_child(_viewport)
	_stage = Control.new()
	_stage.name = "UIFeedbackValidationStage"
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(_stage)
	for viewport_size in VIEWPORTS:
		_viewport.size = viewport_size
		await _frames(4)
		await _capture_dialogue(viewport_size)
		await _capture_demand_and_placement(viewport_size)
	await _capture_feedback_curve(Vector2i(1920, 1080))
	_write_manifest()
	print("UI_FEEDBACK_CAPTURE success=true files=%d viewports=%d" % [_manifest.size(), VIEWPORTS.size()])
	quit()


func _capture_dialogue(viewport_size: Vector2i) -> void:
	_reset_stage()
	var dialogue := DialogueView.new()
	_stage.add_child(dialogue)
	dialogue.build()
	dialogue.set_counterpart_portrait("ambrose", "Ambrose", null, "thoughtful", true)
	dialogue.append_speech_row(
		"ambrose", "Ambrose", "right",
		"Opportunity, Beauty, Liveability and Belonging belong together. BEAUTY repeats clearly; livability also maps while Beautystone stays ordinary. These longer localized words demonstrate safe wrapping without changing the authored sentence.",
		true, true
	)
	await _frames(5)
	await _shot(viewport_size, "dialogue-keywords-wrap")


func _capture_demand_and_placement(viewport_size: Vector2i) -> void:
	_reset_stage()
	_stage.theme = load("res://themes/player_ui_theme.tres")
	var status_script: GDScript = load("res://plugins/player_ui/status_bar.gd")
	var dock_script: GDScript = load("res://plugins/player_ui/tool_dock.gd")
	if status_script == null or not status_script.can_instantiate() or dock_script == null or not dock_script.can_instantiate():
		push_error("ui_feedback_capture_controls_unavailable")
		quit(1)
		return
	var status: Control = status_script.new()
	_stage.add_child(status)
	status.setup({
		"Demand": _CaptureDemand.new(),
		"UniqueRegistry": _CaptureUniques.new(),
		"BuildingCatalog": _CaptureCatalog.new(),
	})
	status.apply_compact_layout(viewport_size.x)
	status.refresh()
	var hover_card := _hover_card(String(status._demand_hover_projections["residential"]["text"]))
	var ui_scale := clampf(float(viewport_size.x) / 1920.0, 1.0, 2.0)
	hover_card.scale = Vector2(ui_scale, ui_scale)
	hover_card.position = Vector2(maxf(20.0, viewport_size.x * 0.5 - 190.0 * ui_scale), 132.0 * ui_scale)
	_stage.add_child(hover_card)
	var dock: Control = dock_script.new()
	_stage.add_child(dock)
	dock.setup()
	dock.apply_viewport_layout(viewport_size.x)
	dock.set_model({"entries_by_id":{"demonstration-home":{
		"display_name":"Demonstration Home", "icon_key":"residential-tier-one",
		"representative_cash_cost":120,
		"representative_demand_cost":{"bucket_id":"residential", "cost":5.0},
		"authored_effects":[
			{"quality":"opportunity", "amount":3.0, "scope":"city", "reason":"Local jobs"},
			{"quality":"liveability", "amount":-2.0, "scope":"local", "reason":"Busy frontage"},
			{"quality":"beauty", "amount":4.0, "scope":"city", "reason":"Base Beauty"},
			{"quality":"belonging", "amount":1.5, "scope":"local", "reason":"Shared doorstep"},
		],
	}}})
	dock.show_placement("demonstration-home", "", 0, {
		"effects":[{"quality":"beauty", "amount":999.0}],
		"same_type_neighbours":99,
	})
	await _frames(5)
	await _shot(viewport_size, "demand-hover-held-effects")


func _capture_feedback_curve(viewport_size: Vector2i) -> void:
	_viewport.size = viewport_size
	_reset_stage()
	var panel := PanelContainer.new()
	panel.position = Vector2(250, 300)
	panel.size = Vector2(1420, 400)
	_stage.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 24)
	panel.add_child(column)
	var title := _label("Placement feedback — deterministic early fade and slower taper", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 52)
	column.add_child(row)
	var builder_script: GDScript = load("res://scripts/builder.gd")
	if builder_script == null or not builder_script.can_instantiate():
		push_error("ui_feedback_capture_builder_unavailable")
		quit(1)
		return
	for elapsed in [0.0, 0.8, 1.6, 2.4, 3.2]:
		var sample := VBoxContainer.new()
		sample.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := TextureRect.new()
		icon.texture = load("res://sprites/community_icons/game/beauty.png")
		icon.custom_minimum_size = Vector2(112, 112)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate.a = builder_script.placement_feedback_alpha(elapsed)
		sample.add_child(icon)
		var caption := _label("%.1fs\nalpha %.2f" % [elapsed, builder_script.placement_feedback_alpha(elapsed)], 22)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sample.add_child(caption)
		row.add_child(sample)
	await _frames(5)
	await _shot(viewport_size, "feedback-animation-samples")


func _reset_stage() -> void:
	for child in _stage.get_children():
		_stage.remove_child(child)
		child.queue_free()
	_stage.theme = null
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("397f73")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(background)
	for index in range(18):
		var block := ColorRect.new()
		block.position = Vector2(55 + (index % 9) * 215, 110 + (index / 9) * 630)
		block.size = Vector2(125 + (index % 3) * 22, 88 + (index % 4) * 16)
		block.color = Color("6f6651") if index % 2 == 0 else Color("4d5964")
		block.rotation = deg_to_rad(-4.0 + float(index % 5) * 2.0)
		background.add_child(block)


func _hover_card(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "HomesDemandHoverDetail"
	panel.custom_minimum_size = Vector2(380, 235)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e7d3ad")
	style.border_color = Color("171713")
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	var label := _label(text, 20)
	label.add_theme_color_override("font_color", Color("171713"))
	panel.add_child(label)
	return panel


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", load("res://fonts/lilita_one_regular.ttf"))
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _shot(viewport_size: Vector2i, state: String) -> void:
	var image := _viewport.get_texture().get_image()
	var file_name := "%dx%d-%s.png" % [viewport_size.x, viewport_size.y, state]
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(file_name)))
	if error != OK:
		push_error("ui_feedback_capture_failed: %s error=%s" % [file_name, error])
		quit(1)
		return
	_manifest.append({"file":file_name, "viewport":[viewport_size.x, viewport_size.y], "state":state})


func _write_manifest() -> void:
	var file := FileAccess.open(OUTPUT.path_join("manifest.json"), FileAccess.WRITE)
	if file == null:
		push_error("ui_feedback_capture_manifest_failed")
		quit(1)
		return
	file.store_string(JSON.stringify({
		"feature":"017-ui-feedback-improvements",
		"renderer":"normal",
		"high_dpi_policy":"Dialogue and HUD controls scale from the 1920-wide authored canvas up to 2x at 3840; 1280 retains compact 1x controls",
		"feedback_duration_seconds":3.2,
		"captures":_manifest,
	}, "  "))
	file.close()


func _frames(count: int) -> void:
	for _index in count:
		await process_frame


class _CaptureDemand extends RefCounted:
	func get_bucket_snapshot(bucket_id: String) -> Dictionary:
		return {
			"unserved":{"residential":18, "industrial":9, "commercial":7}.get(bucket_id, 0),
			"total":{"residential":75, "industrial":31, "commercial":12}.get(bucket_id, 0),
		}


class _CaptureUniques extends RefCounted:
	func get_all_profiles() -> Dictionary:
		return {
			"building_postwar_terrace":{"bucket":"residential", "prerequisite_threshold":40},
			"building_postwar_midblock":{"bucket":"residential", "prerequisite_threshold":75},
			"building_postwar_tower_block":{"bucket":"residential", "prerequisite_threshold":225},
		}


class _CaptureCatalog extends RefCounted:
	func get_summary_by_id(building_id: String) -> Dictionary:
		return {"display_name":{
			"building_postwar_terrace":"Postwar Terrace",
			"building_postwar_midblock":"Postwar Mid-Block",
			"building_postwar_tower_block":"Postwar Tower Block",
		}.get(building_id, building_id)}
