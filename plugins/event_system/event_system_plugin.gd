extends PluginBase

## EventSystem — generalised narrative event bus (Phase 8).
##
## Responsibilities:
##   1. Walk res://data/events/**/*.json at boot; parse each file into an event
##      record; build a dispatch index keyed by trigger signal.
##   2. Listen to every registered trigger signal on GameEvents and dispatch
##      matching events through the envelope-level `enabled_if` gate.
##   3. Emit `event_resolved(record)` for renderers (DialoguePlugin,
##      NewspaperPlugin, NotificationPlugin, ...) to render the payload.
##   4. Apply option-level `effects` when renderers ask — effects can chain
##      into further events via the `fire_event` kind.
##
## The core bus is type-agnostic: new payload types come for free as long as a
## renderer plugin subscribes to `event_resolved` and handles its `event_type`.

const DATA_DIR := "res://data/events"
const CONDITION := preload("res://scripts/event_condition.gd")

## Renderers connect to this — one arg, the full event record dict.
signal event_resolved(record: Dictionary)
## Lightweight telemetry signal; fires after dispatch & enabled_if pass.
signal event_fired(event_id: String)

# event_id -> record dict (parsed JSON + `_path`).
var _events: Dictionary = {}
# trigger signal name -> Array[event_id] (preserves file-walk order)
var _by_trigger: Dictionary = {}

# Narrow whitelist of signals we subscribe to. Extending this list means
# (a) adding a signal on GameEvents, and (b) adding it here. Keys are the
# signal names; values are the arg name for the primary filter (character_id /
# patron_id / building_id / "").
const TRIGGER_SIGNALS := {
	"character_arrived":          "character_id",
	"character_want_revealed":    "character_id",
	"character_satisfied":        "character_id",
	"character_state_changed":    "character_id",
	"patron_landmark_ready":      "patron_id",
	"patron_landmark_completed":  "patron_id",
	"unique_placed":              "building_id",
	"buildable_area_expanded":    "",
}

var _catalog:    PluginBase
var _economy:    PluginBase
var _demand:     PluginBase
var _characters: PluginBase
var _patrons:    PluginBase

func get_plugin_name() -> String:
	return "EventSystem"

func get_dependencies() -> Array[String]:
	# CharacterSystem + PatronSystem are listed so the topo-sort guarantees both
	# finish their _plugin_ready (and any boot-time state transitions) before
	# we reconcile. Loader itself only needs BuildingCatalog.
	return ["BuildingCatalog", "CharacterSystem", "PatronSystem"]

func inject(deps: Dictionary) -> void:
	_catalog    = deps.get("BuildingCatalog")
	_characters = deps.get("CharacterSystem")
	_patrons    = deps.get("PatronSystem")

func _plugin_ready() -> void:
	_economy = PluginManager.get_plugin("Economy")
	_demand  = PluginManager.get_plugin("Demand")

	_load_all(DATA_DIR)
	_connect_triggers()

	var by_type := _summarise_by_type()
	print("[EventSystem] loading: dir=%s" % DATA_DIR)
	print("[EventSystem] loaded: count=%d errors=0" % _events.size())
	print("[EventSystem] indexed: triggers=%d by_type=%s" % [_by_trigger.size(), _by_type_str(by_type)])

	# Boot reconcile: characters and patrons may have entered non-initial states
	# during their own _plugin_ready (fresh boot with seeded demand of 100 puts
	# every character in ARRIVED before we were subscribed). Replay the relevant
	# triggers for any subject whose matching event hasn't yet fired this save.
	# Deferred so renderer plugins (Dialogue / Newspaper / Notification) finish
	# their own _plugin_ready first — the topo sort puts them after us.
	call_deferred("_reconcile_boot_state")

