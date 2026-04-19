extends PluginBase

## Palette — the build-menu data model + UI panel.
##
## Collapses the raw catalog into cyclable entries:
##   - Structures sharing a pool_id (e.g. residential_t1 pool of small_a + small_d)
##     merge into one entry whose random pick is rolled at placement time.
##   - Structures without a pool_id (police, pub, nature_patch, …) stand alone.
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
func get_dependencies() -> Array[String]: return ["BuildingCatalog", "Demand", "Economy"]

var _catalog: PluginBase
var _demand:  PluginBase
var _economy: PluginBase

func inject(deps: Dictionary) -> void:
	_catalog = deps.get("BuildingCatalog")
	_demand  = deps.get("Demand")
	_economy = deps.get("Economy")

# ── State ─────────────────────────────────────────────────────────────────────

var _all_entries: Array[PaletteEntry] = []   # every entry, stable order
var _affordable_ids: Array[String] = []      # ids currently shown
var _selected_id: String = ""                # "" when nothing affordable

# UI refs
var _list_vbox: VBoxContainer
var _row_labels: Dictionary = {}             # entry_id -> Label

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
	_build_ui()
	_refresh()

	GameEvents.cash_changed.connect(func(_a, _d): _refresh())
	GameEvents.demand_changed.connect(func(_bid, _v): _refresh())
	GameEvents.structure_placed.connect(func(_p, _i, _o): _refresh())
	GameEvents.structure_demolished.connect(func(_p): _refresh())
	GameEvents.map_loaded.connect(func(_m): _refresh())

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
				by_pool[pool_id] = entry
				_all_entries.append(entry)
			entry.structure_indices.append(i)
		else:
			var solo := PaletteEntry.new()
			solo.id = summary.get("building_id", "entry_%d" % i)
			solo.display_name = summary.get("display_name", solo.id)
			solo.structure_indices = [i]
			solo.sort_key = _sort_key_for(category, solo.id, i)
			_all_entries.append(solo)

	_all_entries.sort_custom(func(a, b): return a.sort_key < b.sort_key)

	print("[Palette] built: entries=%d" % _all_entries.size())
	for e in _all_entries:
		print("[Palette] entry: id=%s members=%d" % [e.id, e.structure_indices.size()])

## Stable lexicographic sort key. Category bucket first, then the id itself.
static func _sort_key_for(category: String, id: String, tiebreaker: int) -> String:
	var bucket: int = CATEGORY_ORDER.get(category, 99)
	return "%d_%s_%05d" % [bucket, id, tiebreaker]

# ── Affordability + selection ─────────────────────────────────────────────────

func _is_affordable(entry: PaletteEntry) -> bool:
	# An entry is affordable if ANY of its members is affordable — pools should
	# still show up even if one variant is temporarily unbuyable (they share
	# cost by construction today, but keep this permissive for the future).
	for idx: int in entry.structure_indices:
		var s: Structure = _catalog.get_all()[idx]
		var cash_ok: bool = true
		var demand_ok: bool = true
		if _economy and _economy.has_method("can_afford_cash"):
			cash_ok = _economy.can_afford_cash(s)
		if _demand and _demand.has_method("can_afford"):
			demand_ok = _demand.can_afford(s)
		if cash_ok and demand_ok:
			return true
	return false

func _refresh() -> void:
	var new_ids: Array[String] = []
	for e in _all_entries:
		if _is_affordable(e):
			new_ids.append(e.id)

	# Keep selection if still affordable; otherwise snap to a nearby affordable.
	var selection := _selected_id
	if selection.is_empty() or selection not in new_ids:
		selection = _nearest_affordable(selection, new_ids)

	var changed := new_ids != _affordable_ids or selection != _selected_id
	_affordable_ids = new_ids
	_selected_id = selection

	if changed:
		_rebuild_ui_rows()
		GameEvents.palette_changed.emit(_affordable_ids.duplicate(), _selected_id)

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
func pick_structure_index_for_build() -> int:
	var e := current_entry()
	if e == null or e.structure_indices.is_empty():
		return -1
	return e.structure_indices.pick_random()

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
	_rebuild_ui_rows()
	GameEvents.palette_changed.emit(_affordable_ids.duplicate(), _selected_id)

func _entry_by_id(id: String) -> PaletteEntry:
	for e in _all_entries:
		if e.id == id:
			return e
	return null

# ── UI panel ──────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left   = 10
	panel.offset_right  = 220
	panel.offset_top    = -260
	panel.offset_bottom = -10
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "Build (Q/E)"
	header.add_theme_constant_override("outline_size", 2)
	vbox.add_child(header)

	_list_vbox = VBoxContainer.new()
	_list_vbox.add_theme_constant_override("separation", 0)
	vbox.add_child(_list_vbox)

func _rebuild_ui_rows() -> void:
	if _list_vbox == null:
		return
	for child in _list_vbox.get_children():
		_list_vbox.remove_child(child)
		child.queue_free()
	_row_labels.clear()

	for id in _affordable_ids:
		var e := _entry_by_id(id)
		if e == null:
			continue
		var lbl := Label.new()
		var prefix := "> " if id == _selected_id else "  "
		var suffix := "" if e.structure_indices.size() <= 1 else "  (×%d)" % e.structure_indices.size()
		lbl.text = "%s%s%s" % [prefix, e.display_name, suffix]
		if id == _selected_id:
			lbl.modulate = Color(1.0, 0.95, 0.4)
		_list_vbox.add_child(lbl)
		_row_labels[id] = lbl
