extends PluginBase

## Palette — the authoritative build-menu data model.
##
## Collapses the raw catalog into cyclable entries:
##   - Structures sharing a pool_id (e.g. residential_t1 pool of small_a + small_d)
##     merge into one entry whose random pick is rolled at placement time.
##   - Structures without a pool_id (pub, nature_patch, …) stand alone.
##   - Road variants without an explicit pool_id are hidden (the auto-tiler
##     sources them internally; only the canonical "road" entry is user-facing).
##
## Affordability is re-evaluated every tick / on cash_changed / demand_changed
## / structure_placed. Unaffordable entries drop out of the visible list;
## if the current selection becomes unaffordable it snaps to the next that is.
##
## Builder queries three things:
##   current_structure_index() — what model to show in the cursor preview
##   pick_structure_index_for_build() — random pick from the current pool
##   select_next() / select_previous() — Q/E cycling among affordable entries

func get_plugin_name() -> String: return "Palette"
func get_dependencies() -> Array[String]: return ["BuildingCatalog", "Demand", "Economy", "UniqueRegistry", "RoadNetwork"]

var _catalog: PluginBase
var _demand:  PluginBase
var _economy: PluginBase
var _uniques: PluginBase
var _road_network: PluginBase

func inject(deps: Dictionary) -> void:
	_catalog = deps.get("BuildingCatalog")
	_demand  = deps.get("Demand")
	_economy = deps.get("Economy")
	_uniques = deps.get("UniqueRegistry")
	_road_network = deps.get("RoadNetwork")

# ── State ─────────────────────────────────────────────────────────────────────

var _all_entries: Array[PaletteEntry] = []   # every entry, stable order
var _affordable_ids: Array[String] = []      # ids currently shown
var _selected_id: String = ""                # "" when nothing affordable
var _menu_revision: int = 0
var _last_projection_fingerprint: String = ""

# Display-name overrides for pools (pools have no single authoritative source).
const POOL_DISPLAY_NAMES := {
	"residential_t1": "House",
	"residential_t2": "Tower Block",
	"commercial_t1":  "Shop",
	"commercial_t2":  "Supermarket",
	"industrial_t1":  "Workshop",
	"industrial_t2":  "City Hall",
	"grass":          "Grass",
	"pavement":       "Pavement",
	"road":           "Road",
}

# Category → sort bucket. Lower = earlier in the list.
const CATEGORY_ORDER := {
	"road":        0,
	"nature":      1,
	"generic":     2,
	"unique":      3,
}

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	_build_entries()
	_refresh()

	GameEvents.cash_changed.connect(func(_a, _d): _refresh())
	GameEvents.demand_unserved_changed.connect(func(_bid, _v): _refresh())
	GameEvents.structure_placed.connect(func(_p, _i, _o): _refresh())
	GameEvents.structure_demolished.connect(func(_p): _refresh())
	GameEvents.map_loaded.connect(func(_m): _refresh())
	GameEvents.unique_unlocked.connect(func(_bid): _refresh())
	GameEvents.unique_placed.connect(func(_bid): _refresh())
	GameEvents.unique_removed.connect(func(_bid): _refresh())

# ── Entry construction ────────────────────────────────────────────────────────

func _build_entries() -> void:
	_all_entries.clear()
	var structures: Array[Structure] = _catalog.get_all()
	var summaries: Array = _catalog.get_summary()
	var by_pool: Dictionary = {}  # pool_id -> PaletteEntry

	for i in structures.size():
		var s: Structure = structures[i]
		var summary: Dictionary = summaries[i]
		var pool_id: String = s.pool_id
		var category: String = summary.get("category", "")

		# Non-pooled road variants are auto-tiler support tiles — hidden.
		if pool_id.is_empty() and s.find_metadata(RoadMetadata) != null:
			continue

		if not pool_id.is_empty():
			var entry: PaletteEntry = by_pool.get(pool_id)
			if entry == null:
				entry = PaletteEntry.new()
				entry.id = pool_id
				entry.display_name = POOL_DISPLAY_NAMES.get(pool_id, pool_id)
				entry.sort_key = _sort_key_for(category, pool_id, i)
				var pool_ui: Dictionary = _catalog.get_pool_ui_metadata(pool_id) if _catalog.has_method("get_pool_ui_metadata") else summary
				_apply_ui_metadata(entry, pool_ui)
				by_pool[pool_id] = entry
				_all_entries.append(entry)
			entry.structure_indices.append(i)
		else:
			var solo := PaletteEntry.new()
			solo.id = summary.get("building_id", "entry_%d" % i)
			solo.display_name = summary.get("display_name", solo.id)
			solo.structure_indices = [i]
			solo.sort_key = _sort_key_for(category, solo.id, i)
			_apply_ui_metadata(solo, summary)
			_all_entries.append(solo)

	_all_entries.sort_custom(func(a, b):
		if a.ui_group != b.ui_group:
			return _group_order(a.ui_group) < _group_order(b.ui_group)
		if a.ui_order != b.ui_order:
			return a.ui_order < b.ui_order
		return a.id < b.id)

	print("[Palette] built: entries=%d" % _all_entries.size())
	for e in _all_entries:
		print("[Palette] entry: id=%s members=%d" % [e.id, e.structure_indices.size()])

