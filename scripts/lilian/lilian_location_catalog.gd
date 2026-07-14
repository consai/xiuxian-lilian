class_name LilianLocationCatalog
extends RefCounted

const SCHEMA_PATH := "res://data/exportjson/didian.json"
const LOCATIONS_PATH := "res://data/exportjson/didian_locations.json"
const SCHEMA_VERSION := 3

const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")
const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")

var _paths: Dictionary
var _load_attempted := false
var _valid := false
var _errors: PackedStringArray = []
var _schema: Dictionary = {}
var _locations: Dictionary = {}


func _init(paths: Dictionary = {}) -> void:
	_paths = {
		"schema": str(paths.get("schema", SCHEMA_PATH)),
		"locations": str(paths.get("locations", LOCATIONS_PATH)),
	}


func schema() -> Dictionary:
	_ensure_loaded()
	return _schema.duplicate(true) if _valid else {}


func location_by_id(location_id: String) -> Dictionary:
	_ensure_loaded()
	if not _valid:
		return {}
	var id := location_id.strip_edges()
	var row_v: Variant = _locations.get(id)
	if not row_v is Dictionary:
		return {}
	var row := (row_v as Dictionary).duplicate(true)
	row["id"] = id
	return row


func all_location_ids() -> Array:
	_ensure_loaded()
	if not _valid:
		return []
	var ids: Array = _locations.keys()
	ids.sort_custom(ExportTableReaderScript.compare_keys)
	return ids.duplicate()


func all_locations() -> Array:
	var out: Array = []
	for id_v in all_location_ids():
		out.append(location_by_id(str(id_v)))
	return out


func collect_errors() -> PackedStringArray:
	_ensure_loaded()
	return _errors.duplicate()


static func validate_tables(
		schema_table: Dictionary,
		location_rows: Dictionary,
		paths: Dictionary = {}
) -> PackedStringArray:
	var schema_path := str(paths.get("schema", SCHEMA_PATH))
	var locations_path := str(paths.get("locations", LOCATIONS_PATH))
	var errors: PackedStringArray = []
	_validate_schema(schema_table, schema_path, errors)
	_validate_locations(location_rows, locations_path, errors)
	return errors


static func _normalize_locations(location_rows: Dictionary) -> Dictionary:
	var normalized := location_rows.duplicate(true)
	for key_v in normalized.keys():
		var row_v: Variant = normalized[key_v]
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		var event_pool: Array = []
		for event_id_v in row.get("event_pool", []) as Array:
			event_pool.append({"id": str(event_id_v), "weight": 1})
		row["event_pool"] = event_pool
	return normalized


func _ensure_loaded() -> void:
	if _load_attempted:
		return
	_load_attempted = true
	for key in ["schema", "locations"]:
		var path := str(_paths[key])
		var root_v: Variant = JsonReaderScript.read_variant(path)
		if root_v == null:
			_fail("unreadable_file", path, "root")
			return
		if not root_v is Dictionary:
			_fail("invalid_root", path, "root")
			return
		for row_key_v in (root_v as Dictionary).keys():
			if not (root_v as Dictionary)[row_key_v] is Dictionary:
				_fail("invalid_row", path, str(row_key_v))
				return
	var schema_table := ExportTableReaderScript.read_settings(str(_paths["schema"]))
	var location_rows := ExportTableReaderScript.read_keyed_rows(str(_paths["locations"]))
	_errors = validate_tables(schema_table, location_rows, _paths)
	if not _errors.is_empty():
		for message in _errors:
			push_error(message)
		_clear()
		return
	_schema = schema_table.duplicate(true)
	_locations = _normalize_locations(location_rows)
	_valid = true


func _fail(code: String, path: String, field: String) -> void:
	_errors.append(_message(code, path, field))
	push_error(_errors[_errors.size() - 1])
	_clear()


func _clear() -> void:
	_valid = false
	_schema.clear()
	_locations.clear()


