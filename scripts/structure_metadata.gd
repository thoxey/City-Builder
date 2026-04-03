extends Resource
class_name StructureMetadata

## Base class for per-structure metadata. Extend this in your plugin.
##
## Example:
##   class_name TrafficMetadata extends StructureMetadata
##   @export var capacity: int = 1
##
## Then query: for m in structure.metadata: if m is TrafficMetadata: ...