## Stable lexicographic sort key. Category bucket first, then the id itself.
static func _sort_key_for(category: String, id: String, tiebreaker: int) -> String:
	var bucket: int = CATEGORY_ORDER.get(category, 99)
	return "%d_%s_%05d" % [bucket, id, tiebreaker]

static func _group_order(group_id: String) -> int:
	return ["roads", "homes", "commerce", "industry", "nature", "civic", "landmarks"].find(group_id)

static func _apply_ui_metadata(entry: PaletteEntry, data: Dictionary) -> void:
	entry.ui_group = String(data.get("ui_group", "landmarks"))
	entry.ui_order = int(data.get("ui_order", 1000))
	entry.ui_icon = String(data.get("ui_icon", "missing-artwork"))

# ── Affordability + selection ─────────────────────────────────────────────────

func _is_affordable(entry: PaletteEntry) -> bool:
	# An entry is affordable if ANY of its members is affordable — pools should
	# still show up even if one variant is temporarily unbuyable (they share
	# cost by construction today, but keep this permissive for the future).
	var summaries: Array = _catalog.get_summary()
	for idx: int in entry.structure_indices:
		var s: Structure = _catalog.get_all()[idx]
		var bid: String = summaries[idx].get("building_id", "")
		var cash_ok: bool = true
		var demand_ok: bool = true
		var unique_ok: bool = true
		if _economy and _economy.has_method("can_afford_cash"):
			cash_ok = _economy.can_afford_cash(s)
		if _demand and _demand.has_method("can_afford"):
			demand_ok = _demand.can_afford(s)
		# Uniques must be unlocked (threshold + prereqs met) AND not already
		# placed. Non-uniques fall through untouched.
		if _uniques and _uniques.has_method("is_unique") and _uniques.is_unique(bid):
			unique_ok = _uniques.is_unlocked(bid)
		if cash_ok and demand_ok and unique_ok:
			return true
	return false

