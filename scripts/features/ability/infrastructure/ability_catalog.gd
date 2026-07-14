class_name AbilityCatalog
extends RefCounted

const ACTIVE_PATH := "res://data/exportjson/zhandou_active.json"
const PASSIVE_PATH := "res://data/exportjson/passive.json"
const EXPECTED_ACTIVE_COUNT := 17
const EXPECTED_PASSIVE_COUNT := 22

const AbilityExportAdapterScript := preload("res://scripts/dao/ability_export_adapter.gd")
const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")
const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")

var _load_attempted := false
var _valid := false
var _errors: PackedStringArray = []
var _tables: Dictionary = {}
var _definitions: Array = []
var _by_id: Dictionary = {}
var _table_by_id: Dictionary = {}
var _paths: Dictionary


func _init(paths: Dictionary = {}) -> void:
	_paths = _resolved_paths({
		"active": str(paths.get("active", ACTIVE_PATH)),
		"passive": str(paths.get("passive", PASSIVE_PATH)),
	})


func reload() -> bool:
	_load_attempted = true
	var active_path := str(_paths[EnumSkill.LABEL_ZHANDOU_ACTIVE])
	var passive_path := str(_paths[EnumSkill.LABEL_PASSIVE])
	var active_v: Variant = JsonReaderScript.read_variant(active_path)
	var passive_v: Variant = JsonReaderScript.read_variant(passive_path)
	var errors: PackedStringArray = []
	if active_v == null:
		errors.append(_message("unreadable_file", active_path, EnumSkill.LABEL_ZHANDOU_ACTIVE, "root"))
	if passive_v == null:
		errors.append(_message("unreadable_file", passive_path, EnumSkill.LABEL_PASSIVE, "root"))
	if not errors.is_empty():
		return _reject(errors)
	return _commit_roots(active_v, passive_v, true, _paths)


func reload_from_roots(
		active_root: Variant,
		passive_root: Variant,
		paths: Dictionary = {}
) -> bool:
	## Contract-test seam. Production always uses reload() and the fixed export paths.
	_load_attempted = true
	return _commit_roots(active_root, passive_root, true, _resolved_paths(paths))


func collect_errors() -> PackedStringArray:
	_ensure_loaded()
	return _errors.duplicate()


func table_keys() -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	if not _valid:
		return out
	for table_key in EnumSkill.LOAD_ORDER:
		out.append(table_key)
	return out


func definitions_in_table(table_key: String) -> Array:
	_ensure_loaded()
	if not _valid:
		return []
	var rows_v: Variant = _tables.get(table_key.strip_edges(), [])
	return (rows_v as Array).duplicate(true) if rows_v is Array else []


func all_definitions() -> Array:
	_ensure_loaded()
	return _definitions.duplicate(true) if _valid else []


func by_id(ability_id: String) -> Dictionary:
	_ensure_loaded()
	if not _valid:
		return {}
	var row_v: Variant = _by_id.get(ability_id.strip_edges())
	return (row_v as Dictionary).duplicate(true) if row_v is Dictionary else {}


func table_key_for(ability_id: String) -> String:
	_ensure_loaded()
	return str(_table_by_id.get(ability_id.strip_edges(), "")) if _valid else ""


static func validate_roots(
		active_root: Variant,
		passive_root: Variant,
		paths: Dictionary = {}
) -> PackedStringArray:
	var resolved_paths := _resolved_paths(paths)
	var errors: PackedStringArray = []
	_validate_raw_root(EnumSkill.LABEL_ZHANDOU_ACTIVE, active_root, str(resolved_paths[EnumSkill.LABEL_ZHANDOU_ACTIVE]), errors)
	_validate_raw_root(EnumSkill.LABEL_PASSIVE, passive_root, str(resolved_paths[EnumSkill.LABEL_PASSIVE]), errors)
	if not errors.is_empty():
		return errors
	var normalized := _normalize_roots(active_root as Dictionary, passive_root as Dictionary)
	_validate_normalized_tables(normalized, true, resolved_paths, errors)
	return errors


func _ensure_loaded() -> void:
	if not _load_attempted:
		reload()


