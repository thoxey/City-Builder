extends RefCounted
class_name PaletteEntry

## A single cyclable slot in the build palette. Wraps either a standalone
## structure or a pool of visually-distinct variants sharing a pool_id.
## The palette plugin owns the list; Builder asks for the current entry's
## representative preview and the random pick at placement time.

## Stable identifier — pool_id when pooled, building_id when standalone.
var id: String
var display_name: String
## Catalog indices (= MeshLibrary item ids) that belong to this entry.
var structure_indices: Array[int] = []
## String key used to sort the palette into a stable, human-readable order.
var sort_key: String = ""