func _decision_for_structure(idx: int) -> Dictionary:
	if idx < 0 or idx >= _catalog.get_all().size():
		return {"state": "missing_content", "label": "Content is unavailable", "can_select": false}
	var structure: Structure = _catalog.get_all()[idx]
	var summary: Dictionary = _catalog.get_summary()[idx]
	var building_id := String(summary.get("building_id", ""))
	if GameState.map and bool(GameState.map.rooted_town_rules) and _road_network:
		var hall_placed := int(_road_network.get_town_hall_internal_id()) >= 0
		if not hall_placed and building_id != "building_town_hall":
			return {"state": PlaytestActionResult.TOWN_HALL_REQUIRED,
				"label": "Place your free Town Hall first", "can_select": false,
				"reasons": [PlaytestActionResult.TOWN_HALL_REQUIRED]}
		if hall_placed and building_id == "building_town_hall":
			return {"state": PlaytestActionResult.TOWN_HALL_ALREADY_PLACED,
				"label": "Town Hall already placed", "can_select": false,
				"reasons": [PlaytestActionResult.TOWN_HALL_ALREADY_PLACED]}
	if _uniques and _uniques.has_method("is_unique") and _uniques.is_unique(building_id):
		var unlock: Dictionary = _uniques.evaluate_unlock(building_id) if _uniques.has_method("evaluate_unlock") else {}
		if unlock.is_empty() and _uniques.has_method("is_unlocked"):
			unlock = {"placed": _uniques.is_placed(building_id) if _uniques.has_method("is_placed") else false,
				"unlocked": _uniques.is_unlocked(building_id), "missing_prerequisites": []}
		if not bool(unlock.get("selectable", unlock.get("unlocked", true))):
			var reason := String(unlock.get("primary_reason", ""))
			var label := _label_for_unique_gate(unlock)
			return {"state": reason, "label": label, "can_select": false, "reasons": unlock.get("reasons", []).duplicate(), "gate": unlock.duplicate(true)}
	var cash: Dictionary = _economy.quote_cash(structure) if _economy and _economy.has_method("quote_cash") else {
		"ok": _economy.can_afford_cash(structure) if _economy and _economy.has_method("can_afford_cash") else true,
		"cost": int(summary.get("cash_cost", 0)), "have": 0}
	if not bool(cash.get("ok", true)):
		return {"state": "insufficient_cash", "label": "Need £%d more" % maxi(0, int(cash.get("cost", 0)) - int(cash.get("have", 0))), "can_select": false}
	var demand: Dictionary = _demand.quote_placement(structure) if _demand and _demand.has_method("quote_placement") else {
		"ok": _demand.can_afford(structure) if _demand and _demand.has_method("can_afford") else true,
		"bucket_id":"", "reason":"insufficient", "cost":0, "have":0}
	if not bool(demand.get("ok", true)):
		var bucket: String = _demand.bucket_display_name(String(demand.get("bucket_id", ""))) if _demand and _demand.has_method("bucket_display_name") else String(demand.get("bucket_id", "town"))
		if demand.get("reason", "") == "below_threshold":
			return {"state": "insufficient_demand", "label": "Requires %d %s demand" % [int(demand.get("threshold", 0)), bucket], "can_select": false}
		return {"state": "insufficient_demand", "label": "Need %d more %s demand" % [int(ceil(float(demand.get("cost", 0)) - float(demand.get("have", 0)))), bucket], "can_select": false}
	return {"state": "available", "label": "Available", "can_select": true, "reasons": []}

func _label_for_unique_gate(gate: Dictionary) -> String:
	match String(gate.get("primary_reason", "")):
		PlaytestActionResult.UNIQUE_ALREADY_PLACED:
			return "Already built — this story building is unique"
		PlaytestActionResult.WANT_NOT_REVEALED:
			var character: Dictionary = gate.get("character", {}) if gate.get("character") is Dictionary else {}
			return "Talk to %s to reveal this request" % String(character.get("display_name", "the character"))
		PlaytestActionResult.PATRON_NOT_READY:
			var patron: Dictionary = gate.get("patron", {}) if gate.get("patron") is Dictionary else {}
			return "Complete %s's requests first" % String(patron.get("display_name", "the patron"))
		PlaytestActionResult.UNMET_PREREQUISITE:
			return "Requires %s" % _display_names_for_ids(gate.get("missing_prerequisites", []))
		PlaytestActionResult.BELOW_DEMAND_THRESHOLD:
			return "Requires %d %s demand" % [int(gate.get("threshold", 0)), String(gate.get("bucket", "town"))]
	return "Unavailable"

func _display_names_for_ids(ids: Array) -> String:
	var names: Array[String] = []
	for id in ids:
		var summary: Dictionary = _catalog.get_summary_by_id(String(id)) if _catalog.has_method("get_summary_by_id") else {}
		names.append(String(summary.get("display_name", String(id).replace("building_", "").replace("_", " ").capitalize())))
	return ", ".join(names)

func _update_entry_availability(entry: PaletteEntry) -> void:
	if entry.structure_indices.is_empty():
		entry.availability = "no_members"
		entry.availability_label = "No buildable variants are available"
		entry.can_select = false
		return
	var first_rejection := {"state": "missing_content", "label": "Content is unavailable", "can_select": false}
	for idx in entry.structure_indices:
		var decision := _decision_for_structure(idx)
		if decision.can_select:
			entry.availability = "available"
			entry.availability_label = "Available"
			entry.can_select = true
			return
		if first_rejection.state == "missing_content":
			first_rejection = decision
	entry.availability = first_rejection.state
	entry.availability_label = first_rejection.label
	entry.can_select = false