func _reconcile_boot_state() -> void:
	if _characters and _characters.has_method("all_character_ids"):
		for cid in _characters.all_character_ids():
			var s: int = int(_characters.get_state(cid))
			# CharState: 0=NOT_ARRIVED, 1=ARRIVED, 2=WANT_REVEALED, 3=SATISFIED, 4=CONTRIBUTES
			if s >= 1: _maybe_dispatch_once("character_arrived",       {"character_id": cid})
			if s >= 2: _maybe_dispatch_once("character_want_revealed", {"character_id": cid})
			if s >= 3: _maybe_dispatch_once("character_satisfied",     {"character_id": cid})
	if _patrons and _patrons.has_method("all_patron_ids"):
		for pid in _patrons.all_patron_ids():
			var s: int = int(_patrons.get_state(pid))
			# PatronState: 0=LOCKED, 1=LANDMARK_AVAILABLE, 2=COMPLETED
			if s >= 1: _maybe_dispatch_once("patron_landmark_ready",     {"patron_id": pid})
			if s >= 2: _maybe_dispatch_once("patron_landmark_completed", {"patron_id": pid})

## Dispatch matching events for this trigger+filter, but only those that have
## never fired on this save (event_counts == 0). Used for boot reconcile so
## events don't replay every load.
func _maybe_dispatch_once(trigger: String, payload_ctx: Dictionary) -> void:
	var ids: Array = _by_trigger.get(trigger, [])
	for eid in ids:
		var rec: Dictionary = _events.get(eid, {})
		if rec.is_empty():
			continue
		if not _matches_trigger_filter(rec, payload_ctx):
			continue
		var already: int = int(GameState.map.event_counts.get(eid, 0)) if GameState and GameState.map else 0
		if already > 0:
			continue
		var gate := String(rec.get("enabled_if", ""))
		if not gate.is_empty():
			if not CONDITION.evaluate(gate, _build_condition_ctx()):
				print("[EventSystem] suppressed: event_id=%s reason=enabled_if_false expr=\"%s\"" % [eid, gate])
				continue
		print("[EventSystem] reconcile: event_id=%s trigger=%s" % [eid, trigger])
		_deliver(rec)

# ── Loading ───────────────────────────────────────────────────────────────────

func _load_all(root: String) -> void:
	_events.clear()
	_by_trigger.clear()
	_walk_dir(root)
	# Stable order by event_id within each trigger bucket so tests don't flap.
	for key in _by_trigger.keys():
		var arr: Array = _by_trigger[key]
		arr.sort()
		_by_trigger[key] = arr

func _walk_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var path := dir_path.path_join(name)
		if dir.current_is_dir():
			_walk_dir(path)
		elif name.ends_with(".json") and not name.begins_with("_"):
			_parse_one(path)
		name = dir.get_next()
	dir.list_dir_end()

