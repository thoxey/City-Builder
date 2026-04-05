class_name PersonSlot
extends RefCounted

## Lightweight data container for one active person.
## No scene tree presence — PeoplePlugin owns the MultiMesh and updates it each frame.

const WALK_SPEED := 1.5
const ROT_SPEED  := 12.0
const BOB_FREQ   := 9.0
const BOB_HEIGHT := 0.035

var slot_index:   int       = -1
var current_tile: Vector3i  = Vector3i.ZERO
var position:     Vector3   = Vector3.ZERO
var visible:      bool      = true

var _waypoints:      Array[Vector3]  = []
var _waypoint_tiles: Array[Vector3i] = []
var _bob_time:       float           = 0.0
var _facing:         Basis           = Basis.IDENTITY