func _refresh() -> void:
	var new_ids: Array[String] = []
	for e in _all_entries:
		_update_entry_availability(e)
		if e.can_select:
			new_ids.append(e.id)

	# Keep selection if still affordable; otherwise snap to a nearby affordable.
	var selection := _selected_id
	if selection.is_empty() or selection not in new_ids:
		selection = _nearest_affordable(selection, new_ids)

	var changed := new_ids != _affordable_ids or selection != _selected_id
	_affordable_ids = new_ids
	_selected_id = selection

	if changed:
		GameEvents.palette_changed.emit(_affordable_ids.duplicate(), _selected_id)
	var fingerprint := JSON.stringify(_projection_payload(false))
	if fingerprint != _last_projection_fingerprint:
		_last_projection_fingerprint = fingerprint
		_menu_revision += 1
		GameEvents.build_menu_model_changed.emit(_menu_revision)

## When the current selection falls off the affordable list, pick the entry
## nearest to its former position — keeps the cursor roughly where the player
## last had it.
func _nearest_affordable(prev_id: String, affordable_ids: Array[String]) -> String:
	if affordable_ids.is_empty():
		return ""
	if prev_id.is_empty():
		return affordable_ids[0]
	var prev_pos := -1
	for i in _all_entries.size():
		if _all_entries[i].id == prev_id:
			prev_pos = i
			break
	if prev_pos < 0:
		return affordable_ids[0]
	# Walk forward then backward from prev_pos looking for an id that's affordable.
	for offset in range(1, _all_entries.size()):
		var fwd := prev_pos + offset
		if fwd < _all_entries.size() and _all_entries[fwd].id in affordable_ids:
			return _all_entries[fwd].id
		var bwd := prev_pos - offset
		if bwd >= 0 and _all_entries[bwd].id in affordable_ids:
			return _all_entries[bwd].id
	return affordable_ids[0]

# ── Public API (Builder) ──────────────────────────────────────────────────────

func current_entry() -> PaletteEntry:
	return _entry_by_id(_selected_id)

## Structure index the cursor preview should display. The palette always shows
## the first member as the stable representative — placement rolls random.
func current_structure_index() -> int:
	var e := current_entry()
	if e == null or e.structure_indices.is_empty():
		return -1
	return e.structure_indices[0]

## Rolls a random member of the current entry's pool for an actual build.
func pick_structure_index_for_build(rng: RandomNumberGenerator = null) -> int:
	var e := current_entry()
	if e == null or e.structure_indices.is_empty():
		return -1
	if rng:
		return e.structure_indices[rng.randi_range(0, e.structure_indices.size() - 1)]
	return e.structure_indices.pick_random()

## Read-only copy used by semantic playtest discovery. PaletteEntry resources
## remain internal so callers cannot alter normal selection state.
func get_entry_records() -> Array:
	var result: Array = []
	for entry: PaletteEntry in _all_entries:
		result.append({
			"id": entry.id,
			"display_name": entry.display_name,
			"structure_indices": entry.structure_indices.duplicate(),
			"decision": _decision_for_structure(entry.structure_indices[0]).duplicate(true) if not entry.structure_indices.is_empty() else {},
		})
	return result

func get_build_menu_model() -> Dictionary:
	var result := _projection_payload(true)
	result["revision"] = _menu_revision
	return result.duplicate(true)

func _projection_payload(include_revision: bool) -> Dictionary:
	var entries_by_id := {}
	var groups: Array = []
	var group_defs := [
		{"id":"roads", "label":"Roads & Paths", "icon_key":"roads-and-paths"},
		{"id":"homes", "label":"Homes", "icon_key":"homes"},
		{"id":"commerce", "label":"Commerce", "icon_key":"commerce"},
		{"id":"industry", "label":"Industry", "icon_key":"industry"},
		{"id":"nature", "label":"Nature", "icon_key":"nature"},
		{"id":"civic", "label":"Leisure & Civic", "icon_key":"leisure-civic"},
		{"id":"landmarks", "label":"Landmarks & Story", "icon_key":"landmarks-story"},
	]
	for def in group_defs:
		var ids: Array[String] = []
		var available_count := 0
		for entry: PaletteEntry in _all_entries:
			if entry.ui_group != def.id:
				continue
			ids.append(entry.id)
			if entry.can_select: available_count += 1
			entries_by_id[entry.id] = _entry_projection(entry)
		if not ids.is_empty():
			groups.append({"id":def.id, "label":def.label, "icon_key":def.icon_key,
				"order":_group_order(def.id), "entry_ids":ids, "available_count":available_count, "total_count":ids.size()})
	var payload := {"groups":groups, "entries_by_id":entries_by_id, "selected_entry_id":_selected_id,
		"empty_state":"No build choices are available" if _all_entries.is_empty() else ""}
	if include_revision: payload["revision"] = _menu_revision
	return payload

