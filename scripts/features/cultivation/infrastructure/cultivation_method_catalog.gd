class_name CultivationMethodCatalog
extends RefCounted

const SETTINGS_PATH := "res://data/exportjson/xiulian_methods.json"
const METADATA_PATH := "res://data/exportjson/xiulian_methods_metadata.json"
const FAMILIES_PATH := "res://data/exportjson/xiulian_methods_families.json"
const METHODS_PATH := "res://data/exportjson/xiulian_methods_methods.json"
const EFFECT_CATALOG_PATH := "res://data/exportjson/xiulian_methods_effectCatalog.json"
const SCHEMA_VERSION := 2
const CONFIG_ID := "cultivation_methods"
const EXPECTED_FAMILY_COUNT := 15
const EXPECTED_METHOD_COUNT := 83
const EXPECTED_EFFECT_COUNT := 175

const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")
const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")

var _paths: Dictionary
var _load_attempted := false
var _valid := false
var _errors: PackedStringArray = []
var _settings: Dictionary = {}
var _metadata: Dictionary = {}
var _families_by_id: Dictionary = {}
var _methods_by_id: Dictionary = {}
var _method_ids: Array = []
var _effects_by_id: Dictionary = {}


func _init(paths: Dictionary = {}) -> void:
	_paths = {
		"settings": str(paths.get("settings", SETTINGS_PATH)),
		"metadata": str(paths.get("metadata", METADATA_PATH)),
		"families": str(paths.get("families", FAMILIES_PATH)),
		"methods": str(paths.get("methods", METHODS_PATH)),
		"effects": str(paths.get("effects", EFFECT_CATALOG_PATH)),
	}


func all_definitions() -> Array:
	_ensure_loaded()
	if not _valid:
		return []
	var out: Array = []
	for method_id_v in _method_ids:
		out.append((_methods_by_id[method_id_v] as Dictionary).duplicate(true))
	return out


func definition_by_id(method_id: String) -> Dictionary:
	_ensure_loaded()
	if not _valid:
		return {}
	var row_v: Variant = _methods_by_id.get(method_id.strip_edges())
	return (row_v as Dictionary).duplicate(true) if row_v is Dictionary else {}


func family_by_id(family_id: String) -> Dictionary:
	_ensure_loaded()
	if not _valid:
		return {}
	var row_v: Variant = _families_by_id.get(family_id.strip_edges())
	return (row_v as Dictionary).duplicate(true) if row_v is Dictionary else {}


func collect_errors() -> PackedStringArray:
	_ensure_loaded()
	return _errors.duplicate()


static func validate_tables(
		settings: Dictionary,
		metadata: Dictionary,
		families: Dictionary,
		methods: Dictionary,
		effects: Dictionary,
		paths: Dictionary = {}
) -> PackedStringArray:
	var resolved_paths := {
		"settings": str(paths.get("settings", SETTINGS_PATH)),
		"metadata": str(paths.get("metadata", METADATA_PATH)),
		"families": str(paths.get("families", FAMILIES_PATH)),
		"methods": str(paths.get("methods", METHODS_PATH)),
		"effects": str(paths.get("effects", EFFECT_CATALOG_PATH)),
	}
	var errors: PackedStringArray = []
	_validate_settings(settings, resolved_paths.settings, errors)
	_validate_metadata(metadata, resolved_paths.metadata, errors)
	_validate_row_counts(families, methods, effects, resolved_paths, errors)
	var family_index := _validate_families(families, resolved_paths.families, errors)
	var effect_aliases := _validate_effect_catalog(effects, resolved_paths.effects, errors)
	var method_index := _validate_methods(methods, effects, effect_aliases, resolved_paths.methods, errors)
	_validate_references(family_index, method_index, resolved_paths, errors)
	return errors


