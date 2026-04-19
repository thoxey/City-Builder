extends PluginBase

## QuestDebug — dev-only button row for fast-forwarding the M3 questline.
##
## Sits under the HUD top bar. Not part of the real UX; purely a test harness
## so you don't have to build 13 uniques per patron to prove the loop works.
## Safe to leave enabled during polish — each button is additive, none wipe
## player progress beyond "Reset".
##
## Buttons per patron:
##   Satisfy — marks all three characters SATISFIED, flipping the patron to
##             LANDMARK_AVAILABLE. Player must still build the landmark to
##             trigger the donation.
##   Complete — additionally fires the landmark placement, walking the patron
##              to COMPLETED and firing the land donation.
##
## Reset — sends every character back to NOT_ARRIVED and every patron to
## LOCKED. Does NOT touch the buildable area or placed buildings.

var _characters: PluginBase
var _patrons:    PluginBase

func get_plugin_name() -> String: return "QuestDebug"
func get_dependencies() -> Array[String]: return ["CharacterSystem", "PatronSystem"]

func inject(deps: Dictionary) -> void:
	_characters = deps.get("CharacterSystem")
	_patrons    = deps.get("PatronSystem")

func _plugin_ready() -> void:
	_build_ui()

# ── UI ────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left   = -330
	panel.offset_right  = 330
	panel.offset_top    = 54   # sits just under the HUD top bar
	panel.offset_bottom = 86
	canvas.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	panel.add_child(hbox)

	var header := Label.new()
	header.text = "M3 Debug:"
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(header)

	for pid in ["aristocrat", "businessman", "farmer"]:
		hbox.add_child(VSeparator.new())
		hbox.add_child(_make_label(pid.capitalize()))
		hbox.add_child(_make_button("Satisfy", _make_satisfy_handler(pid)))
		hbox.add_child(_make_button("Complete", _make_complete_handler(pid)))

	hbox.add_child(VSeparator.new())
	hbox.add_child(_make_button("Reset", _on_reset))

func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # keep Tab for nameplate toggle
	b.pressed.connect(cb)
	return b

# ── Handlers ──────────────────────────────────────────────────────────────────

## Closure factory: bind the patron_id to a specific action so one button
## per (patron, action) pair stays self-contained.
func _make_satisfy_handler(pid: String) -> Callable:
	return func() -> void: _satisfy_patron(pid)

func _make_complete_handler(pid: String) -> Callable:
	return func() -> void: _complete_patron(pid)

func _satisfy_patron(pid: String) -> void:
	if _patrons == null or _characters == null:
		return
	var def: Dictionary = _patrons.get_def(pid)
	if def.is_empty():
		push_warning("[QuestDebug] unknown patron: %s" % pid)
		return
	for cid in def.get("character_ids", []):
		_force_satisfy(String(cid))
	print("[QuestDebug] satisfy: patron=%s" % pid)

func _complete_patron(pid: String) -> void:
	_satisfy_patron(pid)
	if _patrons == null:
		return
	var def: Dictionary = _patrons.get_def(pid)
	var landmark: String = String(def.get("landmark_building_id", ""))
	if landmark.is_empty():
		return
	# Emit unique_placed — PatronSystem listens for landmark_building_id match
	# and flips to COMPLETED, which cascades to BuildableArea.expand via the
	# patron_landmark_completed signal. No actual mesh goes on the grid.
	GameEvents.unique_placed.emit(landmark)
	print("[QuestDebug] complete: patron=%s landmark=%s" % [pid, landmark])

## Drive a character through the minimal path to SATISFIED, respecting the
## plugin's own transitions so the signals fire in order. Idempotent — if
## already past SATISFIED, does nothing.
func _force_satisfy(cid: String) -> void:
	if _characters == null:
		return
	var state: int = _characters.get_state(cid)
	# 3 = SATISFIED; 4 = CONTRIBUTES_TO_LANDMARK
	if state >= 3:
		return
	# Mirror the real transitions by writing the states directly — the
	# backing dict is on GameState.map, and we still fire the right signals
	# so downstream (PatronSystem, Palette, etc.) stays consistent.
	if state < 1:
		_characters._set_state(cid, 1)  # ARRIVED
		GameEvents.character_arrived.emit(cid)
	if state < 2:
		_characters._set_state(cid, 2)  # WANT_REVEALED
		GameEvents.character_want_revealed.emit(cid)
	_characters._set_state(cid, 3)      # SATISFIED
	GameEvents.character_satisfied.emit(cid)

func _on_reset() -> void:
	if _characters:
		for cid in _characters.all_character_ids():
			_characters._set_state(cid, 0)  # NOT_ARRIVED
	if _patrons:
		for pid in _patrons.all_patron_ids():
			GameState.map.patron_states[pid] = 0  # LOCKED
	print("[QuestDebug] reset: all quest state cleared")
