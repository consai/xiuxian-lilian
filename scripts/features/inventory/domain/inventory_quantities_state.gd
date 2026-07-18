class_name InventoryQuantitiesState
extends RefCounted

const FIELDS := ["inventory", "storage"]


static func default_state() -> Dictionary:
	return {"inventory": {}, "storage": {}}


static func prepare(candidate: Variant) -> Dictionary:
	var errors := collect_errors(candidate)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		return _result(false, {}, errors[0])
	return _result(true, (candidate as Dictionary).duplicate(true), "")


static func collect_errors(candidate: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not candidate is Dictionary:
		errors.append(_error("invalid_root_type", "quantities"))
		return errors
	var state := candidate as Dictionary
	for key_v in state.keys():
		if str(key_v) not in FIELDS:
			errors.append(_error("unknown_field", str(key_v)))
	for key in FIELDS:
		if not state.has(key):
			errors.append(_error("missing_field", key))
	if not errors.is_empty():
		return errors
	for field in FIELDS:
		var values_v: Variant = state[field]
		if not values_v is Dictionary:
			errors.append(_error("invalid_dictionary", field))
			continue
		for item_id_v in (values_v as Dictionary).keys():
			if not item_id_v is String or str(item_id_v).strip_edges() == "":
				errors.append(_error("invalid_item_id", field))
				continue
			var count: Variant = (values_v as Dictionary)[item_id_v]
			if not count is int or int(count) < 0:
				errors.append(_error("invalid_non_negative_integer", "%s.%s" % [field, item_id_v]))
	return errors


static func _error(code: String, field: String) -> String:
	return "[inventory_quantities_state:%s] field=%s" % [code, field]


static func _result(ok: bool, value: Dictionary, error: String) -> Dictionary:
	return {"ok": ok, "value": value.duplicate(true), "error": error}
