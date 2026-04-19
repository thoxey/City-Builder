extends Resource
class_name DataMap

## Cash surplus — running balance of tax income minus service overhead.
## Spent on decorative (nature) placement; growth buildings stay demand-bank gated.
## Starting grant of 1000 lets the player put down a few decoratives before tax kicks in.
@export var cash: int = 1000

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
