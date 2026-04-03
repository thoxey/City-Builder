extends Node
class_name PluginBase

## Base class for all city builder plugins.
##
## Lifecycle (managed by PluginManager):
##   1. get_plugin_name()   — called to register the plugin in the DI container
##   2. get_dependencies()  — called to resolve load order and build the dep map
##   3. inject(deps)        — called with resolved dependencies before tree entry
##   4. _plugin_ready()     — called once GameState refs are fully populated
##
## Never override _ready(). PluginManager drives the entire lifecycle.

func get_plugin_name() -> String:
	return ""

func get_dependencies() -> Array[String]:
	return []

func inject(_deps: Dictionary) -> void:
	pass

func _plugin_ready() -> void:
	pass