func _parse_one(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("[EventSystem] parse_error: file=%s error=empty_or_unreadable" % path)
		return
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("[EventSystem] parse_error: file=%s error=invalid_json" % path)
		return
	var rec: Dictionary = parsed
	var eid := String(rec.get("event_id", ""))
	if eid.is_empty():
		push_error("[EventSystem] parse_error: file=%s error=missing_event_id" % path)
		return
	if _events.has(eid):
		push_error("[EventSystem] parse_error: file=%s error=duplicate_event_id id=%s" % [path, eid])
		return
	rec["_path"] = path
	_events[eid] = rec
	var trig: Dictionary = rec.get("trigger", {})
	var sig := String(trig.get("event", ""))
	if sig.is_empty():
		push_warning("[EventSystem] no_trigger: event_id=%s file=%s" % [eid, path])
		return
	if not _by_trigger.has(sig):
		_by_trigger[sig] = [] as Array
	_by_trigger[sig].append(eid)

func _summarise_by_type() -> Dictionary:
	var out: Dictionary = {}
	for eid in _events:
		var t := String(_events[eid].get("event_type", "unknown"))
		out[t] = int(out.get(t, 0)) + 1
	return out

static func _by_type_str(d: Dictionary) -> String:
	var parts: Array[String] = []
	var keys: Array = d.keys()
	keys.sort()
	for k in keys:
		parts.append("%s:%d" % [k, d[k]])
	return "{%s}" % ", ".join(parts)

# ── Trigger subscription ──────────────────────────────────────────────────────

func _connect_triggers() -> void:
	if not GameEvents.character_arrived.is_connected(_on_character_arrived):
		GameEvents.character_arrived.connect(_on_character_arrived)
	if not GameEvents.character_want_revealed.is_connected(_on_character_want_revealed):
		GameEvents.character_want_revealed.connect(_on_character_want_revealed)
	if not GameEvents.character_satisfied.is_connected(_on_character_satisfied):
		GameEvents.character_satisfied.connect(_on_character_satisfied)
	if not GameEvents.character_state_changed.is_connected(_on_character_state_changed):
		GameEvents.character_state_changed.connect(_on_character_state_changed)
	if not GameEvents.patron_landmark_ready.is_connected(_on_patron_landmark_ready):
		GameEvents.patron_landmark_ready.connect(_on_patron_landmark_ready)
	if not GameEvents.patron_landmark_completed.is_connected(_on_patron_landmark_completed):
		GameEvents.patron_landmark_completed.connect(_on_patron_landmark_completed)
	if not GameEvents.unique_placed.is_connected(_on_unique_placed):
		GameEvents.unique_placed.connect(_on_unique_placed)
	if not GameEvents.buildable_area_expanded.is_connected(_on_buildable_area_expanded):
		GameEvents.buildable_area_expanded.connect(_on_buildable_area_expanded)

func _on_character_arrived(cid: String) -> void:
	_dispatch("character_arrived", {"character_id": cid})

func _on_character_want_revealed(cid: String) -> void:
	_dispatch("character_want_revealed", {"character_id": cid})

func _on_character_satisfied(cid: String) -> void:
	_dispatch("character_satisfied", {"character_id": cid})

func _on_character_state_changed(cid: String, state: int) -> void:
	_dispatch("character_state_changed", {"character_id": cid, "state": state})

func _on_patron_landmark_ready(pid: String) -> void:
	_dispatch("patron_landmark_ready", {"patron_id": pid})

func _on_patron_landmark_completed(pid: String) -> void:
	_dispatch("patron_landmark_completed", {"patron_id": pid})

func _on_unique_placed(bid: String) -> void:
	_dispatch("unique_placed", {"building_id": bid})

func _on_buildable_area_expanded(cells: Array) -> void:
	_dispatch("buildable_area_expanded", {"cells": cells})

# ── Dispatch ──────────────────────────────────────────────────────────────────

func _dispatch(trigger: String, payload_ctx: Dictionary) -> void:
	print("[EventSystem] trigger: event=%s %s" % [trigger, _kv_string(payload_ctx)])
	var ids: Array = _by_trigger.get(trigger, [])
	for eid in ids:
		var rec: Dictionary = _events.get(eid, {})
		if rec.is_empty():
			continue
		if not _matches_trigger_filter(rec, payload_ctx):
			continue
		var gate := String(rec.get("enabled_if", ""))
		if not gate.is_empty():
			var ok: bool = CONDITION.evaluate(gate, _build_condition_ctx())
			if not ok:
				print("[EventSystem] suppressed: event_id=%s reason=enabled_if_false expr=\"%s\"" % [eid, gate])
				continue
		_deliver(rec)

## Dispatch a specific event directly (used by `fire_event` effects and tests).
func fire(event_id: String) -> void:
	var rec: Dictionary = _events.get(event_id, {})
	if rec.is_empty():
		push_warning("[EventSystem] fire_unknown: event_id=%s" % event_id)
		return
	var gate := String(rec.get("enabled_if", ""))
	if not gate.is_empty():
		if not CONDITION.evaluate(gate, _build_condition_ctx()):
			print("[EventSystem] suppressed: event_id=%s reason=enabled_if_false expr=\"%s\"" % [event_id, gate])
			return
	_deliver(rec)

func _deliver(rec: Dictionary) -> void:
	var eid := String(rec.get("event_id", ""))
	var etype := String(rec.get("event_type", "unknown"))
	print("[EventSystem] dispatch: event_id=%s type=%s" % [eid, etype])
	_bump_count(eid)
	event_fired.emit(eid)
	event_resolved.emit(rec)
	print("[EventSystem] resolved: event_id=%s type=%s" % [eid, etype])

func _matches_trigger_filter(rec: Dictionary, payload_ctx: Dictionary) -> bool:
	var trig: Dictionary = rec.get("trigger", {})
	# Empty-string filter fields in the JSON mean "match anything". Non-empty
	# fields must match the payload exactly on the relevant primary key.
	for key in ["character_id", "patron_id", "building_id"]:
		var want := String(trig.get(key, ""))
		if want.is_empty():
			continue
		var got := String(payload_ctx.get(key, ""))
		if got != want:
			return false
	return true

func _bump_count(event_id: String) -> void:
	if GameState and GameState.map:
		var d: Dictionary = GameState.map.event_counts
		d[event_id] = int(d.get(event_id, 0)) + 1

# ── Effects (called by Dialogue renderer on option click / on_enter) ─────────

## Apply a single effect dict. Returns true if applied, false on unknown kind.
## Kept on EventSystem (not Dialogue) so future renderers can share.
func apply_effect(effect: Dictionary) -> bool:
	var kind := String(effect.get("kind", ""))
	match kind:
		"set_flag":
			var name := String(effect.get("target", ""))
			if name.is_empty():
				return false
			if GameState and GameState.map:
				GameState.map.flags[name] = true
			print("[EventSystem] effect_set_flag: name=%s" % name)
			return true
		"delay_want":
			# M4: logged but not mechanically enforced — CharacterSystem would
			# need a delay-list; tracked in backlog. The flag is still emitted
			# so M7 polish can react.
			var cid := String(effect.get("target", ""))
			var amount := int(effect.get("amount", 0))
			print("[EventSystem] effect_delay_want: target=%s amount=%d" % [cid, amount])
			return true
		"discount_cost":
			var bid := String(effect.get("target", ""))
			var delta := int(effect.get("amount", 0))
			if _catalog and _catalog.has_method("apply_cash_discount"):
				_catalog.apply_cash_discount(bid, delta)
			print("[EventSystem] effect_discount_cost: target=%s amount=%d" % [bid, delta])
			return true
		"fire_event":
			var target_id := String(effect.get("target", ""))
			if target_id.is_empty():
				return false
			print("[EventSystem] cascade: to=%s" % target_id)
			fire(target_id)
			return true
		_:
			push_warning("[EventSystem] unknown_effect: kind=%s" % kind)
			return false

func apply_effects(effects: Array) -> void:
	for e in effects:
		if typeof(e) == TYPE_DICTIONARY:
			apply_effect(e)

# ── Condition context ─────────────────────────────────────────────────────────

func _build_condition_ctx() -> Dictionary:
	var ctx: Dictionary = {
		"cash": 0,
		"flags": {},
		"placed_ids": {},
		"demand": {},
		"character_states": {},
		"event_counts": {},
	}
	if GameState and GameState.map:
		ctx["cash"] = int(GameState.map.cash)
		ctx["flags"] = GameState.map.flags
		ctx["character_states"] = GameState.map.character_states
		ctx["event_counts"] = GameState.map.event_counts
		for reg_id in GameState.building_registry:
			var info: Dictionary = GameState.building_registry[reg_id]
			var idx: int = int(info.get("structure", -1))
			if _catalog:
				var summary: Dictionary = _catalog.get_summary_by_index(idx)
				var bid := String(summary.get("building_id", ""))
				if not bid.is_empty():
					ctx["placed_ids"][bid] = true
	if _demand and _demand.has_method("get_value"):
		for b in ["desirability", "housing_demand", "industrial_demand", "commercial_demand"]:
			ctx["demand"][b] = _demand.get_value(b)
	return ctx

# ── Public accessors ──────────────────────────────────────────────────────────

func get_event(event_id: String) -> Dictionary:
	return _events.get(event_id, {}).duplicate(true)

func all_event_ids() -> Array:
	return _events.keys()

func events_for_trigger(trigger: String) -> Array:
	return (_by_trigger.get(trigger, []) as Array).duplicate()

## Test hook: inject a pre-built events dict (bypasses disk scan).
func set_events_for_test(events: Dictionary) -> void:
	_events = events.duplicate(true)
	_by_trigger.clear()
	for eid in _events:
		var rec: Dictionary = _events[eid]
		var sig := String(rec.get("trigger", {}).get("event", ""))
		if sig.is_empty():
			continue
		if not _by_trigger.has(sig):
			_by_trigger[sig] = [] as Array
		_by_trigger[sig].append(eid)

# ── Helpers ───────────────────────────────────────────────────────────────────

static func _kv_string(d: Dictionary) -> String:
	var parts: Array[String] = []
	var keys: Array = d.keys()
	keys.sort()
	for k in keys:
		parts.append("%s=%s" % [k, d[k]])
	return " ".join(parts)