func _ensure_loaded() -> void:
	if _load_attempted:
		return
	_load_attempted = true
	for key_v in _paths.keys():
		var key := str(key_v)
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
	var settings := ExportTableReaderScript.read_settings(str(_paths.settings))
	var metadata := ExportTableReaderScript.read_settings(str(_paths.metadata))
	var families := ExportTableReaderScript.read_keyed_rows(str(_paths.families))
	var methods := ExportTableReaderScript.read_keyed_rows(str(_paths.methods))
	var effects := ExportTableReaderScript.read_keyed_rows(str(_paths.effects))
	_errors = validate_tables(settings, metadata, families, methods, effects, _paths)
	if not _errors.is_empty():
		for message in _errors:
			push_error(message)
		_clear()
		return
	_settings = settings.duplicate(true)
	_metadata = metadata.duplicate(true)
	_families_by_id = _index_rows(families)
	_methods_by_id = _index_rows(methods)
	_effects_by_id = effects.duplicate(true)
	_method_ids = methods.keys()
	_method_ids.sort_custom(ExportTableReaderScript.compare_keys)
	_valid = true


func _fail(code: String, path: String, field: String) -> void:
	_errors.append(_message(code, path, field))
	push_error(_errors[-1])
	_clear()


func _clear() -> void:
	_valid = false
	_settings.clear()
	_metadata.clear()
	_families_by_id.clear()
	_methods_by_id.clear()
	_method_ids.clear()
	_effects_by_id.clear()


static func _validate_settings(table: Dictionary, path: String, errors: PackedStringArray) -> void:
	if not _is_integer_number(table.get("schemaVersion")):
		errors.append(_message("schema_version_type", path, "schemaVersion"))
	elif int(table.schemaVersion) != SCHEMA_VERSION:
		errors.append(_message("schema_version_unsupported", path, "schemaVersion"))
	if not table.get("configId") is String or str(table.configId).strip_edges() != CONFIG_ID:
		errors.append(_message("config_id_invalid", path, "configId"))


static func _validate_metadata(table: Dictionary, path: String, errors: PackedStringArray) -> void:
	for field in ["name", "description"]:
		_required_string(table, field, path, field, errors)
	for field in ["familyCount", "methodCount", "effectTypeCount"]:
		if not _is_integer_number(table.get(field)):
			errors.append(_message("metadata_count_type", path, field))
	var expected := {
		"familyCount": EXPECTED_FAMILY_COUNT,
		"methodCount": EXPECTED_METHOD_COUNT,
		"effectTypeCount": EXPECTED_EFFECT_COUNT,
	}
	for field_v in expected.keys():
		var field := str(field_v)
		if _is_integer_number(table.get(field)) and int(table[field]) != int(expected[field]):
			errors.append(_message("metadata_count_mismatch", path, field))


static func _validate_row_counts(
		families: Dictionary,
		methods: Dictionary,
		effects: Dictionary,
		paths: Dictionary,
		errors: PackedStringArray
) -> void:
	for spec in [
		["families", families.size(), EXPECTED_FAMILY_COUNT],
		["methods", methods.size(), EXPECTED_METHOD_COUNT],
		["effects", effects.size(), EXPECTED_EFFECT_COUNT],
	]:
		if int(spec[1]) != int(spec[2]):
			errors.append(_message("row_count_mismatch", str(paths[spec[0]]), "root"))


