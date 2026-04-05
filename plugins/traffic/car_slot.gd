class_name CarSlot
extends RefCounted

## Lightweight data container for one active car journey.
## No scene tree presence — CarManager owns the MultiMesh and drives this each frame.

enum CarType { CIVILIAN = 0, POLICE = 1, AMBULANCE = 2 }

var journey_id:  int   = -1
var car_type:    int   = CarType.CIVILIAN
var route:       Array[Vector3i] = []
var route_index: int   = 0
var loop:        bool  = false
var speed:       float = 3.0
var slot_index:  int   = -1             # index into this type's MultiMesh

# ── World state ───────────────────────────────────────────────────────────────

var position:     Vector3  = Vector3.ZERO
var current_tile: Vector3i = Vector3i.ZERO
var travel_dir:   Vector2i = Vector2i.ZERO   # direction toward the next waypoint

var _waypoints:      Array[Vector3]  = []
var _waypoint_tiles: Array[Vector3i] = []

# ── Rotation — segment progress interpolation ─────────────────────────────────
# As the car crosses a tile, _seg_progress goes 0 → 1.
# _write_transform does slerp(_seg_start_basis, _seg_end_basis, _seg_progress).

var _seg_start_basis: Basis = Basis.IDENTITY
var _seg_end_basis:   Basis = Basis.IDENTITY
var _seg_progress:    float = 0.0
var _seg_total_dist:  float = 1.0

# ── Traffic state ─────────────────────────────────────────────────────────────

var waiting:       bool  = false
var wait_time:     float = 0.0
var reroute_count: int   = 0   # consecutive reroutes; reset when car moves a tile
var lane_slot:     int   = 0   # 0 = front of lane, 1 = bumper behind
