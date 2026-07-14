class_name LilianEventCatalog
extends RefCounted

const COMMON_SCHEMA_PATH := "res://data/exportjson/lilian_common_events.json"
const COMMON_EVENTS_PATH := "res://data/exportjson/lilian_common_events_events.json"
const EXPLICIT_SCHEMA_PATH := "res://data/exportjson/lilian_events.json"
const EXPLICIT_EVENTS_PATH := "res://data/exportjson/lilian_events_events.json"
const SCHEMA_VERSION := 2

const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")
const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")

static var _load_attempted := false
static var _valid := false
static var _errors: PackedStringArray = []
static var _common_schema: Dictionary = {}
static var _explicit_schema: Dictionary = {}
static var _common_events: Dictionary = {}
static var _explicit_events: Dictionary = {}


static func common_schema() -> Dictionary:
	_ensure_loaded()
	return _common_schema.duplicate(true) if _valid else {}


static func explicit_schema() -> Dictionary:
	_ensure_loaded()
	return _explicit_schema.duplicate(true) if _valid else {}


static func common_by_id(event_id: String) -> Dictionary:
	_ensure_loaded()
	return _row_by_id(_common_events, event_id) if _valid else {}


static func explicit_by_id(event_id: String) -> Dictionary:
	_ensure_loaded()
	return _row_by_id(_explicit_events, event_id) if _valid else {}


static func static_by_id(event_id: String) -> Dictionary:
	var event := explicit_by_id(event_id)
	return event if not event.is_empty() else common_by_id(event_id)


static func all_common_ids() -> Array:
	_ensure_loaded()
	return _sorted_ids(_common_events) if _valid else []


static func all_explicit_ids() -> Array:
	_ensure_loaded()
	return _sorted_ids(_explicit_events) if _valid else []


static func collect_errors() -> PackedStringArray:
	_ensure_loaded()
	return _errors.duplicate()


static func validate_tables(
		common_schema_table: Dictionary,
		common_rows: Dictionary,
		explicit_schema_table: Dictionary,
		explicit_rows: Dictionary,
		paths: Dictionary = {}
) -> PackedStringArray:
	var resolved_paths := {
		"common_schema": str(paths.get("common_schema", COMMON_SCHEMA_PATH)),
		"common_events": str(paths.get("common_events", COMMON_EVENTS_PATH)),
		"explicit_schema": str(paths.get("explicit_schema", EXPLICIT_SCHEMA_PATH)),
		"explicit_events": str(paths.get("explicit_events", EXPLICIT_EVENTS_PATH)),
	}
	var errors: PackedStringArray = []
	_validate_schema(common_schema_table, resolved_paths["common_schema"], errors)
	_validate_schema(explicit_schema_table, resolved_paths["explicit_schema"], errors)
	_validate_event_table(common_rows, resolved_paths["common_events"], errors)
	_validate_event_table(explicit_rows, resolved_paths["explicit_events"], errors)
	for id_v in common_rows.keys():
		var event_id := str(id_v)
		if explicit_rows.has(event_id):
			errors.append(_message("duplicate_event_id", resolved_paths["explicit_events"], event_id))
	var all_rows := common_rows.duplicate(true)
	for id_v in explicit_rows.keys():
		all_rows[str(id_v)] = explicit_rows[id_v]
	_validate_trigger_references(common_rows, all_rows, resolved_paths["common_events"], errors)
	_validate_trigger_references(explicit_rows, all_rows, resolved_paths["explicit_events"], errors)
	return errors


static func _ensure_loaded() -> void:
	if _load_attempted:
		return
	_load_attempted = true
	var paths := {
		"common_schema": COMMON_SCHEMA_PATH,
		"common_events": COMMON_EVENTS_PATH,
		"explicit_schema": EXPLICIT_SCHEMA_PATH,
		"explicit_events": EXPLICIT_EVENTS_PATH,
	}
	for key in ["common_schema", "common_events", "explicit_schema", "explicit_events"]:
		var path := str(paths[key])
		var root_v: Variant = JsonReaderScript.read_variant(path)
		if root_v == null:
			_errors.append(_message("unreadable_file", path, "root"))
			_report_and_clear()
			return
		if not root_v is Dictionary:
			_errors.append(_message("invalid_root", path, "root"))
			_report_and_clear()
			return
		for row_key_v in (root_v as Dictionary).keys():
			if not (root_v as Dictionary)[row_key_v] is Dictionary:
				_errors.append(_message("invalid_row", path, str(row_key_v)))
				_report_and_clear()
				return
	var common_schema_table := ExportTableReaderScript.read_settings(COMMON_SCHEMA_PATH)
	var common_rows := ExportTableReaderScript.read_keyed_rows(COMMON_EVENTS_PATH)
	var explicit_schema_table := ExportTableReaderScript.read_settings(EXPLICIT_SCHEMA_PATH)
	var explicit_rows := ExportTableReaderScript.read_keyed_rows(EXPLICIT_EVENTS_PATH)
	_errors = validate_tables(
		common_schema_table,
		common_rows,
		explicit_schema_table,
		explicit_rows,
		paths
	)
	if not _errors.is_empty():
		_report_and_clear()
		return
	_common_schema = common_schema_table.duplicate(true)
	_explicit_schema = explicit_schema_table.duplicate(true)
	_common_events = common_rows.duplicate(true)
	_explicit_events = explicit_rows.duplicate(true)
	_valid = true