static func _validate_families(rows: Dictionary, path: String, errors: PackedStringArray) -> Dictionary:
	var index: Dictionary = {}
	for key_v in rows.keys():
		var key := str(key_v).strip_edges()
		var row_v: Variant = rows[key_v]
		if key == "" or not row_v is Dictionary:
			errors.append(_message("invalid_family_row", path, key if key != "" else "root"))
			continue
		var row := row_v as Dictionary
		_validate_key_and_id(key, row, path, errors)
		for field in ["name", "role"]:
			_required_string(row, field, path, "%s.%s" % [key, field], errors)
		if not _is_integer_number(row.get("quality")) or int(row.get("quality", 0)) < 1:
			errors.append(_message("quality_invalid", path, "%s.quality" % key))
		_validate_non_empty_unique_string_array(row.get("methodIds"), path, "%s.methodIds" % key, errors)
		if row.has("progressionType") and row.progressionType != null \
				and (not row.progressionType is String or str(row.progressionType).strip_edges() == ""):
			errors.append(_message("progression_type_invalid", path, "%s.progressionType" % key))
		var row_id := str(row.get("id", "")).strip_edges()
		if row_id != "":
			if index.has(row_id):
				errors.append(_message("duplicate_family_id", path, "%s.id" % key))
			index[row_id] = row
	return index


static func _validate_effect_catalog(rows: Dictionary, path: String, errors: PackedStringArray) -> Dictionary:
	var aliases: Dictionary = {}
	for key_v in rows.keys():
		var key := str(key_v).strip_edges()
		var row_v: Variant = rows[key_v]
		if key == "" or not row_v is Dictionary:
			errors.append(_message("invalid_effect_row", path, key if key != "" else "root"))
			continue
		var row := row_v as Dictionary
		if not row.get("key") is String or str(row.key).strip_edges() != key:
			errors.append(_message("row_key_mismatch", path, "%s.key" % key))
		for field in ["category", "defaultTarget", "runtimeKey", "description"]:
			_required_string(row, field, path, "%s.%s" % [key, field], errors)
		_register_effect_alias(aliases, key, key, path, errors)
		var runtime_key := str(row.get("runtimeKey", "")).strip_edges()
		if runtime_key != "":
			_register_effect_alias(aliases, runtime_key, key, path, errors)
	return aliases


static func _register_effect_alias(
		aliases: Dictionary,
		alias: String,
		catalog_key: String,
		path: String,
		errors: PackedStringArray
) -> void:
	if aliases.has(alias) and str(aliases[alias]) != catalog_key:
		errors.append(_message("effect_alias_conflict", path, alias))
		return
	aliases[alias] = catalog_key


static func _validate_methods(
		rows: Dictionary,
		effect_rows: Dictionary,
		effect_aliases: Dictionary,
		path: String,
		errors: PackedStringArray
) -> Dictionary:
	var index: Dictionary = {}
	for key_v in rows.keys():
		var key := str(key_v).strip_edges()
		var row_v: Variant = rows[key_v]
		if key == "" or not row_v is Dictionary:
			errors.append(_message("invalid_method_row", path, key if key != "" else "root"))
			continue
		var row := row_v as Dictionary
		_validate_key_and_id(key, row, path, errors)
		for field in ["name", "familyId", "realm", "description"]:
			_required_string(row, field, path, "%s.%s" % [key, field], errors)
		for field in ["tier", "quality"]:
			if not _is_integer_number(row.get(field)) or int(row.get(field, 0)) < 1:
				errors.append(_message("positive_integer_required", path, "%s.%s" % [key, field]))
		for field in ["predecessorId", "nextMethodId"]:
			if row.has(field) and row[field] != null \
					and (not row[field] is String or str(row[field]).strip_edges() == ""):
				errors.append(_message("method_link_invalid", path, "%s.%s" % [key, field]))
		_validate_practice(row.get("practice"), path, "%s.practice" % key, errors)
		_validate_effects(row.get("effects"), effect_aliases, effect_rows, path, key, errors)
		for field in ["knowledge", "tags", "passive_rules", "synergy_rules"]:
			if not row.get(field) is Array:
				errors.append(_message("array_required", path, "%s.%s" % [key, field]))
		if not row.get("learningRequirements") is Dictionary:
			errors.append(_message("learning_requirements_invalid", path, "%s.learningRequirements" % key))
		var row_id := str(row.get("id", "")).strip_edges()
		if row_id != "":
			if index.has(row_id):
				errors.append(_message("duplicate_method_id", path, "%s.id" % key))
			index[row_id] = row
	return index


