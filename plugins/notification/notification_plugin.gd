extends PluginBase

## NotificationPlugin — M4 stub renderer.
##
## Log-only. The real toast UI lands in M7 polish; for now this plugin just
## confirms the event system routed a `notification` payload correctly.

var _event_system: PluginBase

func get_plugin_name() -> String:
	return "Notification"

func get_dependencies() -> Array[String]:
	return ["EventSystem"]

func inject(deps: Dictionary) -> void:
	_event_system = deps.get("EventSystem")

func _plugin_ready() -> void:
	if _event_system:
		_event_system.event_resolved.connect(_on_event_resolved)

func _on_event_resolved(record: Dictionary) -> void:
	if String(record.get("event_type", "")) != "notification":
		return
	var p: Dictionary = record.get("payload", {})
	print("[Notification] render: event_id=%s text=\"%s\" duration=%.1f" % [
		String(record.get("event_id", "")),
		String(p.get("text", "")),
		float(p.get("duration", 0.0)),
	])