static func _validate_schema(table: Dictionary, path: String, errors: PackedStringArray) -> void:
	if not _is_integer_number(table.get("schema_version")):
		errors.append(_message("schema_version_type", path, "schema_version"))
	elif int(table.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append(_message("schema_version_unsupported", path, "schema_version"))


static func _validate_event_table(table: Dictionary, path: String, errors: PackedStringArray) -> void:
	if table.is_empty():
		errors.append(_message("table_empty", path, "root"))
		return
	for key_v in table.keys():
		var key := str(key_v).strip_edges()
		var row_v: Variant = table[key_v]
		if key == "":
			errors.append(_message("row_key_empty", path, "root"))
			continue
		if not row_v is Dictionary:
			errors.append(_message("invalid_row", path, key))
			continue
		_validate_event_row(key, row_v as Dictionary, path, errors)


static func _validate_event_row(key: String, row: Dictionary, path: String, errors: PackedStringArray) -> void:
	_required_string(row, "id", key, path, errors)
	if row.get("id") is String and str(row.get("id")).strip_edges() != key:
		errors.append(_message("row_id_mismatch", path, "%s.id" % key))
	for field in ["location_id", "type", "name"]:
		_required_string(row, field, key, path, errors)
	for field in ["desc", "risk_text"]:
		if not row.get(field) is String:
			errors.append(_message("string_type", path, "%s.%s" % [key, field]))
	if not _is_integer_number(row.get("weight")) or int(row.get("weight", 0)) <= 0:
		errors.append(_message("weight_type", path, "%s.weight" % key))
	if not row.get("once_per_lilian") is bool:
		errors.append(_message("once_type", path, "%s.once_per_lilian" % key))
	for field in ["tags", "conditions", "results"]:
		if not row.get(field) is Array:
			errors.append(_message("array_type", path, "%s.%s" % [key, field]))
	if row.get("tags") is Array:
		_validate_string_array_entries(row["tags"] as Array, "%s.tags" % key, path, errors)
	if row.get("conditions") is Array:
		_validate_object_array_entries(row["conditions"] as Array, "%s.conditions" % key, path, errors)
	if row.get("results") is Array:
		_validate_results(row["results"] as Array, "%s.results" % key, path, errors)
	for optional_array in ["effects", "options"]:
		if row.has(optional_array) and not row[optional_array] is Array:
			errors.append(_message("array_type", path, "%s.%s" % [key, optional_array]))
	if row.get("effects") is Array:
		_validate_object_array_entries(row["effects"] as Array, "%s.effects" % key, path, errors)
	for optional_string in ["mode", "drop_pool", "enemy_pool", "template_id", "success_text", "empty_text", "outcome_text"]:
		if row.has(optional_string) and not row[optional_string] is String:
			errors.append(_message("string_type", path, "%s.%s" % [key, optional_string]))
	if row.has("duration_days") and not _is_integer_number(row["duration_days"]):
		errors.append(_message("integer_type", path, "%s.duration_days" % key))
	if row.has("enemy_count"):
		var enemy_count: Variant = row["enemy_count"]
		if not enemy_count is String or str(enemy_count).strip_edges() == "" \
				or not str(enemy_count).is_valid_int() or int(enemy_count) <= 0:
			errors.append(_message("enemy_count_type", path, "%s.enemy_count" % key))
	_validate_options(row.get("options", []), key, path, errors)


static func _validate_options(value: Variant, event_id: String, path: String, errors: PackedStringArray) -> void:
	if not value is Array:
		return
	var seen := {}
	for index in (value as Array).size():
		var option_v: Variant = (value as Array)[index]
		var field := "%s.options[%d]" % [event_id, index]
		if not option_v is Dictionary:
			errors.append(_message("option_type", path, field))
			continue
		var option := option_v as Dictionary
		var option_id := str(option.get("id", "")).strip_edges()
		if not option.get("id") is String or option_id == "":
			errors.append(_message("option_id", path, "%s.id" % field))
		elif seen.has(option_id):
			errors.append(_message("option_id_duplicate", path, "%s.id" % field))
		seen[option_id] = true
		for array_field in ["conditions", "effects", "results", "rewards"]:
			if option.has(array_field) and not option[array_field] is Array:
				errors.append(_message("array_type", path, "%s.%s" % [field, array_field]))
		if option.get("conditions") is Array:
			_validate_object_array_entries(option["conditions"] as Array, "%s.conditions" % field, path, errors)
		if option.get("effects") is Array:
			_validate_object_array_entries(option["effects"] as Array, "%s.effects" % field, path, errors)
		if option.get("results") is Array:
			_validate_results(option["results"] as Array, "%s.results" % field, path, errors)
		if option.get("rewards") is Array:
			_validate_object_array_entries(option["rewards"] as Array, "%s.rewards" % field, path, errors)
		for string_field in ["label", "desc", "risk_text", "drop_pool", "trigger_event"]:
			if option.has(string_field) and not option[string_field] is String:
				errors.append(_message("string_type", path, "%s.%s" % [field, string_field]))


static func _validate_trigger_references(
		table: Dictionary,
		all_rows: Dictionary,
		path: String,
		errors: PackedStringArray
) -> void:
	for event_id_v in table.keys():
		var event_id := str(event_id_v)
		var row_v: Variant = table[event_id_v]
		if not row_v is Dictionary:
			continue
		var options_v: Variant = (row_v as Dictionary).get("options", [])
		if not options_v is Array:
			continue
		for index in (options_v as Array).size():
			var option_v: Variant = (options_v as Array)[index]
			if not option_v is Dictionary:
				continue
			var trigger_id := str((option_v as Dictionary).get("trigger_event", "")).strip_edges()
			if trigger_id != "" and not all_rows.has(trigger_id):
				errors.append(_message("unknown_trigger_event", path, "%s.options[%d].trigger_event" % [event_id, index]))


static func _validate_results(results: Array, field: String, path: String, errors: PackedStringArray) -> void:
	for index in results.size():
		var result_v: Variant = results[index]
		var entry_field := "%s[%d]" % [field, index]
		if not result_v is Dictionary:
			errors.append(_message("result_type", path, entry_field))
			continue
		var result := result_v as Dictionary
		var result_type := str(result.get("type", "")).strip_edges()
		if not result.get("type") is String or result_type == "":
			errors.append(_message("result_kind", path, "%s.type" % entry_field))
			continue
		match result_type:
			"drop":
				if not result.get("drop_pool") is String or str(result.get("drop_pool")).strip_edges() == "":
					errors.append(_message("result_drop_pool", path, "%s.drop_pool" % entry_field))
			"rewards":
				if not result.get("rewards") is Array:
					errors.append(_message("array_type", path, "%s.rewards" % entry_field))
				else:
					_validate_object_array_entries(result["rewards"] as Array, "%s.rewards" % entry_field, path, errors)
			"effects":
				if not result.get("effects") is Array:
					errors.append(_message("array_type", path, "%s.effects" % entry_field))
				else:
					_validate_object_array_entries(result["effects"] as Array, "%s.effects" % entry_field, path, errors)
			_:
				errors.append(_message("result_kind_unknown", path, "%s.type" % entry_field))


static func _validate_object_array_entries(
		values: Array,
		field: String,
		path: String,
		errors: PackedStringArray
) -> void:
	for index in values.size():
		if not values[index] is Dictionary:
			errors.append(_message("object_entry_type", path, "%s[%d]" % [field, index]))


static func _validate_string_array_entries(
		values: Array,
		field: String,
		path: String,
		errors: PackedStringArray
) -> void:
	for index in values.size():
		if not values[index] is String:
			errors.append(_message("string_entry_type", path, "%s[%d]" % [field, index]))


static func _required_string(
		row: Dictionary,
		field: String,
		key: String,
		path: String,
		errors: PackedStringArray
) -> void:
	if not row.get(field) is String or str(row.get(field)).strip_edges() == "":
		errors.append(_message("required_string", path, "%s.%s" % [key, field]))


static func _row_by_id(table: Dictionary, event_id: String) -> Dictionary:
	var id := event_id.strip_edges()
	var row_v: Variant = table.get(id)
	return (row_v as Dictionary).duplicate(true) if row_v is Dictionary else {}


static func _sorted_ids(table: Dictionary) -> Array:
	var ids: Array = table.keys()
	ids.sort_custom(ExportTableReaderScript.compare_keys)
	return ids.duplicate()


static func _is_integer_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_equal_approx(float(value), roundf(float(value)))
	return false


static func _report_and_clear() -> void:
	for error in _errors:
		push_error(error)
	_valid = false
	_common_schema.clear()
	_explicit_schema.clear()
	_common_events.clear()
	_explicit_events.clear()


static func _message(code: String, path: String, field: String) -> String:
	return "[lilian_event_catalog:%s] file=%s field=%s" % [code, path, field]
