class_name DaoTreeCatalog
extends RefCounted

const SETTINGS_PATH := "res://data/exportjson/dao_tree.json"
const METADATA_PATH := "res://data/exportjson/dao_tree_metadata.json"
const TRAINING_PATH := "res://data/exportjson/dao_tree_training.json"
const ATTRIBUTES_PATH := "res://data/exportjson/dao_tree_attributes.json"
const REALMS_PATH := "res://data/exportjson/dao_tree_realms.json"
const GROUPS_PATH := "res://data/exportjson/dao_tree_domainGroups.json"
const DOMAINS_PATH := "res://data/exportjson/dao_tree_domains.json"
const SKILLS_PATH := "res://data/exportjson/dao_tree_skills.json"

const TABLES := ["settings", "metadata", "training", "attributes", "realms", "groups", "domains", "skills"]
const EXPECTED_COUNTS := {
	"settings": 2, "metadata": 3, "training": 1, "attributes": 5,
	"realms": 9, "groups": 1, "domains": 3, "skills": 35,
}
const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")
const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")

var _paths: Dictionary
var _load_attempted := false
var _valid := false
var _errors: PackedStringArray = []
var _snapshot: Dictionary = {}


func _init(paths: Dictionary = {}) -> void:
	_paths = _resolved_paths(paths)


func reload() -> bool:
	_load_attempted = true
	var roots: Dictionary = {}
	var errors: PackedStringArray = []
	for table in TABLES:
		var path := str(_paths[table])
		var root_v: Variant = JsonReaderScript.read_variant(path)
		if root_v == null:
			errors.append(_message("unreadable_file", path, table, "root"))
		elif not root_v is Dictionary:
			errors.append(_message("invalid_root", path, table, "root"))
		else:
			roots[table] = root_v
	if not errors.is_empty():
		return _reject(errors)
	return reload_from_roots(roots, _paths)


func reload_from_roots(roots: Variant, paths: Dictionary = {}) -> bool:
	_load_attempted = true
	var resolved := _resolved_paths(paths)
	if not roots is Dictionary:
		return _reject(PackedStringArray([_message("invalid_roots", "fixture", "all", "root")]))
	var errors := validate_roots(roots as Dictionary, resolved)
	if not errors.is_empty():
		return _reject(errors)
	var candidate := _decode_roots(roots as Dictionary)
	_snapshot = candidate.duplicate(true)
	_errors.clear()
	_valid = true
	return true


func snapshot() -> Dictionary:
	_ensure_loaded()
	return _snapshot.duplicate(true) if _valid else {}


func collect_errors() -> PackedStringArray:
	_ensure_loaded()
	return _errors.duplicate()


func metadata() -> Dictionary:
	return _dictionary("metadata")


func training() -> Dictionary:
	return _dictionary("training")


func attributes() -> Dictionary:
	return _dictionary("attributes")


func all_skills() -> Array:
	return _rows("skills")


func domains() -> Array:
	return _rows("domains")


func domain_groups() -> Array:
	return _rows("domain_groups")


func realms() -> Array:
	return _rows("realms")


func skill_by_id(skill_id: String) -> Dictionary:
	return _row_by_id(all_skills(), skill_id)


func skills_in_domain(domain_id: String) -> Array:
	return _rows_matching(all_skills(), "domain", domain_id)


func skills_in_realm(realm_id: String) -> Array:
	return _rows_matching(all_skills(), "realm", realm_id)


func domain_by_id(domain_id: String) -> Dictionary:
	return _row_by_id(domains(), domain_id)


func realm_by_id(realm_id: String) -> Dictionary:
	return _row_by_id(realms(), realm_id)


func realm_display_name(realm_id: String) -> String:
	var rid := realm_id.strip_edges()
	if rid == "":
		return ""
	var realm := realm_by_id(rid)
	return str(realm.get("name", rid))


func realm_order(realm_id: String) -> int:
	return int(realm_by_id(realm_id).get("order", 0))


