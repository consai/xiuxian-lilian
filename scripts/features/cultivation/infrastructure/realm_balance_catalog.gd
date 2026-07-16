class_name RealmBalanceCatalog
extends RefCounted

const ACCEPTANCE_PATH := "res://data/exportjson/yunxing_params/jingjie_balance_acceptance.json"
const BENCHMARK_ENEMIES_PATH := "res://data/exportjson/yunxing_params/jingjie_balance_benchmark_ene.json"
const BUDGETS_PATH := "res://data/exportjson/yunxing_params/jingjie_balance_budgets.json"
const COMBAT_ATTRIBUTE_FORMULA_PATH := "res://data/exportjson/yunxing_params/jingjie_balance_combat_attrib.json"
const CULTIVATION_PROGRESSION_PATH := "res://data/exportjson/yunxing_params/jingjie_balance_cultivation_p.json"
const ENCOUNTER_BANDS_PATH := "res://data/exportjson/yunxing_params/jingjie_balance_encounter_ban.json"
const MAJOR_REALMS_PATH := "res://data/exportjson/yunxing_params/jingjie_balance_major_realms.json"
const STANDARD_PLAYERS_PATH := "res://data/exportjson/yunxing_params/jingjie_balance_standard_play.json"

const MAJOR_REALM_IDS := ["lianqi", "zhuji", "jindan", "yuanying", "huashen", "lianxu", "heti", "dacheng", "dujie"]
const REQUIRED_COMBAT_ATTRS := ["hp_max", "mp_max", "physical_atk", "magic_atk", "physical_def", "magic_def", "spd", "control_power", "control_resist", "hp_regen", "mp_regen", "carry", "shield"]
const REQUIRED_ENCOUNTER_BANDS := ["normal", "elite", "boss"]
const REQUIRED_QUALITY_BANDS := ["low", "medium", "high", "supreme"]
const REQUIRED_ACCEPTANCE_KEYS := ["normal_win_rate_min", "normal_win_rate_max", "normal_duration_sec_min", "normal_duration_sec_max", "elite_win_rate_min", "elite_win_rate_max", "lianqi_mature_vs_zhuji_normal_win_rate_max", "resource_remaining_ratio_min", "resource_remaining_ratio_max"]
const REQUIRED_BENCHMARK_KEYS := ["lianqi_normal", "lianqi_elite", "zhuji_normal"]
const REQUIRED_STANDARD_PLAYER_KEYS := ["lianqi_early", "lianqi_mature", "zhuji_early"]

const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")

var _paths: Dictionary
var _load_attempted := false
var _valid := false
var _errors: PackedStringArray = []
var _bundle: Dictionary = {}


func _init(paths: Dictionary = {}) -> void:
	_paths = _resolved_paths(paths)


func reload() -> bool:
	_load_attempted = true
	var raw_roots: Dictionary = {}
	var errors: PackedStringArray = []
	for table_v in _paths.keys():
		var table := str(table_v)
		var path := str(_paths[table])
		var root_v: Variant = JsonReaderScript.read_variant(path)
		if root_v == null:
			errors.append(_message("unreadable_file", path, "root"))
		elif not root_v is Dictionary:
			errors.append(_message("invalid_root", path, "root"))
		else:
			raw_roots[table] = root_v
	if not errors.is_empty():
		return _reject(errors)
	return reload_from_raw_roots(raw_roots, _paths)


func reload_from_raw_roots(raw_roots: Variant, paths: Dictionary = {}) -> bool:
	_load_attempted = true
	var resolved_paths := _resolved_paths(paths)
	if not raw_roots is Dictionary:
		return _reject(PackedStringArray([_message("invalid_raw_roots", "fixture", "root")]))
	var errors: PackedStringArray = []
	for table_v in resolved_paths.keys():
		var table := str(table_v)
		if not (raw_roots as Dictionary).get(table) is Dictionary:
			errors.append(_message("invalid_root", str(resolved_paths[table]), "root"))
	if not errors.is_empty():
		return _reject(errors)
	var candidate := _decode_roots(raw_roots as Dictionary)
	return reload_from_bundle(candidate, resolved_paths)


