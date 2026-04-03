extends PluginBase

## Day/night cycle plugin.
## Animates the existing Sun DirectionalLight3D and drives sky/ambient colours
## through a WorldEnvironment that overrides the camera's static environment.
## Preserves all post-process settings (SSAO, glow, tonemapping) from the
## original main-environment.tres.
##
## UI: bottom-right slider to manually scrub time of day.
## Click "Auto" to resume the automatic cycle.

const CYCLE_DURATION := 120.0  # real seconds per full in-game day
const START_TIME     := 0.28   # start just after dawn

## Colour keyframes — [time, sky_top, sky_horizon, sun_color, sun_energy]
## time: 0.0 = midnight · 0.25 = sunrise · 0.5 = noon · 0.75 = sunset
const SKY_KEYS: Array = [
	[0.00, Color(0.010, 0.015, 0.060), Color(0.020, 0.030, 0.100), Color(0.40, 0.50, 1.00), 0.00],  # midnight
	[0.18, Color(0.080, 0.025, 0.180), Color(0.120, 0.050, 0.240), Color(0.55, 0.40, 0.90), 0.00],  # pre-dawn purple
	[0.25, Color(0.280, 0.060, 0.320), Color(0.960, 0.250, 0.380), Color(1.00, 0.38, 0.15), 0.45],  # sunrise: hot pink sky, coral sun
	[0.33, Color(0.080, 0.280, 0.680), Color(0.640, 0.790, 1.000), Color(1.00, 0.88, 0.55), 0.90],  # morning: crisp blue + gold
	[0.50, Color(0.040, 0.360, 0.780), Color(0.340, 0.680, 0.960), Color(1.00, 0.98, 0.90), 1.30],  # noon: vivid azure
	[0.65, Color(0.060, 0.310, 0.660), Color(0.980, 0.760, 0.400), Color(1.00, 0.92, 0.65), 1.10],  # afternoon: golden haze horizon
	[0.73, Color(0.220, 0.060, 0.280), Color(1.000, 0.420, 0.060), Color(1.00, 0.52, 0.08), 0.65],  # golden hour: purple + vivid orange
	[0.78, Color(0.160, 0.030, 0.180), Color(0.860, 0.150, 0.040), Color(1.00, 0.28, 0.05), 0.25],  # sunset: blood orange
	[0.84, Color(0.060, 0.015, 0.140), Color(0.340, 0.050, 0.200), Color(0.60, 0.40, 0.80), 0.00],  # dusk: deep magenta
	[0.93, Color(0.015, 0.015, 0.065), Color(0.030, 0.035, 0.110), Color(0.40, 0.50, 1.00), 0.00],  # night
	[1.00, Color(0.010, 0.015, 0.060), Color(0.020, 0.030, 0.100), Color(0.40, 0.50, 1.00), 0.00],  # midnight (loop)
]

## Fired once per in-game hour (every CYCLE_DURATION/24 real seconds).
## hour: 0–23 integer cast to float.
signal hour_changed(hour: float)

var _time: float = START_TIME
var _manual: bool = false
var _last_hour: int = -1

## Returns the current normalised time (0.0 = midnight, 0.5 = noon).
func get_time() -> float:
	return _time

var _sun: DirectionalLight3D
var _world_env: WorldEnvironment
var _sky_mat: ProceduralSkyMaterial
var _env: Environment

# UI
var _slider: HSlider
var _time_label: Label
var _auto_btn: Button
var _updating_slider: bool = false  # prevents slider signal re-entrancy

func get_plugin_name() -> String: return "DayNight"
func get_dependencies() -> Array[String]: return []

# ── Setup ─────────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	_setup_lighting()
	_setup_ui()
	_apply(_time)

