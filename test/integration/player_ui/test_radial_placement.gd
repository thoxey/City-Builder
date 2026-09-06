extends GutTest

const PlayerUI := preload("res://plugins/player_ui/player_ui_plugin.gd")
const CompactGuidance := preload("res://plugins/dashboard/compact_guidance_view.gd")

func test_accepted_selection_closes_radial_and_starts_placement_once() -> void:
	var ui := PlayerUI.new()
	ui._palette = _Palette.new(true)
	ui._builder = _Builder.new()
	ui._dock = _Dock.new()
	ui._radial = _Radial.new()
	ui._request_entry("grass")
	assert_eq(ui._palette.requests, ["grass"])
	assert_eq(ui._builder.begin_count, 1)
	assert_eq(ui._radial.close_count, 1)
	assert_eq(ui._dock.placement_ids, ["grass"])
	_free_doubles(ui)
	ui.free()

func test_rejected_selection_keeps_radial_open_and_does_not_place() -> void:
	var ui := PlayerUI.new()
	ui._palette = _Palette.new(false)
	ui._builder = _Builder.new()
	ui._dock = _Dock.new()
	ui._radial = _Radial.new()
	ui._request_entry("locked")
	assert_eq(ui._builder.begin_count, 0)
	assert_eq(ui._radial.close_count, 0)
	assert_eq(ui._radial.model_updates, 1)
	_free_doubles(ui)
	ui.free()

func test_dashboard_and_guidance_safe_regions_compose_at_supported_resolutions() -> void:
	var ui := PlayerUI.new()
	ui._dock = _Dock.new()
	ui._radial = _Radial.new()
	ui._radial.visible = false
	ui._consequences = PlacementConsequencesPanel.new()
	ui._consequences.setup()
	var dashboard := _Dashboard.new()
	add_child(dashboard)
	dashboard._guidance_view.build()
	ui._deps = {"Dashboard":dashboard}

	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		dashboard._guidance_view.layout_for_viewport(viewport_size)
		dashboard._guidance_view.visible = true
		for drawer_open in [false, true]:
			dashboard._panel.visible = drawer_open
			ui._consequences.apply_compact_layout(viewport_size.x)
			ui._process(0.0)
			_assert_panel_clears_guidance_and_dashboard(ui._consequences, dashboard._guidance_view, viewport_size.x, drawer_open)
			# Match PlayerUI's resize callback order after safe regions are known.
			ui._consequences.apply_compact_layout(viewport_size.x)
			_assert_panel_clears_guidance_and_dashboard(ui._consequences, dashboard._guidance_view, viewport_size.x, drawer_open)

	ui._consequences.free()
	dashboard.free()
	ui._dock.free()
	ui._radial.free()
	ui.free()

func _assert_panel_clears_guidance_and_dashboard(panel: PlacementConsequencesPanel,
		guidance: CompactGuidanceView, viewport_width: float, drawer_open: bool) -> void:
	var portrait := guidance.control_for_test("portrait_host")
	var portrait_right := guidance.position.x + (portrait.position.x + portrait.size.x) * guidance.scale.x
	var panel_left := viewport_width * 0.5 + panel.offset_left
	var panel_right := viewport_width * 0.5 + panel.offset_right
	var dashboard_left := viewport_width - (380.0 if drawer_open else 0.0)
	assert_gte(panel_left, portrait_right + PlacementConsequencesPanel.SAFE_MARGIN)
	assert_lte(panel_right, dashboard_left - PlacementConsequencesPanel.SAFE_MARGIN)
	assert_false(_ranges_overlap(panel_left, panel_right, guidance.position.x, portrait_right))

func _ranges_overlap(a_left: float, a_right: float, b_left: float, b_right: float) -> bool:
	return a_left < b_right and b_left < a_right

func _free_doubles(ui: Node) -> void:
	ui._palette.free(); ui._builder.free(); ui._dock.free(); ui._radial.free()

class _Palette extends PluginBase:
	var accepted: bool
	var requests: Array[String] = []
	func _init(value: bool) -> void: accepted = value
	func get_plugin_name() -> String: return "TestPalette"
	func request_select_entry(id: String) -> Dictionary:
		requests.append(id); return {"accepted": accepted}
	func get_build_menu_model() -> Dictionary: return {"entries_by_id": {}}

class _Builder extends Node:
	var begin_count := 0
	func begin_placement_from_palette() -> bool: begin_count += 1; return true
	func is_placement_active() -> bool: return false

class _Dock extends PlayerToolDock:
	var placement_ids: Array[String] = []
	func set_model(_model: Dictionary) -> void: pass
	func show_placement(id: String, _reason: String = "", _rotation: int = 0, _preview: Dictionary = {}) -> void: placement_ids.append(id)

class _Radial extends RadialBuildMenu:
	var close_count := 0
	var model_updates := 0
	func close_menu() -> void: close_count += 1
	func set_model(_model: Dictionary) -> void: model_updates += 1

class _Dashboard extends Node:
	var _panel := PanelContainer.new()
	var _guidance_view := CompactGuidance.new()
	func _init() -> void:
		add_child(_panel)
		add_child(_guidance_view)