static func _validate_schema(table: Dictionary, path: String, errors: PackedStringArray) -> void:
	if not _is_integer_number(table.get("schema_version")):
		errors.append(_message("schema_version_type", path, "schema_version"))
	elif int(table.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append(_message("schema_version_unsupported", path, "schema_version"))


static func _validate_locations(rows: Dictionary, path: String, errors: PackedStringArray) -> void:
	if rows.is_empty():
		errors.append(_message("table_empty", path, "root"))
		return
	for key_v in rows.keys():
		var key := str(key_v).strip_edges()
		var row_v: Variant = rows[key_v]
		if key == "":
			errors.append(_message("row_key_empty", path, "root"))
			continue
		if not row_v is Dictionary:
			errors.append(_message("invalid_row", path, key))
			continue
		_validate_location(key, row_v as Dictionary, path, errors)


static func _validate_location(key: String, row: Dictionary, path: String, errors: PackedStringArray) -> void:
	if row.has("id"):
		errors.append(_message("unexpected_runtime_id", path, "%s.id" % key))
	if not row.get("key") is String or str(row.get("key")).strip_edges() != key:
		errors.append(_message("row_key_mismatch", path, "%s.key" % key))
	for field in ["name", "subtitle", "desc", "recommended_realm"]:
		_required_string(row, field, key, path, errors)
	for field in ["danger", "min_difficulty", "max_difficulty"]:
		if not _is_integer_number(row.get(field)):
			errors.append(_message("integer_type", path, "%s.%s" % [key, field]))
	if _is_integer_number(row.get("danger")) and int(row["danger"]) < 0:
		errors.append(_message("danger_range", path, "%s.danger" % key))
	if _is_integer_number(row.get("min_difficulty")) and int(row["min_difficulty"]) < 1:
		errors.append(_message("difficulty_range", path, "%s.min_difficulty" % key))
	if _is_integer_number(row.get("min_difficulty")) and _is_integer_number(row.get("max_difficulty")) \
			and int(row["max_difficulty"]) < int(row["min_difficulty"]):
		errors.append(_message("difficulty_range", path, "%s.max_difficulty" % key))
	for field in ["preview_rewards", "tags", "monsters", "event_pool"]:
		_validate_non_empty_string_array(row.get(field), "%s.%s" % [key, field], path, errors)
	_validate_unique_strings(row.get("monsters"), "%s.monsters" % key, path, errors)
	_validate_unique_strings(row.get("event_pool"), "%s.event_pool" % key, path, errors)
	_validate_drop_pools(row.get("drop_pools"), key, path, errors)
	if row.has("materials"):
		_validate_materials(row.get("materials"), row.get("drop_pools"), key, path, errors)


static func _validate_drop_pools(value: Variant, location_id: String, path: String, errors: PackedStringArray) -> void:
	var field := "%s.drop_pools" % location_id
	if not value is Dictionary:
		errors.append(_message("drop_pools_type", path, field))
		return
	for pool_id_v in (value as Dictionary).keys():
		var pool_id := str(pool_id_v).strip_edges()
		var pool_v: Variant = (value as Dictionary)[pool_id_v]
		var pool_field := "%s.%s" % [field, pool_id]
		if pool_id == "":
			errors.append(_message("pool_id_empty", path, field))
			continue
		if not pool_v is Dictionary:
			errors.append(_message("pool_type", path, pool_field))
			continue
		var entries_v: Variant = (pool_v as Dictionary).get("entries")
		if not entries_v is Array:
			errors.append(_message("pool_entries_type", path, "%s.entries" % pool_field))
			continue
		for index in (entries_v as Array).size():
			_validate_drop_entry((entries_v as Array)[index], "%s.entries[%d]" % [pool_field, index], path, errors, true)


static func _validate_drop_entry(
		value: Variant,
		field: String,
		path: String,
		errors: PackedStringArray,
		require_counts: bool
) -> void:
	if not value is Dictionary:
		errors.append(_message("drop_entry_type", path, field))
		return
	var entry := value as Dictionary
	var kind := str(entry.get("kind", "")).strip_edges()
	if require_counts and (not entry.get("kind") is String or kind not in ["item", "equip", "currency"]):
		errors.append(_message("drop_kind", path, "%s.kind" % field))
	elif not require_counts and entry.has("kind") \
			and (not entry.get("kind") is String or kind not in ["item", "equip", "currency"]):
		errors.append(_message("drop_kind", path, "%s.kind" % field))
	if not entry.get("id") is String or str(entry.get("id")).strip_edges() == "":
		errors.append(_message("drop_id", path, "%s.id" % field))
	if not _is_integer_number(entry.get("weight")) or int(entry.get("weight", 0)) <= 0:
		errors.append(_message("drop_weight", path, "%s.weight" % field))
	if require_counts:
		if not _is_integer_number(entry.get("min")) or int(entry.get("min", 0)) < 1:
			errors.append(_message("drop_count", path, "%s.min" % field))
		if not _is_integer_number(entry.get("max")):
			errors.append(_message("drop_count", path, "%s.max" % field))
		elif _is_integer_number(entry.get("min")) and int(entry["max"]) < int(entry["min"]):
			errors.append(_message("drop_count", path, "%s.max" % field))
	if entry.has("material_grade") and (not _is_integer_number(entry["material_grade"]) or int(entry["material_grade"]) < 1):
		errors.append(_message("material_grade", path, "%s.material_grade" % field))
	if entry.has("conditions"):
		_validate_object_array(entry["conditions"], "%s.conditions" % field, path, errors)
	if entry.has("variants"):
		var variants_v: Variant = entry["variants"]
		if not variants_v is Array:
			errors.append(_message("variants_type", path, "%s.variants" % field))
		else:
			for index in (variants_v as Array).size():
				_validate_drop_entry((variants_v as Array)[index], "%s.variants[%d]" % [field, index], path, errors, false)


static func _validate_materials(
		value: Variant,
		drop_pools_v: Variant,
		location_id: String,
		path: String,
		errors: PackedStringArray
) -> void:
	var field := "%s.materials" % location_id
	if not value is Array:
		errors.append(_message("materials_type", path, field))
		return
	var drop_pools := drop_pools_v as Dictionary if drop_pools_v is Dictionary else {}
	var seen := {}
	for index in (value as Array).size():
		var material_v: Variant = (value as Array)[index]
		var item_field := "%s[%d]" % [field, index]
		if not material_v is Dictionary:
			errors.append(_message("material_type", path, item_field))
			continue
		var material := material_v as Dictionary
		for string_field in ["id", "name", "category", "drop_pool"]:
			_required_string(material, string_field, item_field, path, errors)
		var material_id := str(material.get("id", "")).strip_edges()
		if material_id != "" and seen.has(material_id):
			errors.append(_message("material_id_duplicate", path, "%s.id" % item_field))
		seen[material_id] = true
		var pool_id := str(material.get("drop_pool", "")).strip_edges()
		if pool_id != "" and not drop_pools.has(pool_id):
			errors.append(_message("material_pool_unknown", path, "%s.drop_pool" % item_field))
		_validate_non_empty_string_array(material.get("item_ids"), "%s.item_ids" % item_field, path, errors)


static func _validate_object_array(value: Variant, field: String, path: String, errors: PackedStringArray) -> void:
	if not value is Array:
		errors.append(_message("object_array_type", path, field))
		return
	for index in (value as Array).size():
		if not (value as Array)[index] is Dictionary:
			errors.append(_message("object_entry_type", path, "%s[%d]" % [field, index]))


static func _validate_non_empty_string_array(value: Variant, field: String, path: String, errors: PackedStringArray) -> void:
	if not value is Array:
		errors.append(_message("string_array_type", path, field))
		return
	if (value as Array).is_empty():
		errors.append(_message("array_empty", path, field))
	for index in (value as Array).size():
		var cell: Variant = (value as Array)[index]
		if not cell is String or str(cell).strip_edges() == "":
			errors.append(_message("string_entry_type", path, "%s[%d]" % [field, index]))


static func _validate_unique_strings(value: Variant, field: String, path: String, errors: PackedStringArray) -> void:
	if not value is Array:
		return
	var seen := {}
	for index in (value as Array).size():
		var id := str((value as Array)[index]).strip_edges()
		if id != "" and seen.has(id):
			errors.append(_message("duplicate_id", path, "%s[%d]" % [field, index]))
		seen[id] = true


static func _required_string(
		row: Dictionary,
		field: String,
		prefix: String,
		path: String,
		errors: PackedStringArray
) -> void:
	if not row.get(field) is String or str(row.get(field)).strip_edges() == "":
		errors.append(_message("required_string", path, "%s.%s" % [prefix, field]))


static func _is_integer_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_equal_approx(float(value), roundf(float(value)))
	return false


static func _message(code: String, path: String, field: String) -> String:
	return "[lilian_location_catalog:%s] file=%s field=%s" % [code, path, field]
