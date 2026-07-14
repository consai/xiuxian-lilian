class_name LilianRulesCatalog
extends RefCounted

const RULES_PATH := "res://data/exportjson/yunxing_params/lilian_rules.json"
const REWARD_BUDGET_PATH := "res://data/exportjson/yunxing_params/lilian_rules_reward_budget.json"
const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")

static var _rules_loaded := false
static var _reward_budget_loaded := false
static var _rules: Dictionary = {}
static var _reward_budget: Dictionary = {}


static func rules() -> Dictionary:
	if not _rules_loaded:
		_rules_loaded = true
		var loaded := ExportTableReaderScript.read_settings(RULES_PATH)
		_rules = _accept_or_report(loaded, validate_rules(loaded))
	return _rules.duplicate(true)


static func reward_budget() -> Dictionary:
	if not _reward_budget_loaded:
		_reward_budget_loaded = true
		var loaded := ExportTableReaderScript.read_settings(REWARD_BUDGET_PATH)
		_reward_budget = _accept_or_report(loaded, validate_reward_budget(loaded))
	return _reward_budget.duplicate(true)


static func validate_rules(value: Dictionary, path: String = RULES_PATH) -> PackedStringArray:
	var errors: PackedStringArray = []
	_validate_integer(errors, value, "schema_version", path, 1, 1)
	_validate_number(errors, value, "event_day_chance", path, 0.0, 1.0)
	_validate_integer(errors, value, "max_idle_days", path, 1)
	_validate_number(errors, value, "defeat_loot_drop_ratio", path, 0.0, 1.0)
	_validate_integer(errors, value, "defeat_injury_days", path, 0)
	_validate_number(errors, value, "defeat_hp_floor_ratio", path, 0.0, 1.0)
	_validate_integer(errors, value, "fled_injury_days", path, 0)
	_validate_integer(errors, value, "choice_count", path, 1)
	_validate_number(errors, value, "auto_event_advance_seconds", path, 0.0, INF, false)
	return errors


static func validate_reward_budget(
		value: Dictionary,
		path: String = REWARD_BUDGET_PATH
) -> PackedStringArray:
	var errors: PackedStringArray = []
	var enabled: Variant = value.get("enabled")
	if not enabled is bool:
		errors.append(_error("required_bool", path, "enabled", enabled, "expected bool"))
	_validate_number(errors, value, "daily_base_value", path, 0.0)
	_validate_number(errors, value, "difficulty_growth", path, 0.0)
	_validate_number(errors, value, "min_scale", path, 0.0, INF, false)
	_validate_number(errors, value, "max_scale", path, 0.0, INF, false)
	if _is_number(value.get("min_scale")) and _is_number(value.get("max_scale")) \
			and float(value["max_scale"]) < float(value["min_scale"]):
		errors.append(_error(
			"scale_order", path, "max_scale", value["max_scale"], "expected >= min_scale"
		))
	_validate_number_map(
		errors,
		value,
		"event_type_multipliers",
		["travel", "gather", "recover", "hazard", "battle", "elite", "boss"],
		path,
		0.0
	)
	_validate_number_map(
		errors, value, "unit_values", ["currency", "item", "equip"], path, 0.0, INF, false
	)
	_validate_number_map(
		errors, value, "material_grade_multipliers", ["1", "2", "3"], path, 0.0, INF, false
	)
	return errors


static func _validate_integer(
		errors: PackedStringArray,
		root: Dictionary,
		field: String,
		path: String,
		minimum: int,
		maximum: int = 2147483647
) -> void:
	var value: Variant = root.get(field)
	if not _is_integer_value(value):
		errors.append(_error("required_integer", path, field, value, "expected integer"))
		return
	var number := int(value)
	if number < minimum or number > maximum:
		errors.append(_error(
			"integer_range", path, field, value, "expected %d..%d" % [minimum, maximum]
		))


static func _validate_number(
		errors: PackedStringArray,
		root: Dictionary,
		field: String,
		path: String,
		minimum: float,
		maximum: float = INF,
		minimum_inclusive: bool = true
) -> void:
	var value: Variant = root.get(field)
	if not _is_number(value):
		errors.append(_error("required_number", path, field, value, "expected number"))
		return
	var number := float(value)
	var below := number < minimum if minimum_inclusive else number <= minimum
	if below or number > maximum:
		var detail := "expected >= %s" % minimum if maximum == INF else "expected %s..%s" % [minimum, maximum]
		if not minimum_inclusive:
			detail = "expected > %s" % minimum if maximum == INF else "expected > %s and <= %s" % [minimum, maximum]
		errors.append(_error("number_range", path, field, value, detail))


static func _validate_number_map(
		errors: PackedStringArray,
		root: Dictionary,
		field: String,
		required_keys: Array,
		path: String,
		minimum: float,
		maximum: float = INF,
		minimum_inclusive: bool = true
) -> void:
	var map_v: Variant = root.get(field)
	if not map_v is Dictionary:
		errors.append(_error("required_object", path, field, map_v, "expected object"))
		return
	var map := map_v as Dictionary
	for key_v in required_keys:
		var key := str(key_v)
		var value: Variant = map.get(key)
		var nested_field := "%s.%s" % [field, key]
		if not _is_number(value):
			errors.append(_error("required_number", path, nested_field, value, "expected number"))
			continue
		var number := float(value)
		var below := number < minimum if minimum_inclusive else number <= minimum
		if below or number > maximum:
			var detail := (
				"expected >= %s" % minimum
				if maximum == INF
				else "expected %s..%s" % [minimum, maximum]
			)
			if not minimum_inclusive:
				detail = (
					"expected > %s" % minimum
					if maximum == INF
					else "expected > %s and <= %s" % [minimum, maximum]
				)
			errors.append(_error("number_range", path, nested_field, value, detail))


static func _is_integer_value(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_equal_approx(float(value), roundf(float(value)))


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _accept_or_report(value: Dictionary, errors: PackedStringArray) -> Dictionary:
	if errors.is_empty():
		return value.duplicate(true)
	for message in errors:
		push_error(message)
	return {}


static func _error(
		code: String,
		path: String,
		field: String,
		value: Variant,
		detail: String
) -> String:
	return "[lilian_rules_catalog:%s] file=%s field=%s value=%s %s" % [
		code, path, field, str(value), detail
	]