func reload_from_bundle(candidate: Variant, paths: Dictionary = {}) -> bool:
	_load_attempted = true
	if not candidate is Dictionary:
		return _reject(PackedStringArray([_message("invalid_bundle", "fixture", "root")]))
	var resolved_paths := _resolved_paths(paths)
	var errors := validate_bundle(candidate as Dictionary, resolved_paths)
	if not errors.is_empty():
		return _reject(errors)
	var copied_candidate: Variant = _json_copy(candidate)
	if not copied_candidate is Dictionary:
		return _reject(PackedStringArray([_message("copy_failed", "fixture", "root")]))
	_bundle = copied_candidate as Dictionary
	_errors.clear()
	_valid = true
	return true


func bundle() -> Dictionary:
	_ensure_loaded()
	if not _valid:
		return {}
	var copied_bundle: Variant = _json_copy(_bundle)
	return copied_bundle as Dictionary if copied_bundle is Dictionary else {}


func collect_errors() -> PackedStringArray:
	_ensure_loaded()
	return _errors.duplicate()


func major_realms() -> Array:
	_ensure_loaded()
	var rows_v: Variant = _bundle.get("major_realms", [])
	return (rows_v as Array).duplicate(true) if _valid and rows_v is Array else []


static func validate_bundle(candidate: Dictionary, paths: Dictionary = {}) -> PackedStringArray:
	var resolved_paths := _resolved_paths(paths)
	var errors: PackedStringArray = []
	for table_v in resolved_paths.keys():
		var table := str(table_v)
		var table_v_candidate: Variant = candidate.get(table)
		var valid_table := table_v_candidate is Array if table == "major_realms" else table_v_candidate is Dictionary
		if not valid_table:
			errors.append(_message("invalid_table", str(resolved_paths[table]), "root"))
	if not errors.is_empty():
		return errors
	_validate_settings(candidate.acceptance as Dictionary, "acceptance", resolved_paths, errors)
	_validate_required_numeric_settings(candidate.acceptance as Dictionary, REQUIRED_ACCEPTANCE_KEYS, "acceptance", resolved_paths, errors)
	_validate_keyed_rows(candidate.budgets as Dictionary, "budgets", resolved_paths, errors)
	_validate_budget_rows(candidate.budgets as Dictionary, resolved_paths, errors)
	_validate_major_realms(candidate.major_realms as Array if candidate.major_realms is Array else [], resolved_paths, errors)
	_validate_combat_formula(candidate.combat_attribute_formula as Dictionary, resolved_paths, errors)
	_validate_keyed_nested(candidate.standard_players as Dictionary, REQUIRED_STANDARD_PLAYER_KEYS, "standard_players", "foundations", resolved_paths, errors)
	_validate_keyed_nested(candidate.benchmark_enemies as Dictionary, REQUIRED_BENCHMARK_KEYS, "benchmark_enemies", "attrs", resolved_paths, errors)
	_validate_encounter_bands(candidate.encounter_bands as Dictionary, resolved_paths, errors)
	_validate_progression(candidate.cultivation_progression as Dictionary, resolved_paths, errors)
	return errors


func _ensure_loaded() -> void:
	if not _load_attempted:
		reload()


func _reject(errors: PackedStringArray) -> bool:
	_errors = errors.duplicate()
	for message in _errors:
		push_error(message)
	return false


static func _decode_roots(raw_roots: Dictionary) -> Dictionary:
	return {
		"acceptance": _settings_from_root(raw_roots.acceptance as Dictionary),
		"benchmark_enemies": _keyed_rows_from_root(raw_roots.benchmark_enemies as Dictionary),
		"budgets": _keyed_rows_from_root(raw_roots.budgets as Dictionary),
		"combat_attribute_formula": _keyed_rows_from_root(raw_roots.combat_attribute_formula as Dictionary),
		"cultivation_progression": _settings_from_root(raw_roots.cultivation_progression as Dictionary),
		"encounter_bands": _keyed_rows_from_root(raw_roots.encounter_bands as Dictionary),
		"major_realms": _row_array_from_root(raw_roots.major_realms as Dictionary),
		"standard_players": _keyed_rows_from_root(raw_roots.standard_players as Dictionary),
	}


