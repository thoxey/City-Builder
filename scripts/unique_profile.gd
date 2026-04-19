extends StructureMetadata
class_name UniqueProfile

## Metadata attached to unique (one-of-a-kind) buildings.
## Read by UniqueRegistry and PatronSystem to drive questline progression.

## Which demand bucket gates this building's availability.
## "residential" | "commercial" | "industrial"
@export var bucket: String = ""

## 1..3 for chain buildings; 0 for wants and landmarks.
@export var tier: int = 0

## Patron that owns this building's chain. "aristocrat" | "businessman" | "farmer"
@export var patron_id: String = ""

## Character this building is associated with. "" for landmarks.
@export var character_id: String = ""

## "chain" | "want" | "landmark"
@export var chain_role: String = "chain"

## Demand value that must be present in `bucket` before this building unlocks.
@export var prerequisite_threshold: int = 0

## Building IDs that must already be placed before this one unlocks.
## Chain T2 requires its T1; wants require the patron's T3; landmarks require all three wants.
@export var prerequisite_ids: PackedStringArray = PackedStringArray()

## Desirability bonus applied while this building exists on the map.
## Most uniques leave this at 0; businessman's civic tier buildings set it nonzero.
@export var desirability_boost: float = 0.0
