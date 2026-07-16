class_name BattleVfxCatalog
extends RefCounted

const FLOAT_SETTINGS_PATH := "res://data/exportjson/zhandou_float_styles.json"
const FLOAT_STYLES_PATH := "res://data/exportjson/zhandou_float_styles_styles.json"
const INDEX_PATH := "res://data/exportjson/zhandou_vfx_index.json"
const PRESET_FILES := {
	"hit_default": "zhandou_presets_hit_default_s.json",
	"hit_only": "zhandou_presets_hit_only_sequ.json",
	"melee_default": "zhandou_presets_melee_default.json",
	"qi_bolt_projectile": "zhandou_presets_qi_bolt_proje.json",
	"ranged_default": "zhandou_presets_ranged_defaul.json",
	"status_cast": "zhandou_presets_status_cast_s.json",
	"sword_qi_projectile": "zhandou_presets_sword_qi_proj.json",
}
const JSON_COMMENT_KEYS: Array[String] = ["_comment", "_说明", "_doc", "_备注"]
const REQUIRED_FLOAT_STYLE_IDS := ["buff_add", "buff_expire", "damage", "heal", "mp_cost", "mp_gain", "shield", "skill"]

const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")
const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")
const StepDefsScript := preload("res://scripts/features/battle/domain/zhandou_vfx_step_defs.gd")

var _paths: Dictionary
var _load_attempted := false
var _valid := false
var _errors: PackedStringArray = []
var _float_bundle: Dictionary = {}
var _index: Dictionary = {}
var _sequences: Dictionary = {}
var _preset_ids: Array = []


func _init(paths: Dictionary = {}) -> void:
	_paths = _resolved_paths(paths)


func reload() -> bool:
	_load_attempted = true
	var roots: Dictionary = {}
	var errors: PackedStringArray = []
	for table_v in _table_names():
		var table := str(table_v)
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
		return _reject(PackedStringArray([_message("invalid_roots", "fixture", "roots", "root")]))
	var errors: PackedStringArray = []
	for table_v in _table_names():
		var table := str(table_v)
		var root_v: Variant = (roots as Dictionary).get(table)
		if not root_v is Dictionary:
			errors.append(_message("invalid_root", str(resolved[table]), table, "root"))
			continue
		for key_v in (root_v as Dictionary).keys():
			if not (root_v as Dictionary)[key_v] is Dictionary:
				errors.append(_message("invalid_row", str(resolved[table]), table, str(key_v)))
		if table.begins_with("preset:"):
			var keys: Array = (root_v as Dictionary).keys()
			keys.sort_custom(ExportTableReaderScript.compare_keys)
			for index in keys.size():
				var outer_key := str(keys[index]).strip_edges()
				var row_v: Variant = (root_v as Dictionary)[keys[index]]
				if row_v is Dictionary and (outer_key != str(index + 1) \
						or str((row_v as Dictionary).get("key", "")).strip_edges() != outer_key):
					errors.append(_message("preset_key_mismatch", str(resolved[table]), table, "%s.key" % outer_key))
	if not errors.is_empty():
		return _reject(errors)
	var candidate := _decode_roots(roots as Dictionary)
	errors = _validate_candidate(candidate, resolved)
	if not errors.is_empty():
		return _reject(errors)
	_float_bundle = (candidate.float_bundle as Dictionary).duplicate(true)
	_index = (candidate.index as Dictionary).duplicate(true)
	_sequences = (candidate.sequences as Dictionary).duplicate(true)
	_preset_ids = _sequences.keys()
	_preset_ids.sort_custom(ExportTableReaderScript.compare_keys)
	_errors.clear()
	_valid = true
	return true


func float_styles() -> Dictionary:
	_ensure_loaded()
	return _float_bundle.duplicate(true) if _valid else {}


func index_snapshot() -> Dictionary:
	_ensure_loaded()
	return _index.duplicate(true) if _valid else {}


func preset_ids() -> Array:
	_ensure_loaded()
	return _preset_ids.duplicate() if _valid else []


func has_preset(preset_id: String) -> bool:
	_ensure_loaded()
	return _valid and _sequences.has(normalize_preset_id(preset_id))


func sequence(preset_id: String) -> Array:
	_ensure_loaded()
	var id := normalize_preset_id(preset_id)
	var value: Variant = _sequences.get(id)
	return (value as Array).duplicate(true) if _valid and value is Array else []


func collect_errors() -> PackedStringArray:
	_ensure_loaded()
	return _errors.duplicate()


