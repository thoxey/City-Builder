extends StructureMetadata
class_name BuildingProfile

## Semantic profile attached to a building structure.
## Consumed by building-type plugins (Residential, Workplace, etc.) to register
## the appropriate CityStatSource or CityStatSink with CityStats.

## Semantic category: "residential", "workplace", "commercial", etc.
@export var category: String = ""

## Peak occupancy / headcount capacity.
@export var capacity: int = 10

## Hour (0–24) when this building becomes active (starts supplying or demanding).
@export var active_start: float = 8.0

## Hour (0–24) when this building goes inactive.
## If active_end < active_start the window wraps midnight (e.g. 22–6).
@export var active_end: float = 18.0
