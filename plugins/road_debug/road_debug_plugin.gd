extends PluginBase
## Debug overlay for the road network.
## Press Tab to toggle. Shows connection directions per tile, coloured by road type.
## Rebuilds automatically when tiles are placed, demolished, or a map is loaded.

const COLORS := {
	RoadMetadata.RoadType.STRAIGHT:     Color(1.0, 1.0, 1.0),
	RoadMetadata.RoadType.CORNER:       Color(0.2, 0.8, 1.0),
	RoadMetadata.RoadType.SPLIT:        Color(1.0, 0.8, 0.1),
	RoadMetadata.RoadType.INTERSECTION: Color(1.0, 0.3, 0.3),
}

const LINE_LENGTH  := 0.38  # how far the connection line extends from tile centre
const ARROW_SIZE   := 0.10  # length of arrowhead branches
const DRAW_HEIGHT  := 0.35  # y offset above the tile surface

var _mesh_instance: MeshInstance3D
var _mesh: ImmediateMesh
var _overlay_visible := false

func _plugin_ready() -> void:
	_mesh = ImmediateMesh.new()

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _mesh
	_mesh_instance.material_override = mat
	_mesh_instance.visible = false
	add_child(_mesh_instance)

	GameEvents.structure_placed.connect(_on_map_changed_3)
	GameEvents.structure_demolished.connect(_on_map_changed_1)
	GameEvents.map_loaded.connect(_on_map_changed_1)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB:
			_overlay_visible = !_overlay_visible
			_mesh_instance.visible = _overlay_visible
			if _overlay_visible:
				_redraw()

# Signal adapters — redraw only when overlay is active
func _on_map_changed_3(_a, _b, _c) -> void:
	if _overlay_visible:
		_redraw()

func _on_map_changed_1(_a) -> void:
	if _overlay_visible:
		_redraw()

func _redraw() -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	for cell in GameState.gridmap.get_used_cells():
		var sid := GameState.gridmap.get_cell_item(cell)
		if sid < 0 or sid >= GameState.structures.size():
			continue

		var road_meta := _get_road_meta(GameState.structures[sid])
		if not road_meta:
			continue

		var orientation := GameState.gridmap.get_cell_item_orientation(cell)
		var world_conns := road_meta.get_world_connections(orientation, GameState.gridmap)
		var color: Color = COLORS.get(road_meta.road_type, Color.WHITE)
		# Tile centre — cell origin is at corner when cell_center = false
		var centre := Vector3(cell.x + 0.5, DRAW_HEIGHT, cell.z + 0.5)

		for conn in world_conns:
			var dir := Vector3(conn.x, 0.0, conn.y)
			var tip := centre + dir * LINE_LENGTH

			# Shaft
			_line(centre, tip, color)

			# Arrowhead
			var perp := Vector3(-dir.z, 0.0, dir.x)  # 90° rotation in XZ
			_line(tip, tip - dir * ARROW_SIZE + perp * ARROW_SIZE, color)
			_line(tip, tip - dir * ARROW_SIZE - perp * ARROW_SIZE, color)

	_mesh.surface_end()

func _line(a: Vector3, b: Vector3, color: Color) -> void:
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(b)

func _get_road_meta(structure: Structure) -> RoadMetadata:
	for m in structure.metadata:
		if m is RoadMetadata:
			return m
	return null