static func validate_roots(roots: Dictionary, paths: Dictionary = {}) -> PackedStringArray:
	var resolved := _resolved_paths(paths)
	var errors: PackedStringArray = []
	for table in TABLES:
		if not roots.get(table) is Dictionary:
			errors.append(_message("invalid_root", str(resolved[table]), table, "root"))
	if not errors.is_empty():
		return errors
	for table in TABLES:
		var root := roots[table] as Dictionary
		if root.size() != int(EXPECTED_COUNTS[table]):
			errors.append(_message("row_count", str(resolved[table]), table, "root"))
	_validate_settings(roots.settings as Dictionary, resolved, errors)
	_validate_metadata(roots.metadata as Dictionary, resolved, errors)
	_validate_training(roots.training as Dictionary, resolved, errors)
	_validate_attributes(roots.attributes as Dictionary, resolved, errors)
	_validate_rows(roots.realms as Dictionary, "realms", resolved, errors)
	_validate_rows(roots.groups as Dictionary, "groups", resolved, errors)
	_validate_rows(roots.domains as Dictionary, "domains", resolved, errors)
	_validate_rows(roots.skills as Dictionary, "skills", resolved, errors)
	_validate_references(roots, resolved, errors)
	return errors


func _ensure_loaded() -> void:
	if not _load_attempted:
		reload()


func _reject(errors: PackedStringArray) -> bool:
	_errors = errors.duplicate()
	for message in _errors:
		push_error(message)
	return false


func _dictionary(key: String) -> Dictionary:
	_ensure_loaded()
	var value: Variant = _snapshot.get(key, {})
	return (value as Dictionary).duplicate(true) if _valid and value is Dictionary else {}


func _rows(key: String) -> Array:
	_ensure_loaded()
	var value: Variant = _snapshot.get(key, [])
	return (value as Array).duplicate(true) if _valid and value is Array else []


static func _decode_roots(roots: Dictionary) -> Dictionary:
	var settings := _settings(roots.settings as Dictionary)
	return {
		"schemaVersion": int(settings.get("schemaVersion", 0)),
		"configId": str(settings.get("configId", "")),
		"metadata": _settings(roots.metadata as Dictionary),
		"training": _keyed_rows(roots.training as Dictionary),
		"attributes": _settings(roots.attributes as Dictionary),
		"realms": _row_array(roots.realms as Dictionary),
		"domain_groups": _row_array(roots.groups as Dictionary),
		"domains": _row_array(roots.domains as Dictionary),
		"skills": _row_array(roots.skills as Dictionary),
	}