static func normalize_preset_id(ref: String) -> String:
	var value := ref.strip_edges()
	if value.ends_with(".json"):
		value = value.substr(0, value.length() - 5)
	var slash := maxi(value.rfind("/"), value.rfind("\\"))
	return value.substr(slash + 1) if slash >= 0 else value


func _ensure_loaded() -> void:
	if not _load_attempted:
		reload()


func _reject(errors: PackedStringArray) -> bool:
	_errors = errors.duplicate()
	for message in _errors:
		push_error(message)
	return false


static func _resolved_paths(overrides: Dictionary) -> Dictionary:
	var out := {
		"float_settings": str(overrides.get("float_settings", FLOAT_SETTINGS_PATH)),
		"float_styles": str(overrides.get("float_styles", FLOAT_STYLES_PATH)),
		"index": str(overrides.get("index", INDEX_PATH)),
	}
	for id_v in PRESET_FILES.keys():
		var id := str(id_v)
		out["preset:%s" % id] = str(overrides.get("preset:%s" % id, "res://data/exportjson/%s" % PRESET_FILES[id]))
	return out


static func _table_names() -> Array:
	var out: Array = ["float_settings", "float_styles", "index"]
	var ids: Array = PRESET_FILES.keys()
	ids.sort_custom(ExportTableReaderScript.compare_keys)
	for id_v in ids:
		out.append("preset:%s" % str(id_v))
	return out


static func _decode_roots(roots: Dictionary) -> Dictionary:
	var float_bundle := _settings_from_root(roots.float_settings as Dictionary)
	float_bundle["styles"] = _keyed_rows_from_root(roots.float_styles as Dictionary)
	var sequences: Dictionary = {}
	for id_v in PRESET_FILES.keys():
		var id := str(id_v)
		sequences[id] = _row_array_from_root(roots["preset:%s" % id] as Dictionary)
	return {
		"float_bundle": _strip_comments(float_bundle),
		"index": _strip_comments(_settings_from_root(roots.index as Dictionary)),
		"sequences": _strip_comments(sequences),
	}