static func _validate_practice(value: Variant, path: String, field: String, errors: PackedStringArray) -> void:
	if not value is Dictionary:
		errors.append(_message("practice_invalid", path, field))
		return
	for number_field in ["efficiency", "deviationRisk"]:
		if not _is_number((value as Dictionary).get(number_field)):
			errors.append(_message("numeric_required", path, "%s.%s" % [field, number_field]))


static func _validate_effects(
		value: Variant,
		effect_aliases: Dictionary,
		effect_rows: Dictionary,
		path: String,
		method_id: String,
		errors: PackedStringArray
) -> void:
	if not value is Array or (value as Array).is_empty():
		errors.append(_message("effects_invalid", path, "%s.effects" % method_id))
		return
	for index in (value as Array).size():
		var effect_v: Variant = (value as Array)[index]
		var field := "%s.effects[%d]" % [method_id, index]
		if not effect_v is Dictionary:
			errors.append(_message("effect_invalid", path, field))
			continue
		var effect := effect_v as Dictionary
		for string_field in ["effectId", "operation", "stackGroup", "stackPolicy", "activation"]:
			_required_string(effect, string_field, path, "%s.%s" % [field, string_field], errors)
		for number_field in ["base", "masteryGrowth"]:
			if not _is_number(effect.get(number_field)):
				errors.append(_message("numeric_required", path, "%s.%s" % [field, number_field]))
		var effect_id := str(effect.get("effectId", "")).strip_edges()
		if effect_id == "" or not effect_aliases.has(effect_id):
			errors.append(_message("effect_reference_unknown", path, "%s.effectId" % field))
		else:
			var catalog_key := str(effect_aliases[effect_id])
			var catalog_row := effect_rows.get(catalog_key, {}) as Dictionary
			var attributes_v: Variant = effect.get("attributes")
			if attributes_v is Dictionary \
					and str((attributes_v as Dictionary).get("target", "")) != str(catalog_row.get("defaultTarget", "")):
				errors.append(_message("effect_target_mismatch", path, "%s.attributes.target" % field))
		_validate_effect_attributes(effect.get("attributes"), path, "%s.attributes" % field, errors)
		if str(effect.get("operation", "")) == "add_percent" and not _is_number(effect.get("cap")):
			errors.append(_message("effect_cap_required", path, "%s.cap" % field))


static func _validate_effect_attributes(value: Variant, path: String, field: String, errors: PackedStringArray) -> void:
	if not value is Dictionary:
		errors.append(_message("effect_attributes_invalid", path, field))
		return
	var attributes := value as Dictionary
	for string_field in ["category", "target", "polarity", "valueType"]:
		_required_string(attributes, string_field, path, "%s.%s" % [field, string_field], errors)
	if not _is_integer_number(attributes.get("displayPriority")):
		errors.append(_message("display_priority_invalid", path, "%s.displayPriority" % field))


static func _validate_references(
		families: Dictionary,
		methods: Dictionary,
		paths: Dictionary,
		errors: PackedStringArray
) -> void:
	var method_membership: Dictionary = {}
	for family_id_v in families.keys():
		var family_id := str(family_id_v)
		var family := families[family_id_v] as Dictionary
		var method_ids_v: Variant = family.get("methodIds")
		if not method_ids_v is Array:
			continue
		var method_ids := method_ids_v as Array
		for index in method_ids.size():
			var method_id := str(method_ids[index])
			if not methods.has(method_id):
				errors.append(_message("family_method_unknown", str(paths.families), "%s.methodIds[%d]" % [family_id, index]))
				continue
			if method_membership.has(method_id):
				errors.append(_message("method_in_multiple_families", str(paths.families), "%s.methodIds[%d]" % [family_id, index]))
			method_membership[method_id] = family_id
			var method := methods[method_id] as Dictionary
			if str(method.get("familyId", "")) != family_id:
				errors.append(_message("method_family_mismatch", str(paths.methods), "%s.familyId" % method_id))
			_validate_family_chain(method_ids, index, method, methods, family_id, paths, errors)
	for method_id_v in methods.keys():
		var method_id := str(method_id_v)
		var method := methods[method_id_v] as Dictionary
		var family_id := str(method.get("familyId", ""))
		if not families.has(family_id):
			errors.append(_message("method_family_unknown", str(paths.methods), "%s.familyId" % method_id))
		if not method_membership.has(method_id):
			errors.append(_message("method_not_in_family", str(paths.methods), method_id))