static func _keyed_rows_from_root(root: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key_v in root.keys():
		var row_v: Variant = root[key_v]
		if row_v is Dictionary:
			out[str(key_v)] = _decode_value(row_v)
	return out


static func _row_array_from_root(root: Dictionary) -> Array:
	var rows := _keyed_rows_from_root(root)
	var keys: Array = rows.keys()
	keys.sort_custom(_compare_keys)
	var out: Array = []
	for key_v in keys:
		out.append((rows[key_v] as Dictionary).duplicate(true))
	return out


static func _settings_from_root(root: Dictionary) -> Dictionary:
	var rows := _keyed_rows_from_root(root)
	var out: Dictionary = {}
	for key_v in rows.keys():
		var row := rows[key_v] as Dictionary
		var key := str(row.get("key", key_v)).strip_edges()
		if key != "":
			out[key] = _setting_payload(row)
	return out


static func _decode_value(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		for key_v in (value as Dictionary).keys():
			var cell: Variant = value[key_v]
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
			var parser := JSON.new()
			if parser.parse(text) == OK and (parser.data is Dictionary or parser.data is Array):
				return _decode_value(parser.data)
	return value


static func _setting_payload(row: Dictionary) -> Variant:
	if row.has("value") and row["value"] != null:
		return _coerce_scalar(row["value"])
	var out: Dictionary = {}
	for key_v in row.keys():
		var key := str(key_v)
		if key == "key" or key == "value":
			continue
		var value: Variant = row[key_v]
		if value != null:
			out[key] = _coerce_scalar(value)
	return out


static func _coerce_scalar(value: Variant) -> Variant:
	if not value is String:
		return value
	var text := str(value).strip_edges()
	var comment_at := text.find(" #")
	if comment_at >= 0:
		var before_comment := text.substr(0, comment_at).strip_edges()
		if before_comment.is_valid_int() or before_comment.is_valid_float() \
				or before_comment.to_lower() in ["true", "false"]:
			text = before_comment
	var lower := text.to_lower()
	if lower == "true":
		return true
	if lower == "false":
		return false
	if text.is_valid_int():
		return int(text)
	if text.is_valid_float():
		return float(text)
	return text


static func _compare_keys(a: Variant, b: Variant) -> bool:
	var left := str(a)
	var right := str(b)
	if left.is_valid_int() and right.is_valid_int():
		return int(left) < int(right)
	return left.naturalnocasecmp_to(right) < 0


static func _validate_keyed_rows(rows: Dictionary, table: String, paths: Dictionary, errors: PackedStringArray) -> void:
	if rows.is_empty():
		errors.append(_message("empty_table", str(paths[table]), "root"))
		return
	for key_v in rows.keys():
		var key := str(key_v).strip_edges()
		if key == "" or not rows[key_v] is Dictionary:
			errors.append(_message("invalid_row", str(paths[table]), key if key != "" else "root"))


static func _validate_settings(rows: Dictionary, table: String, paths: Dictionary, errors: PackedStringArray) -> void:
	if rows.is_empty():
		errors.append(_message("empty_table", str(paths[table]), "root"))
	for key_v in rows.keys():
		if str(key_v).strip_edges() == "":
			errors.append(_message("invalid_key", str(paths[table]), "root"))


static func _validate_required_numeric_settings(rows: Dictionary, required_keys: Array, table: String, paths: Dictionary, errors: PackedStringArray) -> void:
	for key in required_keys:
		if not rows.has(key):
			errors.append(_message("required_key_missing", str(paths[table]), str(key)))
		elif not _is_number(rows.get(key)):
			errors.append(_message("required_number_invalid", str(paths[table]), str(key)))


static func _validate_budget_rows(rows: Dictionary, paths: Dictionary, errors: PackedStringArray) -> void:
	const REQUIRED_KEY := "ability_same_tier_variance"
	var row_v: Variant = rows.get(REQUIRED_KEY)
	if not row_v is Dictionary:
		errors.append(_message("required_key_missing", str(paths.budgets), REQUIRED_KEY))
		return
	var row := row_v as Dictionary
	if str(row.get("key", "")).strip_edges() != REQUIRED_KEY:
		errors.append(_message("row_key_mismatch", str(paths.budgets), "%s.key" % REQUIRED_KEY))
	if not _is_number(row.get("value")):
		errors.append(_message("required_number_invalid", str(paths.budgets), "%s.value" % REQUIRED_KEY))


static func _validate_major_realms(rows: Array, paths: Dictionary, errors: PackedStringArray) -> void:
	if rows.size() != MAJOR_REALM_IDS.size():
		errors.append(_message("row_count", str(paths.major_realms), "root"))
	var ids: Dictionary = {}
	for index in rows.size():
		var row_v: Variant = rows[index]
		if not row_v is Dictionary:
			errors.append(_message("invalid_row", str(paths.major_realms), "[%d]" % index))
			continue
		var row := row_v as Dictionary
		var id := str(row.get("id", "")).strip_edges()
		if id == "" or ids.has(id):
			errors.append(_message("realm_id_invalid", str(paths.major_realms), "[%d].id" % index))
		ids[id] = true
		if not row.get("name") is String or str(row.name).strip_edges() == "":
			errors.append(_message("required_string", str(paths.major_realms), "%s.name" % id))
		if not _is_number(row.get("content_coefficient")) or float(row.get("content_coefficient", 0.0)) <= 0.0:
			errors.append(_message("coefficient_invalid", str(paths.major_realms), "%s.content_coefficient" % id))
	for id in MAJOR_REALM_IDS:
		if not ids.has(id):
			errors.append(_message("required_realm_missing", str(paths.major_realms), id))


static func _validate_combat_formula(rows: Dictionary, paths: Dictionary, errors: PackedStringArray) -> void:
	for attr in REQUIRED_COMBAT_ATTRS:
		var row_v: Variant = rows.get(attr)
		if not row_v is Dictionary:
			errors.append(_message("required_attr_missing", str(paths.combat_attribute_formula), attr))
			continue
		var row := row_v as Dictionary
		if str(row.get("key", "")).strip_edges() != attr:
			errors.append(_message("row_key_mismatch", str(paths.combat_attribute_formula), "%s.key" % attr))
		if not _is_number(row.get("base")) or not row.get("scale") is Dictionary:
			errors.append(_message("formula_invalid", str(paths.combat_attribute_formula), attr))
		elif not _all_dictionary_values_are_numbers(row.scale as Dictionary):
			errors.append(_message("formula_scale_invalid", str(paths.combat_attribute_formula), "%s.scale" % attr))


static func _validate_keyed_nested(rows: Dictionary, required_keys: Array, table: String, field: String, paths: Dictionary, errors: PackedStringArray) -> void:
	if rows.is_empty():
		errors.append(_message("empty_table", str(paths[table]), "root"))
	for required_key in required_keys:
		if not rows.has(required_key):
			errors.append(_message("required_key_missing", str(paths[table]), str(required_key)))
	for key_v in rows.keys():
		var key := str(key_v).strip_edges()
		var row_v: Variant = rows[key_v]
		if key == "" or not row_v is Dictionary:
			errors.append(_message("invalid_row", str(paths[table]), key if key != "" else "root"))
			continue
		var row := row_v as Dictionary
		if str(row.get("key", "")).strip_edges() != key:
			errors.append(_message("row_key_mismatch", str(paths[table]), "%s.key" % key))
		if not row.get(field) is Dictionary or (row[field] as Dictionary).is_empty():
			errors.append(_message("nested_object_invalid", str(paths[table]), "%s.%s" % [key, field]))
		elif not _all_dictionary_values_are_numbers(row[field] as Dictionary):
			errors.append(_message("nested_number_invalid", str(paths[table]), "%s.%s" % [key, field]))


static func _validate_encounter_bands(rows: Dictionary, paths: Dictionary, errors: PackedStringArray) -> void:
	for band in REQUIRED_ENCOUNTER_BANDS:
		var row_v: Variant = rows.get(band)
		if not row_v is Dictionary:
			errors.append(_message("required_band_missing", str(paths.encounter_bands), band))
			continue
		var row := row_v as Dictionary
		if str(row.get("key", "")).strip_edges() != band:
			errors.append(_message("row_key_mismatch", str(paths.encounter_bands), "%s.key" % band))
		if not _is_number(row.get("strength_min")) or not _is_number(row.get("strength_max")) \
				or float(row.strength_min) > float(row.strength_max):
			errors.append(_message("band_invalid", str(paths.encounter_bands), band))


static func _validate_progression(rows: Dictionary, paths: Dictionary, errors: PackedStringArray) -> void:
	var gains_v: Variant = rows.get("base_monthly_gain_by_realm")
	var pills_v: Variant = rows.get("cultivation_pill_balance")
	if not gains_v is Dictionary:
		errors.append(_message("required_progression_missing", str(paths.cultivation_progression), "base_monthly_gain_by_realm"))
	else:
		for realm in MAJOR_REALM_IDS:
			var realm_gains_v: Variant = (gains_v as Dictionary).get(realm)
			if not realm_gains_v is Dictionary:
				errors.append(_message("realm_gain_missing", str(paths.cultivation_progression), realm))
				continue
			var required_phases := ["single"] if realm == "dujie" else ["early", "mid", "late"]
			for phase in required_phases:
				var gain_v: Variant = (realm_gains_v as Dictionary).get(phase)
				if not _is_number(gain_v) or float(gain_v) <= 0.0:
					errors.append(_message("realm_gain_invalid", str(paths.cultivation_progression), "%s.%s" % [realm, phase]))
	if not pills_v is Dictionary:
		errors.append(_message("required_progression_missing", str(paths.cultivation_progression), "cultivation_pill_balance"))
		return
	var pills := pills_v as Dictionary
	var anchor := str(pills.get("anchor_realm", "")).strip_edges()
	if not anchor in MAJOR_REALM_IDS:
		errors.append(_message("pill_anchor_invalid", str(paths.cultivation_progression), "anchor_realm"))
	if not _is_number(pills.get("medium_cultivation_gain")) or int(pills.get("medium_cultivation_gain", 0)) <= 0:
		errors.append(_message("pill_gain_invalid", str(paths.cultivation_progression), "medium_cultivation_gain"))
	var quality_v: Variant = pills.get("quality_band_multiplier")
	if not quality_v is Dictionary:
		errors.append(_message("pill_bands_invalid", str(paths.cultivation_progression), "quality_band_multiplier"))
	else:
		for band in REQUIRED_QUALITY_BANDS:
			var multiplier_v: Variant = (quality_v as Dictionary).get(band)
			if not _is_number(multiplier_v) or float(multiplier_v) <= 0.0:
				errors.append(_message("pill_band_missing", str(paths.cultivation_progression), band))
	var tiers_v: Variant = pills.get("tier_major_realm")
	if not tiers_v is Dictionary:
		errors.append(_message("pill_tiers_invalid", str(paths.cultivation_progression), "tier_major_realm"))
	else:
		for tier in MAJOR_REALM_IDS.size():
			var target := str((tiers_v as Dictionary).get(str(tier + 1), "")).strip_edges()
			if target != MAJOR_REALM_IDS[tier]:
				errors.append(_message("pill_tier_realm_invalid", str(paths.cultivation_progression), str(tier + 1)))


static func _resolved_paths(paths: Dictionary = {}) -> Dictionary:
	return {
		"acceptance": str(paths.get("acceptance", ACCEPTANCE_PATH)),
		"benchmark_enemies": str(paths.get("benchmark_enemies", BENCHMARK_ENEMIES_PATH)),
		"budgets": str(paths.get("budgets", BUDGETS_PATH)),
		"combat_attribute_formula": str(paths.get("combat_attribute_formula", COMBAT_ATTRIBUTE_FORMULA_PATH)),
		"cultivation_progression": str(paths.get("cultivation_progression", CULTIVATION_PROGRESSION_PATH)),
		"encounter_bands": str(paths.get("encounter_bands", ENCOUNTER_BANDS_PATH)),
		"major_realms": str(paths.get("major_realms", MAJOR_REALMS_PATH)),
		"standard_players": str(paths.get("standard_players", STANDARD_PLAYERS_PATH)),
	}


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _all_dictionary_values_are_numbers(values: Dictionary) -> bool:
	for value_v in values.values():
		if not _is_number(value_v):
			return false
	return true


static func _json_copy(value: Variant) -> Variant:
	var parser := JSON.new()
	if parser.parse(JSON.stringify(value)) != OK:
		return null
	return parser.data


static func _message(code: String, path: String, field: String) -> String:
	return "[realm_balance_catalog:%s] path=%s field=%s" % [code, path, field]
