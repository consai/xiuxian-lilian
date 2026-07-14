class_name WeituoState
extends RefCounted

const REQUIRED_FIELDS := ["active", "completed_once", "completed_count", "board"]


static func default_state() -> Dictionary:
	return {
		"active": {},
		"completed_once": [],
		"completed_count": {},
		"board": {"refresh_day": 1, "offer_ids": []},
	}


static func validate(raw: Variant) -> bool:
	if not raw is Dictionary:
		return _fail("invalid_type", "weituo", "expected=Dictionary actual=%s" % type_string(typeof(raw)))
	var state := raw as Dictionary
	for field in REQUIRED_FIELDS:
		if not state.has(field):
			return _fail("missing_field", field)
	if not _validate_active(state["active"]):
		return false
	if not _validate_id_array(state["completed_once"], "completed_once"):
		return false
	if not _validate_completed_count(state["completed_count"]):
		return false
	return _validate_board(state["board"])


static func prepare(raw: Variant) -> Dictionary:
	if not validate(raw):
		return {}
	return (raw as Dictionary).duplicate(true)


static func _validate_active(value: Variant) -> bool:
	if not value is Dictionary:
		return _fail("invalid_type", "active", "expected=Dictionary")
	for instance_id_v in (value as Dictionary).keys():
		if not _non_empty_string(instance_id_v):
			return _fail("invalid_key", "active", "expected=non_empty_string")
		var field := "active.%s" % str(instance_id_v)
		var record_v: Variant = (value as Dictionary)[instance_id_v]
		if not record_v is Dictionary:
			return _fail("invalid_type", field, "expected=Dictionary")
		var record := record_v as Dictionary
		for required in ["weituo_id", "accepted_day", "progress"]:
			if not record.has(required):
				return _fail("missing_field", "%s.%s" % [field, required])
		if not _non_empty_string(record["weituo_id"]):
			return _fail("invalid_value", "%s.weituo_id" % field, "expected=non_empty_string")
		if not _positive_int(record["accepted_day"]):
			return _fail("invalid_value", "%s.accepted_day" % field, "expected=int>=1")
		if not _validate_progress(record["progress"], "%s.progress" % field):
			return false
	return true


static func _validate_progress(value: Variant, field: String) -> bool:
	if not value is Dictionary:
		return _fail("invalid_type", field, "expected=Dictionary")
	var progress := value as Dictionary
	if progress.has("lilian_steps") and not _non_negative_int(progress["lilian_steps"]):
		return _fail("invalid_value", "%s.lilian_steps" % field, "expected=int>=0")
	if progress.has("not_defeated") and typeof(progress["not_defeated"]) != TYPE_BOOL:
		return _fail("invalid_type", "%s.not_defeated" % field, "expected=bool")
	if progress.has("settlement_ids") and not _validate_id_array(
			progress["settlement_ids"], "%s.settlement_ids" % field
	):
		return false
	return true


static func _validate_completed_count(value: Variant) -> bool:
	if not value is Dictionary:
		return _fail("invalid_type", "completed_count", "expected=Dictionary")
	for weituo_id_v in (value as Dictionary).keys():
		if not _non_empty_string(weituo_id_v):
			return _fail("invalid_key", "completed_count", "expected=non_empty_string")
		if not _non_negative_int((value as Dictionary)[weituo_id_v]):
			return _fail(
				"invalid_value",
				"completed_count.%s" % str(weituo_id_v),
				"expected=int>=0"
			)
	return true


static func _validate_board(value: Variant) -> bool:
	if not value is Dictionary:
		return _fail("invalid_type", "board", "expected=Dictionary")
	var board := value as Dictionary
	for field in ["refresh_day", "offer_ids"]:
		if not board.has(field):
			return _fail("missing_field", "board.%s" % field)
	if not _positive_int(board["refresh_day"]):
		return _fail("invalid_value", "board.refresh_day", "expected=int>=1")
	return _validate_id_array(board["offer_ids"], "board.offer_ids")


static func _validate_id_array(value: Variant, field: String) -> bool:
	if not value is Array:
		return _fail("invalid_type", field, "expected=Array")
	var seen := {}
	for index in (value as Array).size():
		var entry: Variant = (value as Array)[index]
		if not _non_empty_string(entry):
			return _fail("invalid_value", "%s[%d]" % [field, index], "expected=non_empty_string")
		if seen.has(str(entry)):
			return _fail("duplicate_value", "%s[%d]" % [field, index], "value=%s" % str(entry))
		seen[str(entry)] = true
	return true


static func _non_empty_string(value: Variant) -> bool:
	return value is String and str(value).strip_edges() != ""


static func _positive_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= 1


static func _non_negative_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= 0


static func _fail(code: String, field: String, detail: String = "") -> bool:
	var message := "[weituo_state:%s] field=%s" % [code, field]
	if detail != "":
		message += " " + detail
	push_error(message)
	return false
