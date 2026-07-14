class_name WeituoCatalog
extends RefCounted

const SCHEMA_PATH := "res://data/exportjson/weituo.json"
const RULES_PATH := "res://data/exportjson/weituo_rules.json"
const COMMISSIONS_PATH := "res://data/exportjson/weituo_weituo.json"
const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")

static var _schema_loaded := false
static var _rules_loaded := false
static var _commissions_loaded := false
static var _schema: Dictionary = {}
static var _rules: Dictionary = {}
static var _commissions: Dictionary = {}


static func schema() -> Dictionary:
	if not _schema_loaded:
		_schema_loaded = true
		var loaded := ExportTableReaderScript.read_settings(SCHEMA_PATH)
		var errors := validate_schema(loaded)
		_schema = _accept_or_report(loaded, errors)
	return _schema.duplicate(true)


static func rules() -> Dictionary:
	if not _rules_loaded:
		_rules_loaded = true
		var loaded := ExportTableReaderScript.read_settings(RULES_PATH)
		var errors := validate_rules(loaded)
		_rules = _accept_or_report(loaded, errors)
	return _rules.duplicate(true)


static func commissions() -> Dictionary:
	if not _commissions_loaded:
		_commissions_loaded = true
		var loaded := ExportTableReaderScript.read_keyed_rows(COMMISSIONS_PATH)
		var errors := validate_commissions(loaded)
		_commissions = _accept_or_report(loaded, errors)
	return _commissions.duplicate(true)


static func commission_by_id(commission_id: String) -> Dictionary:
	var key := commission_id.strip_edges()
	if key == "":
		return {}
	var row_v: Variant = commissions().get(key)
	if not row_v is Dictionary:
		return {}
	return (row_v as Dictionary).duplicate(true)


static func validate_schema(value: Dictionary, path: String = SCHEMA_PATH) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not _is_integer_number(value.get("schema_version")):
		errors.append(_error("schema_version_type", path, "schema_version", "expected integer number"))
	elif int(value["schema_version"]) != 1:
		errors.append(_error("schema_version_unsupported", path, "schema_version", "expected 1"))
	return errors


static func validate_rules(value: Dictionary, path: String = RULES_PATH) -> PackedStringArray:
	var errors: PackedStringArray = []
	for field in ["active_limit", "refresh_days", "board_offer_count"]:
		var field_value: Variant = value.get(field)
		if not _is_integer_number(field_value):
			errors.append(_error("rule_type", path, field, "expected integer number"))
		elif int(field_value) <= 0:
			errors.append(_error("rule_range", path, field, "expected > 0"))
	return errors


static func validate_commissions(value: Dictionary, path: String = COMMISSIONS_PATH) -> PackedStringArray:
	var errors: PackedStringArray = []
	if value.is_empty():
		errors.append(_error("table_empty", path, "$", "expected at least one row"))
		return errors
	for row_key_v in value.keys():
		var row_key := str(row_key_v).strip_edges()
		var row_v: Variant = value[row_key_v]
		if row_key == "":
			errors.append(_error("row_key_empty", path, "$", "row key must not be empty"))
			continue
		if not row_v is Dictionary:
			errors.append(_error("row_type", path, row_key, "expected object"))
			continue
		_validate_commission_row(errors, row_key, row_v as Dictionary, path)
	return errors


static func _validate_commission_row(
		errors: PackedStringArray,
		row_key: String,
		row: Dictionary,
		path: String
) -> void:
	var id_field := "%s.id" % row_key
	if not row.get("id") is String or str(row.get("id")).strip_edges() == "":
		errors.append(_error("required_string", path, id_field, "expected non-empty string"))
	elif str(row["id"]).strip_edges() != row_key:
		errors.append(_error("row_id_mismatch", path, id_field, "expected row key '%s'" % row_key))
	for field in ["title", "issuer", "desc"]:
		var value: Variant = row.get(field)
		if not value is String or str(value).strip_edges() == "":
			errors.append(_error("required_string", path, "%s.%s" % [row_key, field], "expected non-empty string"))
	if not row.get("repeatable") is bool:
		errors.append(_error("required_bool", path, "%s.repeatable" % row_key, "expected bool"))
	if row.has("weight"):
		var weight: Variant = row["weight"]
		if not _is_integer_number(weight) or int(weight) <= 0:
			errors.append(_error("weight_type", path, "%s.weight" % row_key, "expected integer number > 0"))
	if row.has("rarity") and not row["rarity"] is String:
		errors.append(_error("rarity_type", path, "%s.rarity" % row_key, "expected string"))
	_validate_unlock(errors, row_key, row.get("unlock"), path)
	_validate_ui(errors, row_key, row.get("ui"), path)
	_validate_requirements(errors, row_key, row.get("requirements"), path)
	_validate_rewards(errors, row_key, row.get("rewards"), path)


static func _validate_unlock(
		errors: PackedStringArray,
		row_key: String,
		value: Variant,
		path: String
) -> void:
	if value == null:
		return
	var field := "%s.unlock" % row_key
	if not value is Dictionary:
		errors.append(_error("unlock_type", path, field, "expected object"))
		return
	var unlock := value as Dictionary
	if unlock.has("min_realm_index") and not _is_integer_number(unlock["min_realm_index"]):
		errors.append(_error("unlock_realm_type", path, "%s.min_realm_index" % field, "expected integer number"))
	if unlock.has("city_id") and (not unlock["city_id"] is String or str(unlock["city_id"]).strip_edges() == ""):
		errors.append(_error("unlock_city_type", path, "%s.city_id" % field, "expected non-empty string"))