static func _validate_family_chain(
		method_ids: Array,
		index: int,
		method: Dictionary,
		methods: Dictionary,
		family_id: String,
		paths: Dictionary,
		errors: PackedStringArray
) -> void:
	var method_id := str(method.get("id", ""))
	var expected_prev := str(method_ids[index - 1]) if index > 0 else ""
	var expected_next := str(method_ids[index + 1]) if index + 1 < method_ids.size() else ""
	var actual_prev := str(method.get("predecessorId", "")) if method.get("predecessorId") != null else ""
	var actual_next := str(method.get("nextMethodId", "")) if method.get("nextMethodId") != null else ""
	if actual_prev != expected_prev:
		errors.append(_message("predecessor_mismatch", str(paths.methods), "%s.predecessorId" % method_id))
	if actual_next != expected_next:
		errors.append(_message("next_method_mismatch", str(paths.methods), "%s.nextMethodId" % method_id))
	if expected_prev != "" and methods.has(expected_prev):
		var previous := methods[expected_prev] as Dictionary
		if str(previous.get("familyId", "")) != family_id or int(previous.get("tier", 0)) + 1 != int(method.get("tier", 0)):
			errors.append(_message("family_chain_not_contiguous", str(paths.methods), method_id))
	if expected_next != "" and methods.has(expected_next):
		var next := methods[expected_next] as Dictionary
		if str(next.get("familyId", "")) != family_id or int(method.get("tier", 0)) + 1 != int(next.get("tier", 0)):
			errors.append(_message("family_chain_not_contiguous", str(paths.methods), method_id))


static func _validate_key_and_id(key: String, row: Dictionary, path: String, errors: PackedStringArray) -> void:
	if not row.get("id") is String or str(row.id).strip_edges() != key:
		errors.append(_message("row_key_mismatch", path, "%s.id" % key))


static func _validate_non_empty_unique_string_array(
		value: Variant,
		path: String,
		field: String,
		errors: PackedStringArray
) -> void:
	if not value is Array or (value as Array).is_empty():
		errors.append(_message("string_array_invalid", path, field))
		return
	var seen: Dictionary = {}
	for index in (value as Array).size():
		var cell: Variant = (value as Array)[index]
		if not cell is String or str(cell).strip_edges() == "":
			errors.append(_message("string_entry_invalid", path, "%s[%d]" % [field, index]))
			continue
		var text := str(cell).strip_edges()
		if seen.has(text):
			errors.append(_message("duplicate_id", path, "%s[%d]" % [field, index]))
		seen[text] = true


static func _required_string(
		row: Dictionary,
		field: String,
		path: String,
		qualified_field: String,
		errors: PackedStringArray
) -> void:
	if not row.get(field) is String or str(row.get(field)).strip_edges() == "":
		errors.append(_message("required_string", path, qualified_field))


static func _index_rows(rows: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for row_v in rows.values():
		var row := row_v as Dictionary
		out[str(row.get("id", ""))] = row.duplicate(true)
	return out


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _is_integer_number(value: Variant) -> bool:
	return value is int or (value is float and is_equal_approx(float(value), roundf(float(value))))


static func _message(code: String, path: String, field: String) -> String:
	return "[cultivation_method_catalog:%s] file=%s field=%s" % [code, path, field]
