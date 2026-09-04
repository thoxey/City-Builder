extends PluginBase

## City stats HUD — top-centre panel.
##
## Displays: overall satisfaction %, budget balance (surplus or deficit per
## in-game hour), industrial output (raw production from filled workplaces),
## and the four demand buckets (desirability, housing, industrial, commercial).
##
## Reads from CityStats.stats_ticked, GameEvents.satisfaction_changed, and
## the three demand_*_changed signals. Self-contained: creates all UI nodes at runtime.
##
## Per spendable bucket: "fulfilled / total (banked)" so the player sees both
## current placed capacity and the ever-asked-for ceiling. Desirability stays
## as a single percent — non-monotonic, no fulfilled axis.

func get_plugin_name() -> String: return "HUD"
func get_dependencies() -> Array[String]: return ["CityStats", "Demand", "Community"]

var _city_stats: PluginBase
var _demand: PluginBase
var _community: PluginBase

func inject(deps: Dictionary) -> void:
	_city_stats = deps.get("CityStats")
	_demand = deps.get("Demand")
	_community = deps.get("Community")

# ── UI refs ───────────────────────────────────────────────────────────────────

var _satisfaction_label:    Label
var _budget_label:          Label
var _output_label:          Label
var _cash_label:            Label
var _attractiveness_label:  Label
var _demand_labels: Dictionary = {}  # bucket_type_id -> Label
var _community_population_label: Label
var _community_happiness_label: Label
var _community_delta_label: Label
var _last_population := -1
var _community_delta_generation := 0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	_build_ui()
	GameEvents.satisfaction_changed.connect(_on_satisfaction)
	# All three bucket signals route into the same refresh — the label shows
	# fulfilled/total (banked), so any of the three moving requires a redraw.
	GameEvents.demand_unserved_changed.connect(_on_bucket_changed)
	GameEvents.demand_total_changed.connect(_on_bucket_changed)
	GameEvents.demand_fulfilled_changed.connect(_on_bucket_changed)
	GameEvents.cash_changed.connect(_on_cash_changed)
	GameEvents.city_attractiveness_changed.connect(_on_attractiveness_changed)
	_city_stats.stats_ticked.connect(_on_stats_ticked)
	GameEvents.community_population_changed.connect(_on_community_population)
	GameEvents.community_qualities_changed.connect(func(_q): _refresh_community_hud())
	GameEvents.map_loaded.connect(func(_m): _last_population = -1; _refresh_community_hud())
	# Seed the cash label with whatever is on the map right now — the Economy
	# plugin emits cash_changed in its own _plugin_ready, but topo order may put
	# Economy *after* HUD (HUD only deps CityStats + Demand), so we'd miss that
	# first emit. Pull straight from GameState.map for the initial value.
	if GameState.map:
		_on_cash_changed(GameState.map.cash, 0)
	_refresh_community_hud()

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
	_budget_label       = _make_label("Budget: ---/hr")
	_output_label       = _make_label("Output: 0/hr")
	_cash_label         = _make_label("$0")

	hbox.add_child(_satisfaction_label)
	hbox.add_child(_make_sep())
	hbox.add_child(_cash_label)
	hbox.add_child(_make_sep())
	hbox.add_child(_budget_label)
	hbox.add_child(_output_label)
	hbox.add_child(_make_sep())

	_attractiveness_label              = _make_label("Attr: 0")
	_demand_labels["residential"]     = _make_label("Res: --")
	_demand_labels["industrial"]      = _make_label("Ind: --")
	_demand_labels["commercial"]      = _make_label("Com: --")
	hbox.add_child(_attractiveness_label)
	hbox.add_child(_demand_labels["residential"])
	hbox.add_child(_demand_labels["industrial"])
	hbox.add_child(_demand_labels["commercial"])

	# Community is deliberately a separate, compact strip so composite
	# happiness cannot be confused with the legacy Satisfaction score.
	var community_panel := PanelContainer.new()
	community_panel.name = "CommunityHUD"
	community_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	community_panel.offset_left = -210
	community_panel.offset_right = 210
	# The developer control strip occupies y=50..84 at the reference size.
	# Keep Community's compact strip below it so both remain legible.
	community_panel.offset_top = 90
	community_panel.offset_bottom = 124
	canvas.add_child(community_panel)
	var community_row := HBoxContainer.new()
	community_row.add_theme_constant_override("separation", 8)
	community_panel.add_child(community_row)
	community_row.add_child(CommunityUIFactory.icon("population", 22, "Population and residential capacity"))
	_community_population_label = _make_label("People 0/0")
	community_row.add_child(_community_population_label)
	community_row.add_child(CommunityUIFactory.icon("composite-happiness", 22, "Average composite Community happiness"))
	_community_happiness_label = _make_label("Happiness 50.0")
	community_row.add_child(_community_happiness_label)
	_community_delta_label = _make_label("")
	community_row.add_child(_community_delta_label)
	var open_button := Button.new()
	open_button.name = "OpenCommunity"
	open_button.text = "Community"
	open_button.icon = load("res://sprites/community_icons/game/community-tab.png")
	open_button.expand_icon = true
	open_button.focus_mode = Control.FOCUS_ALL
	open_button.tooltip_text = "Open Community insights"
	open_button.pressed.connect(func(): GameEvents.community_ui_requested.emit())
	community_row.add_child(open_button)

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

