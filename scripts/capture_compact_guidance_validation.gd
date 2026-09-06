extends SceneTree

const ViewCls := preload("res://plugins/dashboard/compact_guidance_view.gd")
const OUTPUT := "res://art/ui/dialogue/line-art/reviews/compact-guidance"
const CASES := [
	{
		"size":Vector2i(1280, 720), "slug":"baba-request",
		"model":{
			"speaker_id":"aristocrat_residential", "speaker_name":"Baba Soyink",
			"expression":"concerned", "text":"Place Pirate Radio Station next.",
			"portrait_path":"res://data/characters/aristocrat_residential/expressions/line_art/concerned.png",
		},
	},
	{
		"size":Vector2i(1920, 1080), "slug":"ambrose-growth",
		"model":{
			"speaker_id":"ambrose", "speaker_name":"Ambrose", "expression":"thoughtful",
			"text":"Place commerce until 100 demand is fulfilled. You're at 63.",
			"portrait_path":"res://data/characters/ambrose/expressions/line_art/thoughtful.png",
		},
	},
	{
		"size":Vector2i(3840, 2160), "slug":"william-landmark",
		"model":{
			"speaker_id":"aristocrat_patron", "speaker_name":"Sir William",
			"expression":"thoughtful", "text":"Place The Theatre next.",
			"portrait_path":"res://data/characters/william/expressions/line_art/thoughtful.png",
		},
	},
]

var _captures: Array = []


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for test_case in CASES:
		var viewport_size: Vector2i = test_case["size"]
		var proof_viewport := SubViewport.new()
		proof_viewport.size = viewport_size
		proof_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(proof_viewport)
		_build_context(proof_viewport)
		var guidance: Control = ViewCls.new()
		proof_viewport.add_child(guidance)
		guidance.build()
		guidance.set_guidance(test_case["model"])
		guidance.layout_for_viewport(viewport_size)
		await _frames(4)
		var file_name := "%dx%d-%s.png" % [viewport_size.x, viewport_size.y, test_case["slug"]]
		var error := proof_viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT.path_join(file_name)))
		if error != OK:
			push_error("compact_guidance_capture_failed:%s:%s" % [file_name, error])
			quit(1)
			return
		_captures.append({"file":file_name, "viewport":[viewport_size.x, viewport_size.y], "speaker":test_case["model"]["speaker_id"]})
		proof_viewport.queue_free()
		await process_frame
	_write_manifest()
	print("COMPACT_GUIDANCE_CAPTURE success=true files=%d" % _captures.size())
	quit()


func _build_context(parent: Node) -> void:
	var background := ColorRect.new()
	background.color = Color("#397f73")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(background)
	for index in range(28):
		var block := ColorRect.new()
		block.position = Vector2(120 + (index % 7) * 205, 130 + (index / 7) * 130)
		block.size = Vector2(126, 82)
		block.color = Color("#58705a") if index % 3 else Color("#6f6651")
		block.rotation = deg_to_rad(-4.0 + float(index % 5) * 2.0)
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.add_child(block)


func _write_manifest() -> void:
	var file := FileAccess.open(OUTPUT.path_join("manifest.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"role":"actual-size compact in-game dialogue proofs",
			"input_policy":"surface click and close button dismiss the current direction and consume the pointer event",
			"captures":_captures,
		}, "  "))
		file.close()


func _frames(count: int) -> void:
	for _index in count:
		await process_frame