static func _validate_ui(
		errors: PackedStringArray,
		row_key: String,
		value: Variant,
		path: String
) -> void:
	var field := "%s.ui" % row_key
	if not value is Dictionary:
		errors.append(_error("ui_type", path, field, "expected object"))
		return
	var ui := value as Dictionary
	for child in ["portrait", "badge"]:
		var child_value: Variant = ui.get(child)
		if not child_value is String or str(child_value).strip_edges() == "":
			errors.append(_error("ui_required_string", path, "%s.%s" % [field, child], "expected non-empty string"))


static func _validate_requirements(
		errors: PackedStringArray,
		row_key: String,
		value: Variant,
		path: String
) -> void:
	var field := "%s.requirements" % row_key
	if not value is Array:
		errors.append(_error("requirements_type", path, field, "expected array"))
		return
	var rows := value as Array
	if rows.is_empty():
		errors.append(_error("requirements_empty", path, field, "expected at least one requirement"))
	for index in rows.size():
		var entry_field := "%s[%d]" % [field, index]
		var entry_v: Variant = rows[index]
		if not entry_v is Dictionary:
			errors.append(_error("requirement_type", path, entry_field, "expected object"))
			continue
		var entry := entry_v as Dictionary
		var kind_v: Variant = entry.get("kind")
		if not kind_v is String:
			errors.append(_error("requirement_kind_type", path, "%s.kind" % entry_field, "expected string"))
			continue
		var kind := str(kind_v).strip_edges()
		if kind == "item":
			_validate_item_requirement(errors, entry, entry_field, path)
		elif kind == "lilian":
			_validate_lilian_requirement(errors, entry, entry_field, path)
		else:
			errors.append(_error("requirement_kind_unknown", path, "%s.kind" % entry_field, "unsupported '%s'" % kind))


static func _validate_item_requirement(
		errors: PackedStringArray,
		entry: Dictionary,
		field: String,
		path: String
) -> void:
	_required_non_empty_string(errors, entry, "id", field, path, "requirement_item_id")
	_required_non_empty_string(errors, entry, "label", field, path, "requirement_item_label")
	_required_positive_int(errors, entry, "count", field, path, "requirement_item_count")
	if not entry.get("consume") is bool:
		errors.append(_error("requirement_item_consume", path, "%s.consume" % field, "expected bool"))


static func _validate_lilian_requirement(
		errors: PackedStringArray,
		entry: Dictionary,
		field: String,
		path: String
) -> void:
	_required_non_empty_string(errors, entry, "location_id", field, path, "requirement_location_id")
	_required_positive_int(errors, entry, "min_steps", field, path, "requirement_min_steps")
	if not entry.get("require_not_defeated") is bool:
		errors.append(_error("requirement_not_defeated", path, "%s.require_not_defeated" % field, "expected bool"))


static func _validate_rewards(
		errors: PackedStringArray,
		row_key: String,
		value: Variant,
		path: String
) -> void:
	var field := "%s.rewards" % row_key
	if not value is Array:
		errors.append(_error("rewards_type", path, field, "expected array"))
		return
	var rows := value as Array
	if rows.is_empty():
		errors.append(_error("rewards_empty", path, field, "expected at least one reward"))
	for index in rows.size():
		var entry_field := "%s[%d]" % [field, index]
		var entry_v: Variant = rows[index]
		if not entry_v is Dictionary:
			errors.append(_error("reward_type", path, entry_field, "expected object"))
			continue
		var entry := entry_v as Dictionary
		var kind_v: Variant = entry.get("kind")
		if not kind_v is String:
			errors.append(_error("reward_kind_type", path, "%s.kind" % entry_field, "expected string"))
			continue
		var kind := str(kind_v).strip_edges()
		if kind not in ["item", "equip", "currency"]:
			errors.append(_error("reward_kind_unknown", path, "%s.kind" % entry_field, "unsupported '%s'" % kind))
			continue
		if kind == "equip":
			var equip_id: Variant = entry.get("id")
			if not _is_integer_number(equip_id) and (not equip_id is String or not str(equip_id).is_valid_int()):
				errors.append(_error("reward_equip_id", path, "%s.id" % entry_field, "expected integer id"))
		else:
			_required_non_empty_string(errors, entry, "id", entry_field, path, "reward_id")
		_required_positive_int(errors, entry, "count", entry_field, path, "reward_count")


static func _required_non_empty_string(
		errors: PackedStringArray,
		row: Dictionary,
		key: String,
		prefix: String,
		path: String,
		code: String
) -> void:
	var value: Variant = row.get(key)
	if not value is String or str(value).strip_edges() == "":
		errors.append(_error(code, path, "%s.%s" % [prefix, key], "expected non-empty string"))


static func _required_positive_int(
		errors: PackedStringArray,
		row: Dictionary,
		key: String,
		prefix: String,
		path: String,
		code: String
) -> void:
	var value: Variant = row.get(key)
	if not _is_integer_number(value) or int(value) <= 0:
		errors.append(_error(code, path, "%s.%s" % [prefix, key], "expected integer number > 0"))


static func _is_integer_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_equal_approx(float(value), roundf(float(value)))
	return false


static func _accept_or_report(value: Dictionary, errors: PackedStringArray) -> Dictionary:
	if errors.is_empty():
		return value.duplicate(true)
	for message in errors:
		push_error(message)
	return {}


static func _error(code: String, path: String, field: String, detail: String) -> String:
	return "[weituo_catalog:%s] file=%s field=%s %s" % [code, path, field, detail]