func _on_cash_changed(amount: int, _delta: int) -> void:
	_cash_label.text = "$%d" % amount

func _on_attractiveness_changed(value: int) -> void:
	if _attractiveness_label:
		_attractiveness_label.text = "Attr: %d" % value

func _on_bucket_changed(bucket_type_id: String, _value: float) -> void:
	var lbl: Label = _demand_labels.get(bucket_type_id)
	if lbl == null or _demand == null:
		return
	var bucket: DemandBucket = _demand.buckets.get(bucket_type_id)
	if bucket == null:
		return
	var short: String = {
		"residential": "Res",
		"industrial":  "Ind",
		"commercial":  "Com",
	}.get(bucket_type_id, bucket_type_id)
	# fulfilled/total (banked) — tells the player both what's built and what
	# the town's accumulated need is, plus how many they can place right now.
	lbl.text = "%s: %d/%d (%d)" % [
		short,
		int(bucket.fulfilled),
		int(bucket.total_demand),
		bucket.get_bank_count(),
	]

func _on_stats_ticked(supply: Dictionary, demand: Dictionary, _satisfaction: Dictionary) -> void:
	var budget_balance: int = supply.get("budget", 0) - demand.get("budget", 0)
	if budget_balance >= 0:
		_budget_label.text     = "Budget: +%d/hr" % budget_balance
		_budget_label.modulate = Color(0.2, 1.0, 0.3)
	else:
		_budget_label.text     = "Budget: %d/hr" % budget_balance
		_budget_label.modulate = Color(1.0, 0.25, 0.2)

	_output_label.text = "Output: %d/hr" % int(supply.get("industrial_output", 0))

func _on_community_population(population: int, capacity: int) -> void:
	if _community_population_label:
		_community_population_label.text = "People %d/%d" % [population, capacity]
	if _last_population >= 0 and population != _last_population and _community_delta_label:
		var delta := population - _last_population
		_community_delta_label.text = "%+d" % delta
		_community_delta_label.tooltip_text = "Recent population change"
		_community_delta_generation += 1
		_clear_community_delta_later(_community_delta_generation)
	_last_population = population
	_refresh_community_hud()

func _refresh_community_hud() -> void:
	if _community == null: return
	var snapshot: Dictionary = _community.get_snapshot(true)
	if _community_population_label:
		_community_population_label.text = "People %d/%d" % [int(snapshot.get("population", 0)), int(snapshot.get("capacity", 0))]
	if _community_happiness_label:
		_community_happiness_label.text = "Happiness %.1f" % float(snapshot.get("average_composite_happiness", 50.0))

func _clear_community_delta_later(generation: int) -> void:
	await get_tree().create_timer(4.0).timeout
	if generation == _community_delta_generation and _community_delta_label:
		_community_delta_label.text = ""