func _entry_projection(entry: PaletteEntry) -> Dictionary:
	var costs: Array[int] = []
	var demand_info: Dictionary = {}
	var members: Array[String] = []
	var community_roles: Array[String] = []
	var community_effects: Array = []
	var effect_keys := {}
	for idx in entry.structure_indices:
		var summary: Dictionary = _catalog.get_summary()[idx]
		members.append(String(summary.get("building_id", "")))
		var cost := int(summary.get("cash_cost", 0))
		if _economy and _economy.has_method("get_cash_cost"): cost = _economy.get_cash_cost(_catalog.get_all()[idx])
		if cost not in costs: costs.append(cost)
		if demand_info.is_empty() and _demand and _demand.has_method("quote_placement"):
			demand_info = _demand.quote_placement(_catalog.get_all()[idx]).duplicate(true)
		var role := String(summary.get("community_role", ""))
		if not role.is_empty() and role not in community_roles: community_roles.append(role)
		var profile := _catalog.get_all()[idx].find_metadata(CommunityEffectProfile) as CommunityEffectProfile
		if profile:
			for effect in profile.effects:
				var key := "%s|%s|%s" % [effect.get("effect_id", ""), effect.get("scope", ""), effect.get("radius", "")]
				if effect_keys.has(key): continue
				effect_keys[key] = true
				community_effects.append({
					"effect_id": effect.get("effect_id", ""), "quality": effect.get("quality", ""),
					"scope": effect.get("scope", ""), "amount": effect.get("amount", 0.0),
					"radius": effect.get("radius"), "reason": effect.get("reason", ""),
				})
	costs.sort()
	community_roles.sort()
	community_effects.sort_custom(func(a: Dictionary, b: Dictionary): return String(a["effect_id"]) < String(b["effect_id"]))
	var decision := _decision_for_structure(entry.structure_indices[0])
	return {"id":entry.id, "display_name":entry.display_name, "short_label":entry.display_name,
		"group_id":entry.ui_group, "ui_order":entry.ui_order, "icon_key":entry.ui_icon,
		"is_pool":entry.structure_indices.size() > 1 or (_catalog.get_all()[entry.structure_indices[0]].pool_id != ""),
		"member_building_ids":members, "representative_structure_index":entry.structure_indices[0],
		"cash_cost":costs[0] if costs.size() == 1 else {"min":costs[0], "max":costs[-1]},
		"demand_cost":demand_info, "availability":entry.availability,
		"community_roles": community_roles, "community_effects": community_effects,
		"availability_label":entry.availability_label, "can_select":entry.can_select,
		"decision":decision.duplicate(true), "reasons":decision.get("reasons", []).duplicate()}

func request_select_entry(entry_id: String) -> Dictionary:
	var entry := _entry_by_id(entry_id)
	if entry == null:
		return {"accepted":false, "entry_id":entry_id, "structure_index":-1, "reason":"Unknown build choice"}
	_update_entry_availability(entry)
	if not entry.can_select:
		return {"accepted":false, "entry_id":entry_id, "structure_index":-1, "reason":entry.availability_label}
	_selected_id = entry.id
	_affordable_ids = _affordable_ids if entry.id in _affordable_ids else _affordable_ids + [entry.id]
	GameEvents.palette_changed.emit(_affordable_ids.duplicate(), _selected_id)
	_refresh()
	return {"accepted":true, "entry_id":entry.id, "structure_index":current_structure_index(), "reason":""}

func select_next() -> void:
	_step_selection(1)

func select_previous() -> void:
	_step_selection(-1)

func _step_selection(delta: int) -> void:
	if _affordable_ids.is_empty():
		return
	var current_pos := _affordable_ids.find(_selected_id)
	if current_pos < 0:
		_selected_id = _affordable_ids[0]
	else:
		var next_pos := wrapi(current_pos + delta, 0, _affordable_ids.size())
		_selected_id = _affordable_ids[next_pos]
	GameEvents.palette_changed.emit(_affordable_ids.duplicate(), _selected_id)

func _entry_by_id(id: String) -> PaletteEntry:
	for e in _all_entries:
		if e.id == id:
			return e
	return null

## Compatibility no-op for older unit fixtures; Palette no longer constructs UI.
func _build_ui() -> void:
	pass
