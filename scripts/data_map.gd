extends Resource
class_name DataMap

## Cash surplus — running balance of tax income minus service overhead.
## Spent on decorative (nature) placement; growth buildings stay demand-bank gated.
## Starting grant of 1000 lets the player put down a few decoratives before tax kicks in.
@export var cash: int = 1000

## Fresh live games use the Town Hall-rooted placement rules. Legacy automated
## scenarios explicitly disable this while their fixtures are migrated.
@export var rooted_town_rules: bool = true

@export var structures: Array[DataStructure]

## Character questline progress. Map character_id → CharState int.
## Serialises with the save. Missing keys implicitly = NOT_ARRIVED.
@export var character_states: Dictionary = {}

## Patron questline progress. Map patron_id → PatronState int.
## Serialises with the save. Missing keys implicitly = LOCKED.
@export var patron_states: Dictionary = {}

## Grid cells the player is allowed to build on. Authority is the
## BuildableArea plugin — the map field just persists the live set so a
## landmark-expansion carries across save/load. Empty array = use starter
## plot (BuildableArea seeds it lazily).
@export var allowed_cells: Array[Vector2i] = []

## Event-system narrative flags. Key = flag name (String), value = bool.
## Set by dialogue-option `set_flag` effects and read by the `flag.<name>`
## DSL token. Persists with the save so narrative state survives reload.
@export var flags: Dictionary = {}

## How many times each event_id has fired (life-of-save). Read by the
## `count.<event_id> >= N` DSL token. Bumped by EventSystem on dispatch.
@export var event_counts: Dictionary = {}

## Accrued demand totals are authoritative progression input and must survive a
## cold save/load. Fulfilled demand is derived again from placed structures.
@export var demand_totals: Dictionary = {}

## Dialogue event IDs dispatched but not yet semantically resolved. Keeping
## IDs (rather than presentation records) lets EventSystem rebuild from the
## authored event definition after load without incrementing event_counts.
@export var pending_dialogue_event_ids: Array[String] = []

## Set-like receipt map keyed by patron_id. A receipt is written even when a
## donation overlaps existing land so completion reconciliation is idempotent.
@export var patron_donations_applied: Dictionary = {}

## Quest-tracker sidebar collapsed state. Persists across saves so the
## player's preferred layout sticks. Default visible.
@export var dashboard_collapsed: bool = false

## Presentation-only Community UI preferences. These values never participate
## in simulation snapshots, migration, or deterministic hashes. Defaults keep
## pre-Community-UI saves backward compatible.
@export var community_selected_tab: String = "community"
@export var community_section: String = "overview"
@export var community_overlay_mode: String = "off"

## Community simulation persistence. Records stay JSON-safe so snapshots and
## save migrations use the same representation.
@export var community_schema_version: int = 0
@export var community_generation_version: int = 1
@export var community_residents: Array = []
@export var community_next_resident_id: int = 1
@export var community_rng_seed: int = 1
@export var community_rng_state: int = 0
@export var community_migration_day: int = -1
@export var community_migration_counters: Dictionary = {"arrivals": 0, "departures": 0, "rejections": 0}
@export var community_programmes: Dictionary = {}