func _commit_roots(
		active_root: Variant,
		passive_root: Variant,
		enforce_counts: bool,
		paths: Dictionary
) -> bool:
	var errors: PackedStringArray = []
	_validate_raw_root(EnumSkill.LABEL_ZHANDOU_ACTIVE, active_root, str(paths[EnumSkill.LABEL_ZHANDOU_ACTIVE]), errors)
	_validate_raw_root(EnumSkill.LABEL_PASSIVE, passive_root, str(paths[EnumSkill.LABEL_PASSIVE]), errors)
	if not errors.is_empty():
		return _reject(errors)
	var candidate_tables := _normalize_roots(active_root as Dictionary, passive_root as Dictionary)
	_validate_normalized_tables(candidate_tables, enforce_counts, paths, errors)
	if not errors.is_empty():
		return _reject(errors)
	var candidate_definitions: Array = []
	var candidate_by_id: Dictionary = {}
	var candidate_table_by_id: Dictionary = {}
	for table_key in EnumSkill.LOAD_ORDER:
		for row_v in candidate_tables.get(table_key, []) as Array:
			var row := row_v as Dictionary
			var ability_id := str(row["id"])
			candidate_definitions.append(row.duplicate(true))
			candidate_by_id[ability_id] = row.duplicate(true)
			candidate_table_by_id[ability_id] = table_key
	_tables = candidate_tables.duplicate(true)
	_definitions = candidate_definitions.duplicate(true)
	_by_id = candidate_by_id.duplicate(true)
	_table_by_id = candidate_table_by_id.duplicate(true)
	_errors.clear()
	_valid = true
	return true


static func _normalize_roots(active_root: Dictionary, passive_root: Dictionary) -> Dictionary:
	var out := {}
	for table_key in EnumSkill.LOAD_ORDER:
		var root := active_root if table_key == EnumSkill.LABEL_ZHANDOU_ACTIVE else passive_root
		var rows := AbilityExportAdapterScript.normalize_table_rows(table_key, root)
		rows.sort_custom(_compare_definition_ids)
		out[table_key] = rows
	return out


static func _validate_raw_root(
		table_key: String,
		root_v: Variant,
		path: String,
		errors: PackedStringArray
) -> void:
	if not root_v is Dictionary:
		errors.append(_message("invalid_root", path, table_key, "root"))
		return
	var root := root_v as Dictionary
	if root.is_empty():
		errors.append(_message("empty_root", path, table_key, "root"))
		return
	if root.has("abilities"):
		errors.append(_message("legacy_wrapper", path, table_key, "root.abilities"))
		return
	for key_v in root.keys():
		var key := str(key_v).strip_edges()
		var row_v: Variant = root[key_v]
		if key == "":
			errors.append(_message("empty_key", path, table_key, "root"))
			continue
		if not row_v is Dictionary:
			errors.append(_message("invalid_row", path, table_key, key))
			continue
		var row := row_v as Dictionary
		if not row.get("id") is String or str(row.get("id", "")).strip_edges() == "":
			errors.append(_message("invalid_id", path, table_key, "%s.id" % key))
		elif str(row.get("id")).strip_edges() != key:
			errors.append(_message("id_mismatch", path, table_key, "%s.id" % key))
		_validate_raw_row(table_key, key, row, path, errors)


static func _validate_raw_row(
		table_key: String,
		row_key: String,
		row: Dictionary,
		path: String,
		errors: PackedStringArray
) -> void:
	_required_string(row, "name", path, table_key, "%s.name" % row_key, errors)
	for field in ["tier", "quality"]:
		if not _is_integer_number(row.get(field)):
			errors.append(_message("invalid_integer", path, table_key, "%s.%s" % [row_key, field]))
	_validate_raw_effects(row.get("effects"), path, table_key, "%s.effects" % row_key, errors)
	if table_key == EnumSkill.LABEL_ZHANDOU_ACTIVE:
		for field in ["type", "req_realm", "description", "target", "cost_resource"]:
			_required_string(row, field, path, table_key, "%s.%s" % [row_key, field], errors)
		for field in ["cast_time", "cooldown", "cost_value"]:
			if not _is_number(row.get(field)):
				errors.append(_message("invalid_number", path, table_key, "%s.%s" % [row_key, field]))
		for field in ["icon", "tags", "vfx_preset", "activation"]:
			var value: Variant = row.get(field)
			if value != null and not value is String and not (field == "tags" and value is Array):
				errors.append(_message("invalid_optional_field", path, table_key, "%s.%s" % [row_key, field]))
	else:
		for field in ["desc", "runtype"]:
			_required_string(row, field, path, table_key, "%s.%s" % [row_key, field], errors)
		if not _is_integer_number(row.get("type")):
			errors.append(_message("invalid_integer", path, table_key, "%s.type" % row_key))
		if row.get("cd") != null and not _is_number(row.get("cd")):
			errors.append(_message("invalid_number", path, table_key, "%s.cd" % row_key))
		if not row.get("tag") is Array:
			errors.append(_message("invalid_array", path, table_key, "%s.tag" % row_key))
		if row.get("icon") != null and not row.get("icon") is String:
			errors.append(_message("invalid_optional_field", path, table_key, "%s.icon" % row_key))


