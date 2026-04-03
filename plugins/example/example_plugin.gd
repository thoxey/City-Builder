extends PluginBase
## Example plugin — delete or disable when no longer needed.
## Demonstrates the full plugin pattern: events + clock ticks + state access.

func _plugin_ready() -> void:
	# GameState.gridmap, .structures, .map are safe to access from here on
	GameEvents.structure_placed.connect(_on_structure_placed)
	GameEvents.structure_demolished.connect(_on_structure_demolished)
	GameEvents.cash_changed.connect(_on_cash_changed)
	GameEvents.map_loaded.connect(_on_map_loaded)
	GameClock.tick.connect(_on_tick)
	print("[ExamplePlugin] ready — gridmap cells: ", GameState.gridmap.get_used_cells().size())

func _on_structure_placed(position: Vector3i, structure_index: int, orientation: int) -> void:
	var structure_name = GameState.structures[structure_index].model.resource_path.get_file()
	print("[ExamplePlugin] placed %s at %s (orientation %d)" % [structure_name, position, orientation])

func _on_structure_demolished(position: Vector3i) -> void:
	print("[ExamplePlugin] demolished at ", position)

func _on_cash_changed(new_amount: int) -> void:
	print("[ExamplePlugin] cash: $", new_amount)

func _on_map_loaded(map: DataMap) -> void:
	print("[ExamplePlugin] map loaded — cash: $%d, tiles: %d" % [map.cash, map.structures.size()])

func _on_tick(tick_number: int) -> void:
	# Sample every 5 ticks — use tick_number % N for any cadence
	if tick_number % 5 == 0:
		print("[ExamplePlugin] tick %d — tiles on map: %d" % [tick_number, GameState.gridmap.get_used_cells().size()])
