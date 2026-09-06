class_name PersonSlot
extends RefCounted

## Lightweight data container for one active person.
## No scene tree presence — PeoplePlugin owns the MultiMesh and updates it each frame.

const WALK_SPEED := 1.5
const ROT_SPEED  := 12.0
const BOB_FREQ   := 9.0
const BOB_HEIGHT := 0.035

enum VisualState {
	AT_HOME, AT_DESTINATION, WALKING_TO_STOP, WAITING_FOR_CAR, IN_CAR,
	WALKING_FROM_STOP, WALKING_ROUTE, BLOCKED, UNHOUSED,
}

const STATE_NAMES := {
	VisualState.AT_HOME: "at_home", VisualState.AT_DESTINATION: "at_destination",
	VisualState.WALKING_TO_STOP: "walking_to_stop", VisualState.WAITING_FOR_CAR: "waiting_for_car",
	VisualState.IN_CAR: "in_car", VisualState.WALKING_FROM_STOP: "walking_from_stop",
	VisualState.WALKING_ROUTE: "walking_route", VisualState.BLOCKED: "blocked",
	VisualState.UNHOUSED: "unhoused",
}

var slot_index:   int       = -1
var current_tile: Vector3i  = Vector3i.ZERO
var position:     Vector3   = Vector3.ZERO
var display_position: Vector3 = Vector3.ZERO
var visible:      bool      = true
var resident_id: int = -1
var resident_seed: int = 0
var home_anchor: Variant = null
var current_place: Variant = null
var intent_revision: int = 0
var journey_revision: int = 0
var state: int = VisualState.AT_HOME
var mode: String = "none"
var purpose: String = "home"
var destination_anchor: Variant = null
var blocked_reason: String = ""
var intent: Dictionary = {}
var journey_plan: Dictionary = {}
var journey_id: int = -1
var departure_offset: float = 0.0
var car_retry_remaining: float = 0.0
var plan_key: String = ""
var diagnostic_faults: Array[String] = []
var spacing_active: bool = false
var spacing_order: int = -1
var spacing_lateral_slot: float = 0.0
var spacing_limited_progress: float = 0.0

var _waypoints:      Array[Vector3]  = []
var _waypoint_tiles: Array[Vector3i] = []
var _bob_time:       float           = 0.0
var _facing:         Basis           = Basis.IDENTITY
