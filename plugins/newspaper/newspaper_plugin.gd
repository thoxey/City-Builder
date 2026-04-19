extends PluginBase

## NewspaperPlugin — M4 stub renderer.
##
## Listens to EventSystem.event_resolved; logs `newspaper`-type events so
## authored chain effects (dialogue → `fire_event` → newspaper) are visible
## during M4 without the full newspaper feed UI. Real rendering is M7 polish.

var _event_system: PluginBase

func get_plugin_name() -> String:
	return "Newspaper"

func get_dependencies() -> Array[String]:
	return ["EventSystem"]

func inject(deps: Dictionary) -> void:
	_event_system = deps.get("EventSystem")

func _plugin_ready() -> void:
	if _event_system:
		_event_system.event_resolved.connect(_on_event_resolved)

func _on_event_resolved(record: Dictionary) -> void:
	if String(record.get("event_type", "")) != "newspaper":
		return
	var p: Dictionary = record.get("payload", {})
	print("[Newspaper] render: event_id=%s kicker=\"%s\" headline=\"%s\"" % [
		String(record.get("event_id", "")),
		String(p.get("kicker", "")),
		String(p.get("headline", "")),
	])
