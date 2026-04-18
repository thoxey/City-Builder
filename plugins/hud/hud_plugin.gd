extends PluginBase

## City stats HUD — top-centre panel.
##
## Displays: overall satisfaction %, per-resource scores (safety, health),
## budget balance (surplus or deficit per in-game hour), industrial output
## (raw production from filled workplaces), and the four demand buckets
## (desirability, housing, industrial, commercial).
##
## Reads from CityStats.stats_ticked, GameEvents.satisfaction_changed, and
## GameEvents.demand_changed. Self-contained: creates all UI nodes at runtime.

func get_plugin_name() -> String: return "HUD"
func get_dependencies() -> Array[String]: return ["CityStats", "Demand"]

var _city_stats: PluginBase
var _demand: PluginBase

func inject(deps: Dictionary) -> void:
	_city_stats = deps.get("CityStats")
	_demand = deps.get("Demand")

# ── UI refs ───────────────────────────────────────────────────────────────────

var _satisfaction_label: Label
var _safety_label:       Label
var _health_label:       Label
var _budget_label:       Label
var _output_label:       Label
var _demand_labels: Dictionary = {}  # bucket_type_id -> Label

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	_build_ui()
	GameEvents.satisfaction_changed.connect(_on_satisfaction)
	GameEvents.demand_changed.connect(_on_demand_changed)
	_city_stats.stats_ticked.connect(_on_stats_ticked)

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left   = -315
	panel.offset_right  = 315
	panel.offset_top    = 10
	panel.offset_bottom = 46
	canvas.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	_satisfaction_label = _make_label("★ ---%")
	_safety_label       = _make_label("Safety: ---%")
	_health_label       = _make_label("Health: ---%")
	_budget_label       = _make_label("Budget: ---/hr")
	_output_label       = _make_label("Output: 0/hr")

	hbox.add_child(_satisfaction_label)
	hbox.add_child(_make_sep())
	hbox.add_child(_safety_label)
	hbox.add_child(_health_label)
	hbox.add_child(_make_sep())
	hbox.add_child(_budget_label)
	hbox.add_child(_output_label)
	hbox.add_child(_make_sep())

	_demand_labels["desirability"]      = _make_label("Des: --")
	_demand_labels["housing_demand"]    = _make_label("Hous: --")
	_demand_labels["industrial_demand"] = _make_label("Ind: --")
	_demand_labels["commercial_demand"] = _make_label("Com: --")
	hbox.add_child(_demand_labels["desirability"])
	hbox.add_child(_demand_labels["housing_demand"])
	hbox.add_child(_demand_labels["industrial_demand"])
	hbox.add_child(_demand_labels["commercial_demand"])

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

func _on_demand_changed(bucket_type_id: String, value: float) -> void:
	var lbl: Label = _demand_labels.get(bucket_type_id)
	if lbl == null:
		return
	if bucket_type_id == "desirability":
		lbl.text = "Des: %d%%" % int(value * 100.0)
		return
	# Growth buckets: show running value + the affordable-unit bank count.
	var short: String = {
		"housing_demand":    "Hous",
		"industrial_demand": "Ind",
		"commercial_demand": "Com",
	}.get(bucket_type_id, bucket_type_id)
	var banked := 0
	if _demand:
		var bucket: DemandBucket = _demand.buckets.get(bucket_type_id)
		if bucket:
			banked = bucket.get_bank_count()
	lbl.text = "%s: %d (%d)" % [short, int(value), banked]

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

	_output_label.text = "Output: %d/hr" % int(supply.get("industrial_output", 0))
