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

## Authored player-menu presentation. Pool sidecar metadata takes precedence
## over member metadata when this entry represents a pool.
var ui_group: String = "landmarks"
var ui_order: int = 1000
var ui_icon: String = "missing-artwork"

## Stable, reason-bearing availability projected by Palette. These values are
## presentation state only; selection is always revalidated before acceptance.
var availability: String = "missing_content"
var availability_label: String = "Content is unavailable"
var can_select: bool = false
