class_name KnowledgeState
extends RefCounted

const FIELD_ORDER := ["level", "xp", "marked", "growth_source"]


static func default_state() -> Dictionary:
	return {}


static func collect_errors(candidate: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not candidate is Dictionary:
		errors.append(_error(
			"invalid_root_type",
			"knowledge",
			"expected=Dictionary actual=%s" % type_string(typeof(candidate))
		))
		return errors

	var entries: Array = []
	for key_v in (candidate as Dictionary).keys():
		entries.append({
			"key": key_v,
			"sort_key": "%s:%s" % [type_string(typeof(key_v)), str(key_v)],
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["sort_key"]) < str(b["sort_key"])
	)
	for entry_v in entries:
		var entry_info := entry_v as Dictionary
		var key_v: Variant = entry_info["key"]
		if not key_v is String or str(key_v).strip_edges() == "":
			errors.append(_error(
				"invalid_key",
				"knowledge.%s" % str(key_v),
				"expected=non_empty_string actual=%s" % type_string(typeof(key_v))
			))
			continue
		var skill_id := str(key_v)
		var row_v: Variant = (candidate as Dictionary)[key_v]
		if not row_v is Dictionary:
			errors.append(_error(
				"invalid_entry_type",
				"knowledge.%s" % skill_id,
				"expected=Dictionary actual=%s" % type_string(typeof(row_v))
			))
			continue
		var row := row_v as Dictionary
		for field in FIELD_ORDER:
			if not row.has(field):
				continue
			var value: Variant = row[field]
			match field:
				"level":
					if typeof(value) != TYPE_INT:
						errors.append(_field_type_error(skill_id, field, "int", value))
					elif int(value) < 0 or int(value) > 5:
						errors.append(_error(
							"out_of_range",
							"knowledge.%s.level" % skill_id,
							"range=0..5 actual=%d" % int(value)
						))
				"xp":
					if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
						errors.append(_field_type_error(skill_id, field, "int_or_float", value))
					elif float(value) < 0.0:
						errors.append(_error(
							"out_of_range",
							"knowledge.%s.xp" % skill_id,
							"range=>=0 actual=%s" % str(value)
						))
				"marked":
					if typeof(value) != TYPE_BOOL:
						errors.append(_field_type_error(skill_id, field, "bool", value))
				"growth_source":
					if not value is String:
						errors.append(_field_type_error(skill_id, field, "String", value))
	return errors


static func prepare(candidate: Variant) -> Dictionary:
	var errors := collect_errors(candidate)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		return _result(false, {}, str(errors[0]))
	return _result(true, (candidate as Dictionary).duplicate(true), "")


static func _field_type_error(
	skill_id: String,
	field: String,
	expected: String,
	value: Variant
) -> String:
	return _error(
		"invalid_field_type",
		"knowledge.%s.%s" % [skill_id, field],
		"expected=%s actual=%s" % [expected, type_string(typeof(value))]
	)


static func _error(code: String, field: String, detail: String = "") -> String:
	var message := "[knowledge_state:%s] field=%s" % [code, field]
	if detail != "":
		message += " " + detail
	return message


static func _result(ok: bool, value: Dictionary, error: String) -> Dictionary:
	return {
		"ok": ok,
		"value": value.duplicate(true),
		"error": error,
	}