static func _validate_raw_effects(
		value: Variant,
		path: String,
		table_key: String,
		field: String,
		errors: PackedStringArray
) -> void:
	if not value is Array or (value as Array).is_empty():
		errors.append(_message("invalid_effects", path, table_key, field))
		return
	for index in (value as Array).size():
		var effect_v: Variant = (value as Array)[index]
		if not effect_v is Array or (effect_v as Array).is_empty() \
				or not (effect_v as Array)[0] is String \
				or str((effect_v as Array)[0]).strip_edges() == "":
			errors.append(_message("invalid_effect_row", path, table_key, "%s[%d]" % [field, index]))


static func _validate_normalized_tables(
		tables: Dictionary,
		enforce_counts: bool,
		paths: Dictionary,
		errors: PackedStringArray
) -> void:
	var seen := {}
	for table_key in EnumSkill.LOAD_ORDER:
		var rows_v: Variant = tables.get(table_key)
		var path := str(paths.get(table_key, "fixture://%s.json" % table_key))
		if not rows_v is Array or (rows_v as Array).is_empty():
			errors.append(_message("empty_table", path, table_key, "root"))
			continue
		for index in (rows_v as Array).size():
			var row_v: Variant = (rows_v as Array)[index]
			if not row_v is Dictionary:
				errors.append(_message("invalid_normalized_row", path, table_key, "normalized[%d]" % index))
				continue
			var row := row_v as Dictionary
			var ability_id := str(row.get("id", "")).strip_edges()
			if ability_id == "":
				errors.append(_message("invalid_normalized_id", path, table_key, "normalized[%d].id" % index))
			elif seen.has(ability_id):
				errors.append(_message("duplicate_id", path, table_key, ability_id))
			seen[ability_id] = true
			if not row.get("name") is String or str(row.get("name", "")).strip_edges() == "":
				errors.append(_message("invalid_name", path, table_key, "%s.name" % ability_id))
			if not row.get("type") is String or str(row.get("type", "")).strip_edges() == "":
				errors.append(_message("invalid_type", path, table_key, "%s.type" % ability_id))
			if not row.get("combat") is Dictionary:
				errors.append(_message("invalid_combat", path, table_key, "%s.combat" % ability_id))
			if not row.get("effects") is Array:
				errors.append(_message("invalid_effects", path, table_key, "%s.effects" % ability_id))
	if enforce_counts:
		if (tables.get(EnumSkill.LABEL_ZHANDOU_ACTIVE, []) as Array).size() != EXPECTED_ACTIVE_COUNT:
			errors.append(_message("active_count", str(paths[EnumSkill.LABEL_ZHANDOU_ACTIVE]), EnumSkill.LABEL_ZHANDOU_ACTIVE, "root"))
		if (tables.get(EnumSkill.LABEL_PASSIVE, []) as Array).size() != EXPECTED_PASSIVE_COUNT:
			errors.append(_message("passive_count", str(paths[EnumSkill.LABEL_PASSIVE]), EnumSkill.LABEL_PASSIVE, "root"))


static func _compare_definition_ids(left_v: Variant, right_v: Variant) -> bool:
	var left := left_v as Dictionary
	var right := right_v as Dictionary
	return ExportTableReaderScript.compare_keys(left.get("id", ""), right.get("id", ""))


func _reject(errors: PackedStringArray) -> bool:
	_errors = errors.duplicate()
	for message in _errors:
		push_error(message)
	return false


static func _required_string(
		row: Dictionary,
		field: String,
		path: String,
		table_key: String,
		qualified_field: String,
		errors: PackedStringArray
) -> void:
	if not row.get(field) is String or str(row.get(field)).strip_edges() == "":
		errors.append(_message("required_string", path, table_key, qualified_field))


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _is_integer_number(value: Variant) -> bool:
	return value is int or (value is float and is_equal_approx(float(value), roundf(float(value))))


static func _resolved_paths(paths: Dictionary) -> Dictionary:
	var active_path := str(paths.get("active", "fixture://zhandou_active.json"))
	var passive_path := str(paths.get("passive", "fixture://passive.json"))
	return {
		EnumSkill.LABEL_ZHANDOU_ACTIVE: active_path,
		EnumSkill.LABEL_PASSIVE: passive_path,
	}


static func _message(code: String, path: String, table_key: String, field: String) -> String:
	return "[ability_catalog:%s] file=%s table=%s field=%s" % [code, path, table_key, field]
