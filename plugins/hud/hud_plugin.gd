extends PluginBase

## City stats HUD — top-right panel.
##
## Displays: overall satisfaction %, and per-resource scores (safety, health)
## plus budget balance (surplus or deficit per in-game hour).
##
## Reads from CityStats.stats_ticked and GameEvents.satisfaction_changed.
## Self-contained: creates all UI nodes at runtime (no scene edits needed).

func get_plugin_name() -> String: return "HUD"
func get_dependencies() -> Array[String]: return ["CityStats"]

var _city_stats: PluginBase

func inject(deps: Dictionary) -> void:
	_city_stats = deps.get("CityStats")

# ── UI refs ───────────────────────────────────────────────────────────────────

var _satisfaction_label: Label
var _safety_label:       Label
var _health_label:       Label
var _budget_label:       Label

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	_build_ui()
	GameEvents.satisfaction_changed.connect(_on_satisfaction)
	_city_stats.stats_ticked.connect(_on_stats_ticked)

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left   = -420
	panel.offset_right  = -10
	panel.offset_top    = 10
	panel.offset_bottom = 46
	canvas.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	_satisfaction_label = _make_label("★ ---%")
	_safety_label       = _make_label("Safety: ---%")
	_health_label       = _make_label("Health: ---%")
	_budget_label       = _make_label("Budget: ---/hr")

	hbox.add_child(_satisfaction_label)
	hbox.add_child(_make_sep())
	hbox.add_child(_safety_label)
	hbox.add_child(_health_label)
	hbox.add_child(_make_sep())
	hbox.add_child(_budget_label)

func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

func _make_sep() -> VSeparator:
	return VSeparator.new()

# ── Update ────────────────────────────────────────────────────────────────────

func _on_satisfaction(score: float) -> void:
	_satisfaction_label.text = "★ %d%%" % int(score * 100.0)
	# Colour the star by score
	if score >= 0.75:
		_satisfaction_label.modulate = Color(0.2, 1.0, 0.3)
	elif score >= 0.4:
		_satisfaction_label.modulate = Color(1.0, 0.85, 0.1)
	else:
		_satisfaction_label.modulate = Color(1.0, 0.25, 0.2)

func _on_stats_ticked(supply: Dictionary, demand: Dictionary, satisfaction: Dictionary) -> void:
	_safety_label.text = "Safety: %d%%" % int(satisfaction.get("safety", 1.0) * 100.0)
	_health_label.text = "Health: %d%%" % int(satisfaction.get("health", 1.0) * 100.0)

	var budget_balance: int = supply.get("budget", 0) - demand.get("budget", 0)
	if budget_balance >= 0:
		_budget_label.text     = "Budget: +%d/hr" % budget_balance
		_budget_label.modulate = Color(0.2, 1.0, 0.3)
	else:
		_budget_label.text     = "Budget: %d/hr" % budget_balance
		_budget_label.modulate = Color(1.0, 0.25, 0.2)