static func _keyed_rows_from_root(root: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key_v in root.keys():
		out[str(key_v)] = _decode_value(root[key_v])
	return out


static func _row_array_from_root(root: Dictionary) -> Array:
	var rows := _keyed_rows_from_root(root)
	var keys: Array = rows.keys()
	keys.sort_custom(ExportTableReaderScript.compare_keys)
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
			var parser := JSON.new()
			if parser.parse(text) == OK and (parser.data is Dictionary or parser.data is Array):
				return _decode_value(parser.data)
	return value


static func _setting_payload(row: Dictionary) -> Variant:
	if row.has("value"):
		return _coerce_scalar(row.value)
	var out: Dictionary = {}
	for key_v in row.keys():
		var key := str(key_v)
		if key != "key" and key != "value":
			out[key] = _coerce_scalar(row[key_v])
	return out


static func _coerce_scalar(value: Variant) -> Variant:
	if not value is String:
		return value
	var text := str(value).strip_edges()
	if text.is_valid_int():
		return int(text)
	if text.is_valid_float():
		return float(text)
	if text.to_lower() == "true":
		return true
	if text.to_lower() == "false":
		return false
	return text


static func _strip_comments(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		for key_v in (value as Dictionary).keys():
			if str(key_v) not in JSON_COMMENT_KEYS:
				out[key_v] = _strip_comments((value as Dictionary)[key_v])
		return out
	if value is Array:
		var out: Array = []
		for cell in value as Array:
			out.append(_strip_comments(cell))
		return out
	return value


static func _validate_candidate(candidate: Dictionary, paths: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	var float_bundle := candidate.get("float_bundle", {}) as Dictionary
	for field in ["version", "jitter_x", "max_per_unit_per_frame", "arc_drift_ratio", "arc_apex_min", "arc_apex_max"]:
		if not _is_numeric(float_bundle.get(field)):
			errors.append(_message("numeric_required", str(paths.float_settings), "float_settings", field))
	var styles := float_bundle.get("styles", {}) as Dictionary
	for style_id_v in REQUIRED_FLOAT_STYLE_IDS:
		var style_id := str(style_id_v)
		var style_v: Variant = styles.get(style_id)
		if not style_v is Dictionary:
			errors.append(_message("style_missing", str(paths.float_styles), "float_styles", style_id))
			continue
		var style := style_v as Dictionary
		if not style.get("key") is String or str(style.get("key", "")).strip_edges() != style_id:
			errors.append(_message("style_key_mismatch", str(paths.float_styles), "float_styles", "%s.key" % style_id))
		for field in ["font_size", "rise_px", "duration", "fade_in_frac", "fade_out_frac"]:
			if not _is_numeric(style.get(field)):
				errors.append(_message("numeric_required", str(paths.float_styles), "float_styles", "%s.%s" % [style_id, field]))
		if not style.get("color") is String or str(style.color).strip_edges() == "":
			errors.append(_message("required_string", str(paths.float_styles), "float_styles", "%s.color" % style_id))
	var index := candidate.get("index", {}) as Dictionary
	var version_v: Variant = index.get("version")
	if not _is_integer_number(version_v):
		errors.append(_message("index_version_invalid", str(paths.index), "index", "version"))
	if not index.get("preset_dir") is String or str(index.get("preset_dir", "")).strip_edges() == "":
		errors.append(_message("preset_dir_invalid", str(paths.index), "index", "preset_dir"))
	for field in ["default", "impact_preset"]:
		var id := normalize_preset_id(str(index.get(field, "")))
		if id == "" or not PRESET_FILES.has(id):
			errors.append(_message("preset_reference_unknown", str(paths.index), "index", field))
	var sequences := candidate.get("sequences", {}) as Dictionary
	for id_v in PRESET_FILES.keys():
		var id := str(id_v)
		var steps_v: Variant = sequences.get(id)
		if not steps_v is Array or (steps_v as Array).is_empty():
			errors.append(_message("sequence_empty", str(paths["preset:%s" % id]), "preset:%s" % id, "root"))
			continue
		_validate_steps(steps_v as Array, id, str(paths["preset:%s" % id]), sequences, errors, "", true)
	return errors


static func _validate_steps(steps: Array, preset_id: String, path: String, sequences: Dictionary, errors: PackedStringArray, prefix: String = "", top_level: bool = false) -> void:
	for index in steps.size():
		var field := "%s%d" % [prefix, index]
		var step_v: Variant = steps[index]
		if not step_v is Dictionary:
			errors.append(_message("invalid_step", path, "preset:%s" % preset_id, field))
			continue
		var step := step_v as Dictionary
		if top_level and (not step.get("key") is String or str(step.get("key", "")).strip_edges() != str(index + 1)):
			errors.append(_message("preset_key_mismatch", path, "preset:%s" % preset_id, "%s.key" % field))
		var op := str(step.get("op", "")).strip_edges() if step.get("op") is String else ""
		if op == "":
			errors.append(_message("op_required", path, "preset:%s" % preset_id, "%s.op" % field))
		elif op not in _known_ops():
			errors.append(_message("op_unknown", path, "preset:%s" % preset_id, "%s.op" % field))
		var nested_v: Variant = step.get("steps")
		if nested_v != null:
			if nested_v is Array:
				_validate_steps(nested_v as Array, preset_id, path, sequences, errors, "%s.steps." % field, false)
			else:
				errors.append(_message("steps_invalid", path, "preset:%s" % preset_id, "%s.steps" % field))
		if str(step.get("op", "")) == "subsequence":
			var reference := normalize_preset_id(str(step.get("preset", "")))
			if reference == "" or not sequences.has(reference):
				errors.append(_message("preset_reference_unknown", path, "preset:%s" % preset_id, "%s.preset" % field))


static func _known_ops() -> Array:
	return [
		StepDefsScript.OP_STOP_IDLE,
		StepDefsScript.OP_RESUME_IDLE,
		StepDefsScript.OP_TWEEN,
		StepDefsScript.OP_TWEEN_METHOD,
		StepDefsScript.OP_PARALLEL,
		StepDefsScript.OP_SEQUENCE,
		StepDefsScript.OP_IMPACT,
		StepDefsScript.OP_PROJECTILE,
		StepDefsScript.OP_SCREEN_SHAKE,
		StepDefsScript.OP_CAPTURE_REST,
		StepDefsScript.OP_WAIT,
		StepDefsScript.OP_SUBSEQUENCE,
	]


static func _is_numeric(value: Variant) -> bool:
	return value is int or value is float or (value is String and str(value).strip_edges().is_valid_float())


static func _is_integer_number(value: Variant) -> bool:
	return value is int or (value is float and is_equal_approx(float(value), roundf(float(value))))


static func _message(code: String, path: String, table: String, field: String) -> String:
	return "[battle_vfx_catalog:%s] file=%s table=%s field=%s" % [code, path, table, field]