static func _settings(root: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key_v in root.keys():
		var row_v: Variant = root[key_v]
		if row_v is Dictionary:
			out[str(key_v)] = _coerce((row_v as Dictionary).get("value"))
	return out


static func _keyed_rows(root: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = root.keys()
	keys.sort_custom(ExportTableReaderScript.compare_keys)
	for key_v in keys:
		out[str(key_v)] = _decode_value(root[key_v])
	return out


static func _row_array(root: Dictionary) -> Array:
	var keys: Array = root.keys()
	keys.sort_custom(ExportTableReaderScript.compare_keys)
	var out: Array = []
	for key_v in keys:
		out.append(_decode_value(root[key_v]))
	return out


static func _decode_value(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		for key_v in (value as Dictionary).keys():
			var cell: Variant = (value as Dictionary)[key_v]
			if cell != null:
				out[key_v] = _decode_value(cell)
		return out
	if value is Array:
		var out: Array = []
		for cell in value as Array:
			out.append(_decode_value(cell))
		return out
	if value is String:
		var text := str(value).strip_edges()
		if text.begins_with("{") or text.begins_with("["):
			var parsed: Variant = JSON.parse_string(text)
			if parsed is Dictionary or parsed is Array:
				return _decode_value(parsed)
	return value


static func _coerce(value: Variant) -> Variant:
	if not value is String:
		return value
	var text := str(value).strip_edges()
	if text.is_valid_int():
		return int(text)
	if text.is_valid_float():
		return float(text)
	if text.to_lower() == "true" or text.to_lower() == "false":
		return text.to_lower() == "true"
	return text


static func _validate_settings(root: Dictionary, paths: Dictionary, errors: PackedStringArray) -> void:
	_validate_setting_rows(root, "settings", paths, errors)
	if int(_setting_value(root, "schemaVersion")) != 1:
		errors.append(_message("schema_version", str(paths.settings), "settings", "schemaVersion.value"))
	if str(_setting_value(root, "configId")) != "dao_tree":
		errors.append(_message("config_id", str(paths.settings), "settings", "configId.value"))


static func _validate_metadata(root: Dictionary, paths: Dictionary, errors: PackedStringArray) -> void:
	_validate_setting_rows(root, "metadata", paths, errors)
	for key in ["name", "description"]:
		if str(_setting_value(root, key)).strip_edges() == "":
			errors.append(_message("required_string", str(paths.metadata), "metadata", key + ".value"))
	if int(_setting_value(root, "skillCount")) != int(EXPECTED_COUNTS.skills):
		errors.append(_message("skill_count", str(paths.metadata), "metadata", "skillCount.value"))


static func _validate_training(root: Dictionary, paths: Dictionary, errors: PackedStringArray) -> void:
	var base_v: Variant = root.get("base")
	if not base_v is Dictionary:
		errors.append(_message("invalid_row", str(paths.training), "training", "base"))
		return
	var base := base_v as Dictionary
	if str(base.get("key", "")) != "base":
		errors.append(_message("key_mismatch", str(paths.training), "training", "base.key"))
	for field in ["maxLevel", "basePoints"]:
		if not _is_number(base.get(field)) or float(base.get(field, 0)) <= 0.0:
			errors.append(_message("invalid_number", str(paths.training), "training", "base." + field))
	var multipliers_v: Variant = base.get("levelMultipliers")
	if not multipliers_v is Array or (multipliers_v as Array).size() != int(base.get("maxLevel", 0)):
		errors.append(_message("level_multipliers", str(paths.training), "training", "base.levelMultipliers"))
	elif (multipliers_v as Array).any(func(v: Variant) -> bool: return not _is_number(v) or float(v) <= 0.0):
		errors.append(_message("level_multipliers", str(paths.training), "training", "base.levelMultipliers"))
	for field in ["speedFormula", "pointsFormula"]:
		if str(base.get(field, "")).strip_edges() == "":
			errors.append(_message("required_string", str(paths.training), "training", "base." + field))


static func _validate_attributes(root: Dictionary, paths: Dictionary, errors: PackedStringArray) -> void:
	_validate_setting_rows(root, "attributes", paths, errors)
	for key_v in root.keys():
		if str(_setting_value(root, str(key_v))).strip_edges() == "":
			errors.append(_message("required_string", str(paths.attributes), "attributes", str(key_v) + ".value"))


static func _validate_setting_rows(root: Dictionary, table: String, paths: Dictionary, errors: PackedStringArray) -> void:
	for key_v in root.keys():
		var key := str(key_v)
		var row_v: Variant = root[key_v]
		if not row_v is Dictionary:
			errors.append(_message("invalid_row", str(paths[table]), table, key))
		elif str((row_v as Dictionary).get("key", "")) != key or not (row_v as Dictionary).has("value"):
			errors.append(_message("key_mismatch", str(paths[table]), table, key + ".key"))


static func _validate_rows(root: Dictionary, table: String, paths: Dictionary, errors: PackedStringArray) -> void:
	var seen: Dictionary = {}
	for key_v in root.keys():
		var key := str(key_v)
		var row_v: Variant = root[key_v]
		if not row_v is Dictionary:
			errors.append(_message("invalid_row", str(paths[table]), table, key))
			continue
		var row := row_v as Dictionary
		var row_id := str(row.get("id", "")).strip_edges()
		if row_id != key:
			errors.append(_message("id_mismatch", str(paths[table]), table, key + ".id"))
		if seen.has(row_id):
			errors.append(_message("duplicate_id", str(paths[table]), table, key + ".id"))
		seen[row_id] = true
		if str(row.get("name", "")).strip_edges() == "":
			errors.append(_message("required_string", str(paths[table]), table, key + ".name"))


static func _validate_references(roots: Dictionary, paths: Dictionary, errors: PackedStringArray) -> void:
	var domains := roots.domains as Dictionary
	var realms := roots.realms as Dictionary
	var orders: Dictionary = {}
	for key_v in realms.keys():
		var realm_v: Variant = realms[key_v]
		if not realm_v is Dictionary:
			continue
		var realm := realm_v as Dictionary
		if not _is_number(realm.get("order")) or int(realm.get("order", 0)) <= 0:
			errors.append(_message("realm_order", str(paths.realms), "realms", str(key_v) + ".order"))
		elif orders.has(int(realm.order)):
			errors.append(_message("duplicate_realm_order", str(paths.realms), "realms", str(key_v) + ".order"))
		else:
			orders[int(realm.order)] = true
	for key_v in (roots.groups as Dictionary).keys():
		var row_v: Variant = (roots.groups as Dictionary)[key_v]
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		var refs_v: Variant = row.get("domains")
		if not refs_v is Array or (refs_v as Array).is_empty():
			errors.append(_message("group_domains", str(paths.groups), "groups", str(key_v) + ".domains"))
		else:
			for ref_v in refs_v as Array:
				if not domains.has(str(ref_v)):
					errors.append(_message("unknown_domain", str(paths.groups), "groups", str(key_v) + ".domains"))
	for key_v in (roots.skills as Dictionary).keys():
		var row_v: Variant = (roots.skills as Dictionary)[key_v]
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		for field in ["domain", "realm", "description"]:
			if str(row.get(field, "")).strip_edges() == "":
				errors.append(_message("required_string", str(paths.skills), "skills", "%s.%s" % [key_v, field]))
		if not domains.has(str(row.get("domain", ""))):
			errors.append(_message("unknown_domain", str(paths.skills), "skills", str(key_v) + ".domain"))
		if not realms.has(str(row.get("realm", ""))):
			errors.append(_message("unknown_realm", str(paths.skills), "skills", str(key_v) + ".realm"))
		for field in ["tier", "rank", "quality", "maxLevel"]:
			if not _is_number(row.get(field)) or int(row.get(field, 0)) < 1:
				errors.append(_message("invalid_number", str(paths.skills), "skills", "%s.%s" % [key_v, field]))
		var prereqs_v: Variant = row.get("prereqs")
		if not prereqs_v is Array:
			errors.append(_message("invalid_prereqs", str(paths.skills), "skills", str(key_v) + ".prereqs"))
		else:
			for req_v in prereqs_v as Array:
				if not req_v is Dictionary or not (roots.skills as Dictionary).has(str((req_v as Dictionary).get("id", ""))) \
						or not _is_number((req_v as Dictionary).get("level")):
					errors.append(_message("invalid_prereq", str(paths.skills), "skills", str(key_v) + ".prereqs"))


static func _setting_value(root: Dictionary, key: String) -> Variant:
	var row_v: Variant = root.get(key)
	return _coerce((row_v as Dictionary).get("value")) if row_v is Dictionary else null


static func _row_by_id(rows: Array, target_id: String) -> Dictionary:
	var target := target_id.strip_edges()
	for row_v in rows:
		if row_v is Dictionary and str((row_v as Dictionary).get("id", "")) == target:
			return (row_v as Dictionary).duplicate(true)
	return {}


static func _rows_matching(rows: Array, field: String, value: String) -> Array:
	var target := value.strip_edges()
	var out: Array = []
	for row_v in rows:
		if row_v is Dictionary and str((row_v as Dictionary).get(field, "")) == target:
			out.append((row_v as Dictionary).duplicate(true))
	return out


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _resolved_paths(paths: Dictionary) -> Dictionary:
	return {
		"settings": str(paths.get("settings", SETTINGS_PATH)),
		"metadata": str(paths.get("metadata", METADATA_PATH)),
		"training": str(paths.get("training", TRAINING_PATH)),
		"attributes": str(paths.get("attributes", ATTRIBUTES_PATH)),
		"realms": str(paths.get("realms", REALMS_PATH)),
		"groups": str(paths.get("groups", GROUPS_PATH)),
		"domains": str(paths.get("domains", DOMAINS_PATH)),
		"skills": str(paths.get("skills", SKILLS_PATH)),
	}


static func _message(code: String, path: String, table: String, field: String) -> String:
	return "[dao_tree_catalog:%s] path=%s table=%s field=%s" % [code, path, table, field]
