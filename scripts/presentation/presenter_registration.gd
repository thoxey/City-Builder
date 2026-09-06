extends RefCounted
class_name PresenterRegistration

const Domains := preload("res://scripts/presentation/invalidation_domains.gd")

enum State { CLEAN, DIRTY_HIDDEN, QUEUED, PRESENTING }

var presenter_id: StringName
var domains: Array[StringName]
var is_visible: Callable
var present: Callable
var dirty_domains: Dictionary = {}
var target_version := 0
var last_presented_version := -1
var state := State.CLEAN

static func create(p_id: StringName, p_domains: Array, p_visible: Callable, p_present: Callable) -> Variant:
	var value = (load("res://scripts/presentation/presenter_registration.gd") as GDScript).new()
	value.presenter_id = p_id
	value.domains = Domains.canonicalize(p_domains)
	value.is_visible = p_visible
	value.present = p_present
	return value

func is_valid() -> bool:
	return not String(presenter_id).is_empty() and not domains.is_empty() and is_visible.is_valid() and present.is_valid()

func invalidate(changed_domains: Array, version: int) -> bool:
	var relevant := false
	for domain in changed_domains:
		if domain in domains:
			dirty_domains[String(domain)] = true
			relevant = true
	if not relevant: return false
	target_version = maxi(target_version, version)
	state = State.QUEUED if bool(is_visible.call()) else State.DIRTY_HIDDEN
	return true

func queue_if_visible() -> bool:
	if state == State.DIRTY_HIDDEN and bool(is_visible.call()):
		state = State.QUEUED
		return true
	return state == State.QUEUED

func begin_presenting() -> Array[StringName]:
	state = State.PRESENTING
	return Domains.canonicalize(dirty_domains.keys())

func finish_presenting(version: int, invalidated_during_flush: bool = false) -> void:
	last_presented_version = version
	if invalidated_during_flush:
		state = State.QUEUED
	else:
		dirty_domains.clear()
		state = State.CLEAN
