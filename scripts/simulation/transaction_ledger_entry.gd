extends RefCounted
class_name TransactionLedgerEntry

const DISPOSITION_COMMITTED := &"committed"
const DISPOSITION_REJECTED := &"rejected"
const DISPOSITION_SUPERSEDED := &"superseded"
const DISPOSITION_COMBINED := &"combined"
const DISPOSITIONS := [DISPOSITION_COMMITTED, DISPOSITION_REJECTED, DISPOSITION_SUPERSEDED, DISPOSITION_COMBINED]

const REASON_OK := &"ok"
const REASON_DUPLICATE_CONTRIBUTOR := &"duplicate_contributor"
const REASON_DUPLICATE_INTENT := &"duplicate_intent"
const REASON_UNKNOWN_DOMAIN := &"unknown_domain"
const REASON_UNKNOWN_OPERATION := &"unknown_operation"
const REASON_INVALID_PAYLOAD := &"invalid_payload"
const REASON_STALE_STATE_VERSION := &"stale_state_version"
const REASON_UNDECLARED_CONFLICT := &"undeclared_conflict"
const REASON_COLLECTION_SIDE_EFFECT := &"collection_side_effect"
const REASON_REENTRANT_TRANSACTION := &"reentrant_transaction"
const REASON_REDUCER_FAILURE := &"reducer_failure"
const REASON_COMMIT_PRECONDITION_FAILED := &"commit_precondition_failed"
const REASON_CODES := [REASON_OK, REASON_DUPLICATE_CONTRIBUTOR, REASON_DUPLICATE_INTENT,
	REASON_UNKNOWN_DOMAIN, REASON_UNKNOWN_OPERATION, REASON_INVALID_PAYLOAD,
	REASON_STALE_STATE_VERSION, REASON_UNDECLARED_CONFLICT, REASON_COLLECTION_SIDE_EFFECT,
	REASON_REENTRANT_TRANSACTION, REASON_REDUCER_FAILURE, REASON_COMMIT_PRECONDITION_FAILED]

static func is_disposition(value: StringName) -> bool: return value in DISPOSITIONS
static func is_reason_code(value: StringName) -> bool: return value in REASON_CODES

static func from_intent(transaction_id: String, sequence: int, intent: Variant,
		disposition: StringName, reason_code: StringName, pre_version: int,
		post_version: int, related: Array = []) -> Dictionary:
	return {"transaction_id":transaction_id,"sequence":sequence,"intent_id":intent.intent_id,
		"contributor_id":String(intent.contributor_id),"entity_key":intent.entity_key,
		"target_domain":String(intent.target_domain),"operation":String(intent.operation),
		"disposition":String(disposition),"reason_code":String(reason_code),
		"related_intent_ids":related.duplicate(),"pre_state_version":pre_version,
		"post_state_version":post_version}
