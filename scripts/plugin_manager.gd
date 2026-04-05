extends Node

## Central plugin loader and dependency injector.
##
## To add a plugin: append its script to PLUGINS. Order in the array doesn't
## matter — topological sort handles initialisation order based on declared deps.
## To disable a plugin: comment out its line here (no project.godot changes needed).

const PLUGINS: Array[GDScript] = [
	preload("res://plugins/road_debug/road_debug_plugin.gd"),
	preload("res://plugins/traffic/road_network_plugin.gd"),
	preload("res://plugins/traffic/car_manager_plugin.gd"),
	preload("res://plugins/people/people_plugin.gd"),
	preload("res://plugins/day_night/day_night_plugin.gd"),
	preload("res://plugins/city_stats/city_stats_plugin.gd"),
	preload("res://plugins/satisfaction/satisfaction_plugin.gd"),
	preload("res://plugins/residential/residential_plugin.gd"),
	preload("res://plugins/workplace/workplace_plugin.gd"),
	preload("res://plugins/commercial/commercial_plugin.gd"),
	preload("res://plugins/police/police_plugin.gd"),
	preload("res://plugins/medical/medical_plugin.gd"),
	preload("res://plugins/hud/hud_plugin.gd"),
	preload("res://plugins/example/example_plugin.gd"),
]

var _registry: Dictionary = {}  # name → PluginBase

func _ready() -> void:
	# ── Instantiate ───────────────────────────────────────────────────────────
	var instances: Array[PluginBase] = []
	for script: GDScript in PLUGINS:
		var plugin := script.new() as PluginBase
		var plugin_name := plugin.get_plugin_name()
		if plugin_name.is_empty():
			push_error("[PluginManager] Plugin has no name: %s" % script.resource_path)
			continue
		if _registry.has(plugin_name):
			push_error("[PluginManager] Duplicate plugin name '%s'" % plugin_name)
			continue
		_registry[plugin_name] = plugin
		instances.append(plugin)

	# ── Sort by dependency order ───────────────────────────────────────────────
	var ordered := _topo_sort(instances)
	if ordered.is_empty() and not instances.is_empty():
		push_error("[PluginManager] Circular dependency detected — no plugins loaded")
		return

	# ── Inject deps and add to scene tree ────────────────────────────────────
	for plugin in ordered:
		var deps: Dictionary = {}
		for dep_name: String in plugin.get_dependencies():
			if _registry.has(dep_name):
				deps[dep_name] = _registry[dep_name]
			else:
				push_error("[PluginManager] '%s' requires missing plugin '%s'" % [
						plugin.get_plugin_name(), dep_name])
		plugin.inject(deps)
		add_child(plugin)

	print("[PluginManager] loaded %d plugins: %s" % [ordered.size(), _registry.keys()])

	# ── Fire _plugin_ready() once GameState is populated ─────────────────────
	GameState.register_ready_callback(_on_state_ready)

func _on_state_ready() -> void:
	# Iterate children (already in topo order) so deps are always ready first
	for child in get_children():
		(child as PluginBase)._plugin_ready()

## Retrieve a loaded plugin by name at runtime (e.g. from editor tools).
## Returns null if the plugin is not loaded.
func get_plugin(plugin_name: String) -> PluginBase:
	return _registry.get(plugin_name)

# ── Topological sort (Kahn-style DFS) ────────────────────────────────────────

func _topo_sort(plugins: Array[PluginBase]) -> Array[PluginBase]:
	var result: Array[PluginBase] = []
	var state: Dictionary = {}  # name → 0 unvisited | 1 visiting | 2 done

	for plugin in plugins:
		if not _visit(plugin, state, result):
			return []
	return result

func _visit(plugin: PluginBase, state: Dictionary, result: Array[PluginBase]) -> bool:
	var plugin_name := plugin.get_plugin_name()
	match state.get(plugin_name, 0):
		2: return true   # already processed
		1:               # currently on the stack — cycle
			push_error("[PluginManager] Dependency cycle detected at '%s'" % plugin_name)
			return false

	state[plugin_name] = 1
	for dep_name: String in plugin.get_dependencies():
		var dep: PluginBase = _registry.get(dep_name)
		if dep and not _visit(dep, state, result):
			return false
	state[plugin_name] = 2
	result.append(plugin)
	return true
