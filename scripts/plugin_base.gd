extends Node
class_name PluginBase

## Base class for all city builder plugins.
## Override _plugin_ready() — it fires once GameState references are populated.
## Never override _ready() unless you need pre-state setup; call super._ready() if you do.

func _ready() -> void:
	GameState.register_ready_callback(_plugin_ready)

## Override this in your plugin. GameState.gridmap, .structures, .map are safe to access here.
func _plugin_ready() -> void:
	pass
