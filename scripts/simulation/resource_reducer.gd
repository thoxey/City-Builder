extends RefCounted
class_name ResourceReducer

const ALLOWED_OPERATIONS := [&"supply", &"demand"]

static func reduce(intents: Array, _context: Variant) -> Dictionary:
	var supply := {}
	var demand := {}
	var requests: Array = []
	for intent in intents:
		var payload: Dictionary = intent.get_payload()
		var type_id := String(payload.get("type_id", ""))
		var amount := int(payload.get("amount", -1))
		if type_id.is_empty() or amount < 0:
			return {"ok": false, "reason_code": "invalid_payload"}
		match String(intent.operation):
			"supply": supply[type_id] = int(supply.get(type_id, 0)) + amount
			"demand":
				demand[type_id] = int(demand.get(type_id, 0)) + amount
				requests.append({"type_id": type_id, "amount": amount, "entity_key": intent.entity_key})
			_: return {"ok": false, "reason_code": "unknown_operation"}
	var remaining := supply.duplicate()
	var fulfillment := {}
	for request in requests:
		var type_id: String = request.type_id
		var amount: int = request.amount
		var share := mini(amount, int(remaining.get(type_id, 0)))
		remaining[type_id] = int(remaining.get(type_id, 0)) - share
		fulfillment[request.entity_key] = share
	var satisfaction := {}
	for type_id in demand:
		var fulfilled := int(supply.get(type_id, 0)) - int(remaining.get(type_id, 0))
		satisfaction[type_id] = float(fulfilled) / float(demand[type_id]) if int(demand[type_id]) > 0 else 1.0
	return {"ok": true, "plan": {"supply": supply, "demand": demand,
		"fulfillment": fulfillment, "satisfaction": satisfaction}, "domains": [&"resources"]}
