extends PluginBase

## BuildableArea — authority for which grid cells the player may build on.
##
## The mask is kept separate from the GridMap: the engine grid is infinite
## but this plugin narrows what Builder is allowed to touch. Starts seeded
## with a small starter plot and grows when PatronSystem emits
## `patron_landmark_completed`. The live mask persists in DataMap so
## expansions carry across save/load.

## Default starter plot (8×8 centred on origin). Tuneable for early-game
## ergonomics — extend if the player should have more room to breathe before
## the first donation.
const STARTER_RECT := Rect2i(-4, -4, 8, 8)

var _patrons: PluginBase

## Vector2i -> true. Source of truth during gameplay; mirrored to
## GameState.map.allowed_cells on every mutation so saves round-trip.
var _allowed: Dictionary = {}

func get_plugin_name() -> String:
	return "BuildableArea"

func get_dependencies() -> Array[String]:
	return ["PatronSystem"]

func inject(deps: Dictionary) -> void:
	_patrons = deps.get("PatronSystem")

func _plugin_ready() -> void:
	_load_or_seed()
	GameEvents.patron_landmark_completed.connect(_on_patron_landmark_completed)
	GameEvents.map_loaded.connect(_on_map_loaded)
	print("[BuildableArea] seeded: cells=%d shape=rect rect=(%d,%d,%d,%d)" % [
		_allowed.size(),
		STARTER_RECT.position.x, STARTER_RECT.position.y,
		STARTER_RECT.size.x, STARTER_RECT.size.y
	])

## Pull the allowed set from DataMap if present, else seed from STARTER_RECT.
## Called on boot + every map_loaded so expansions in prior sessions survive.
func _load_or_seed() -> void:
	_allowed.clear()
	if GameState != null and GameState.map != null:
		var saved: Array = GameState.map.allowed_cells
		if not saved.is_empty():
			for c in saved:
				_allowed[c] = true
			return
	# Fresh game or empty save — seed starter.
	for x in range(STARTER_RECT.position.x, STARTER_RECT.position.x + STARTER_RECT.size.x):
		for y in range(STARTER_RECT.position.y, STARTER_RECT.position.y + STARTER_RECT.size.y):
			_allowed[Vector2i(x, y)] = true
	_sync_to_map()

## Copy _allowed (Dictionary) into GameState.map.allowed_cells (Array) so the
## save path sees the current set.
func _sync_to_map() -> void:
	if GameState == null or GameState.map == null:
		return
	var arr: Array[Vector2i] = []
	for c in _allowed.keys():
		arr.append(c)
	GameState.map.allowed_cells = arr

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_patron_landmark_completed(patron_id: String) -> void:
	if _patrons == null:
		return
	var def: Dictionary = _patrons.get_def(patron_id)
	if def.is_empty():
		return
	var area: Dictionary = def.get("donation_area", {})
	if area.is_empty():
		push_warning("[BuildableArea] donation_area missing for patron %s" % patron_id)
		return
	var cells: Array[Vector2i] = LandDonationPayload.cells_from_dict(area)
	_expand(cells, patron_id)

func _on_map_loaded(_m: DataMap) -> void:
	_load_or_seed()

# ── Mutation ──────────────────────────────────────────────────────────────────

func _expand(cells: Array[Vector2i], trigger: String) -> void:
	var added: Array[Vector2i] = []
	for c in cells:
		if not _allowed.has(c):
			_allowed[c] = true
			added.append(c)
	if added.is_empty():
		return
	_sync_to_map()
	print("[BuildableArea] expand: trigger=%s new_cells=%d total_cells=%d" % [
		trigger, added.size(), _allowed.size()
	])
	GameEvents.buildable_area_expanded.emit(added)

## Direct-expand entry point for tests and external callers (e.g. a debug
## tool that wants to grant a specific rect). Wraps _expand so the signal
## still fires.
func expand_rect(rect: Rect2i, trigger: String = "external") -> void:
	var cells: Array[Vector2i] = []
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			cells.append(Vector2i(x, y))
	_expand(cells, trigger)

# ── Queries ───────────────────────────────────────────────────────────────────

func is_allowed(cell: Vector2i) -> bool:
	return _allowed.has(cell)

func allowed_count() -> int:
	return _allowed.size()

func allowed_cells() -> Array:
	return _allowed.keys()