func _setup_lighting() -> void:
	_sun = get_tree().get_root().find_child("Sun", true, false) as DirectionalLight3D
	if not _sun:
		push_warning("[DayNight] No 'Sun' node found — creating one")
		_sun = DirectionalLight3D.new()
		_sun.shadow_enabled = true
		add_child(_sun)

	var base_env := load("res://scenes/main-environment.tres") as Environment
	_env = base_env.duplicate() as Environment

	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_curve = 0.05
	_sky_mat.ground_curve = 0.02

	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_env.sky = sky
	_env.background_mode = Environment.BG_SKY
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_sky_contribution = 0.6

	_world_env = WorldEnvironment.new()
	_world_env.environment = _env
	add_child(_world_env)

func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left   = -230
	panel.offset_top    = -72
	panel.offset_right  = -10
	panel.offset_bottom = -10
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Row: label + auto button
	var hbox := HBoxContainer.new()
	vbox.add_child(hbox)

	_time_label = Label.new()
	_time_label.text = "06:43"
	_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_time_label)

	_auto_btn = Button.new()
	_auto_btn.text = "Auto"
	_auto_btn.toggle_mode = true
	_auto_btn.button_pressed = true
	_auto_btn.toggled.connect(_on_auto_toggled)
	hbox.add_child(_auto_btn)

	# Slider
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.0005
	_slider.custom_minimum_size = Vector2(210, 20)
	_slider.value_changed.connect(_on_slider_changed)
	vbox.add_child(_slider)

# ── Process ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _manual:
		_time = fmod(_time + delta / CYCLE_DURATION, 1.0)

	_apply(_time)

	# Fire hour_changed when crossing an in-game hour boundary
	var current_hour: int = int(_time * 24.0)
	if current_hour != _last_hour:
		_last_hour = current_hour
		hour_changed.emit(float(current_hour))

	# Sync slider without triggering _on_slider_changed
	_updating_slider = true
	_slider.value = _time
	_updating_slider = false
	_time_label.text = _time_to_clock(_time)

# ── Lighting ──────────────────────────────────────────────────────────────────

func _apply(t: float) -> void:
	var sky_top    := Color()
	var sky_horiz  := Color()
	var sun_color  := Color()
	var sun_energy := 0.0

	for i in SKY_KEYS.size() - 1:
		var k0: Array = SKY_KEYS[i]
		var k1: Array = SKY_KEYS[i + 1]
		if t >= float(k0[0]) and t <= float(k1[0]):
			var span: float = float(k1[0]) - float(k0[0])
			var f: float    = smoothstep(0.0, 1.0, (t - float(k0[0])) / span)
			sky_top    = (k0[1] as Color).lerp(k1[1] as Color, f)
			sky_horiz  = (k0[2] as Color).lerp(k1[2] as Color, f)
			sun_color  = (k0[3] as Color).lerp(k1[3] as Color, f)
			sun_energy = lerpf(float(k0[4]), float(k1[4]), f)
			break

	# Sun rotation — full circle, pointing down at noon
	_sun.rotation = Vector3((t - 0.25) * TAU, deg_to_rad(-35.0), 0.0)
	_sun.light_energy = sun_energy
	_sun.light_color  = sun_color

	# Sky
	_sky_mat.sky_top_color        = sky_top
	_sky_mat.sky_horizon_color    = sky_horiz
	_sky_mat.sky_energy_multiplier = lerpf(0.08, 1.6, clampf(sun_energy / 1.3, 0.0, 1.0))
	_sky_mat.ground_bottom_color   = sky_top.darkened(0.88)
	_sky_mat.ground_horizon_color  = sky_horiz.darkened(0.45)

	# Ambient — dims right down at night
	_env.ambient_light_sky_contribution = lerpf(0.04, 0.65, clampf(sun_energy / 1.3, 0.0, 1.0))

# ── UI callbacks ──────────────────────────────────────────────────────────────

func _on_slider_changed(value: float) -> void:
	if _updating_slider:
		return
	_manual = true
	_auto_btn.button_pressed = false
	_time = value

func _on_auto_toggled(pressed: bool) -> void:
	_manual = not pressed

# ── Helpers ───────────────────────────────────────────────────────────────────

func _time_to_clock(t: float) -> String:
	var total_minutes := int(t * 1440.0) % 1440
	var h := total_minutes / 60
	var m := total_minutes % 60
	return "%02d:%02d" % [h, m]
