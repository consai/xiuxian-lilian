class_name CharacterCreationCatalog
extends RefCounted

const PATHS := {
	"origin": "res://data/exportjson/character_origins.json",
	"root": "res://data/exportjson/character_roots.json",
	"talent": "res://data/exportjson/character_talents.json",
}

static var _choices_by_type: Dictionary = {}


static func has_choice_type(choice_type: String) -> bool:
	return PATHS.has(choice_type.strip_edges().to_lower())


static func query_choices(choice_type: String) -> Dictionary:
	var type_id := choice_type.strip_edges().to_lower()
	if not PATHS.has(type_id):
		return {
			"ok": false,
			"error_code": "unknown_character_choice_type",
			"message": "未知角色选项类型：%s" % choice_type,
			"value": [],
		}
	if _choices_by_type.has(type_id):
		return {
			"ok": true,
			"value": (_choices_by_type[type_id] as Array).duplicate(true),
		}

	var path := str(PATHS[type_id])
	var rows := JsonReader.read_object(path)
	var errors := validate_table(rows, type_id, path)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		return {
			"ok": false,
			"error_code": "invalid_character_creation_config",
			"message": str(errors[0]),
			"value": [],
		}

	var enabled_rows: Array = []
	for row_key_v in rows.keys():
		var row := (rows[row_key_v] as Dictionary).duplicate(true)
		if bool(row["enabled"]):
			enabled_rows.append(row)
	if enabled_rows.is_empty():
		var message := _error(
			"no_enabled_choices", path, "<root>", "expected at least one enabled row"
		)
		push_error(message)
		return {
			"ok": false,
			"error_code": "invalid_character_creation_config",
			"message": message,
			"value": [],
		}
	enabled_rows.sort_custom(_compare_choices)
	_choices_by_type[type_id] = enabled_rows.duplicate(true)
	return {"ok": true, "value": enabled_rows.duplicate(true)}


static func validate_table(rows: Dictionary, choice_type: String, path: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	var type_id := choice_type.strip_edges().to_lower()
	if not PATHS.has(type_id):
		errors.append(_error(
			"unknown_choice_type", path, "<root>", "value=%s" % choice_type
		))
		return errors
	if rows.is_empty():
		errors.append(_error("empty_table", path, "<root>", "expected non-empty object"))
		return errors
	for row_key_v in rows.keys():
		var row_key := str(row_key_v).strip_edges()
		var row_field := row_key if row_key != "" else "<empty_key>"
		var row_v: Variant = rows[row_key_v]
		if not row_v is Dictionary:
			errors.append(_error(
				"row_not_dictionary", path, row_field,
				"expected Dictionary, got %s" % type_string(typeof(row_v))
			))
			continue
		_validate_row(errors, row_key, row_v as Dictionary, type_id, path)
	return errors


static func _validate_row(
		errors: PackedStringArray,
		row_key: String,
		row: Dictionary,
		choice_type: String,
		path: String
) -> void:
	var prefix := row_key if row_key != "" else "<empty_key>"
	var id_v: Variant = row.get("id")
	if not id_v is String or str(id_v).strip_edges() == "":
		errors.append(_error("invalid_id", path, "%s.id" % prefix, "expected non-empty String"))
	elif str(id_v).strip_edges() != row_key:
		errors.append(_error(
			"id_key_mismatch", path, "%s.id" % prefix,
			"value=%s expected=%s" % [str(id_v), row_key]
		))
	_require_non_empty_string(errors, row, "name", prefix, path)
	_require_non_empty_string(errors, row, "iconPath", prefix, path)
	_require_string(errors, row, "description", prefix, path)
	var sort_order_v: Variant = row.get("sortOrder")
	if not _is_integer_value(sort_order_v):
		errors.append(_error(
			"invalid_sort_order", path, "%s.sortOrder" % prefix,
			"expected integer value, got %s" % type_string(typeof(sort_order_v))
		))
	var enabled_v: Variant = row.get("enabled")
	if not enabled_v is bool:
		errors.append(_error(
			"invalid_enabled", path, "%s.enabled" % prefix,
			"expected bool, got %s" % type_string(typeof(enabled_v))
		))
	if choice_type in ["origin", "talent"]:
		_require_non_empty_string(errors, row, "passiveid", prefix, path)
	elif choice_type == "root":
		_validate_starter_skill_ids(errors, row, prefix, path)
		_require_non_empty_string(errors, row, "trait", prefix, path)


static func _require_non_empty_string(
		errors: PackedStringArray,
		row: Dictionary,
		field: String,
		prefix: String,
		path: String
) -> void:
	var value: Variant = row.get(field)
	if not value is String or str(value).strip_edges() == "":
		errors.append(_error(
			"invalid_%s" % field.to_snake_case(), path, "%s.%s" % [prefix, field],
			"expected non-empty String"
		))


static func _require_string(
		errors: PackedStringArray,
		row: Dictionary,
		field: String,
		prefix: String,
		path: String
) -> void:
	var value: Variant = row.get(field)
	if not value is String:
		errors.append(_error(
			"invalid_%s" % field.to_snake_case(), path, "%s.%s" % [prefix, field],
			"expected String, got %s" % type_string(typeof(value))
		))


static func _validate_starter_skill_ids(
		errors: PackedStringArray,
		row: Dictionary,
		prefix: String,
		path: String
) -> void:
	var value: Variant = row.get("starterSkillId")
	if not value is Array or (value as Array).is_empty():
		errors.append(_error(
			"invalid_starter_skill_ids", path, "%s.starterSkillId" % prefix,
			"expected non-empty Array[String]"
		))
		return
	for index in (value as Array).size():
		var skill_id_v: Variant = (value as Array)[index]
		if not skill_id_v is String or str(skill_id_v).strip_edges() == "":
			errors.append(_error(
				"invalid_starter_skill_id", path,
				"%s.starterSkillId[%d]" % [prefix, index], "expected non-empty String"
			))


static func _is_integer_value(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_equal_approx(float(value), roundf(float(value)))
	return false


static func _compare_choices(a: Dictionary, b: Dictionary) -> bool:
	var left_order := int(a["sortOrder"])
	var right_order := int(b["sortOrder"])
	if left_order != right_order:
		return left_order < right_order
	return str(a["id"]).naturalnocasecmp_to(str(b["id"])) < 0


static func _error(code: String, path: String, field: String, detail: String) -> String:
	return "[character_creation_catalog:%s] file=%s field=%s %s" % [
		code, path, field, detail,
	]
