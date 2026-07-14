class_name MoniCatalog
extends RefCounted

const SCHEMA_PATH := "res://data/exportjson/yunxing_params/moni.json"
const ACTIVITIES_PATH := "res://data/exportjson/yunxing_params/moni_activities.json"
const INITIAL_PLAYER_PATH := "res://data/exportjson/yunxing_params/moni_initial_player.json"
const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")

static var _schema_loaded := false
static var _activities_loaded := false
static var _initial_player_loaded := false
static var _schema: Dictionary = {}
static var _activities: Dictionary = {}
static var _initial_player: Dictionary = {}


static func schema() -> Dictionary:
	if not _schema_loaded:
		_schema_loaded = true
		var loaded := ExportTableReaderScript.read_settings(SCHEMA_PATH)
		_schema = _accept_or_report(loaded, validate_schema(loaded))
	return _schema.duplicate(true)


static func activities() -> Dictionary:
	if not _activities_loaded:
		_activities_loaded = true
		var loaded := ExportTableReaderScript.read_keyed_rows(ACTIVITIES_PATH)
		var errors := validate_activities(loaded)
		if errors.is_empty():
			_activities = _normalize_activities(loaded)
		else:
			_activities = _accept_or_report(loaded, errors)
	return _activities.duplicate(true)


static func initial_player() -> Dictionary:
	if not _initial_player_loaded:
		_initial_player_loaded = true
		var loaded := ExportTableReaderScript.read_settings(INITIAL_PLAYER_PATH)
		var errors := validate_initial_player(loaded)
		if errors.is_empty():
			_initial_player = _normalize_initial_player(loaded)
		else:
			_initial_player = _accept_or_report(loaded, errors)
	return _initial_player.duplicate(true)


static func activity_by_id(activity_id: String) -> Dictionary:
	var key := activity_id.strip_edges()
	if key == "":
		return {}
	var row_v: Variant = activities().get(key)
	if not row_v is Dictionary:
		return {}
	return (row_v as Dictionary).duplicate(true)


static func validate_schema(value: Dictionary, path: String = SCHEMA_PATH) -> PackedStringArray:
	var errors: PackedStringArray = []
	var version: Variant = value.get("schema_version")
	if not _is_integer_value(version, false):
		errors.append(_error("schema_version_type", path, "schema_version", "expected integer"))
	elif int(version) != 1:
		errors.append(_error("schema_version_unsupported", path, "schema_version", "expected 1"))
	return errors


static func validate_activities(value: Dictionary, path: String = ACTIVITIES_PATH) -> PackedStringArray:
	var errors: PackedStringArray = []
	if value.is_empty():
		errors.append(_error("activities_empty", path, "$", "expected activity rows"))
		return errors
	for required_id in ["cultivate", "rest"]:
		if not value.has(required_id):
			errors.append(_error("activity_required", path, required_id, "missing required activity"))
	for row_key_v in value.keys():
		var row_key := str(row_key_v).strip_edges()
		var row_v: Variant = value[row_key_v]
		if row_key == "":
			errors.append(_error("activity_key_empty", path, "$", "row key must not be empty"))
			continue
		if not row_v is Dictionary:
			errors.append(_error("activity_row_type", path, row_key, "expected object"))
			continue
		var row := row_v as Dictionary
		if not row.get("key") is String or str(row.get("key")).strip_edges() != row_key:
			errors.append(_error("activity_key_mismatch", path, "%s.key" % row_key, "expected '%s'" % row_key))
		_validate_positive_integer(errors, row, "days", row_key, path, false)
		if row_key == "cultivate":
			_validate_non_negative_integer(errors, row, "cultivation_gain", row_key, path, false)
		elif row_key == "rest":
			_validate_non_negative_integer(errors, row, "injury_recovery", row_key, path, true)
	return errors


static func validate_initial_player(
		value: Dictionary,
		path: String = INITIAL_PLAYER_PATH
) -> PackedStringArray:
	var errors: PackedStringArray = []
	for field in ["name", "icon"]:
		var field_value: Variant = value.get(field)
		if not field_value is String or str(field_value).strip_edges() == "":
			errors.append(_error("initial_required_string", path, field, "expected non-empty string"))
	for field in ["attrs", "linggen", "items"]:
		if not value.get(field) is Dictionary:
			errors.append(_error("initial_dictionary_type", path, field, "expected object"))
	var equips_v: Variant = value.get("equips")
	if not equips_v is Dictionary or not (equips_v as Dictionary).is_empty():
		errors.append(_error("initial_equips_shape", path, "equips", "expected empty object"))
	for field in ["jineng", "jineng_use", "gongfa", "item_slots", "equip_slots"]:
		if not value.get(field) is String:
			errors.append(_error("initial_colon_field_type", path, field, "expected colon-delimited string"))
	if not errors.is_empty():
		return errors
	var jineng := _split_string_array(str(value["jineng"]), false)
	var jineng_use := _split_string_array(str(value["jineng_use"]), false)
	var gongfa := _split_string_array(str(value["gongfa"]), false)
	if jineng.is_empty():
		errors.append(_error("initial_jineng_empty", path, "jineng", "expected at least one id"))
	if gongfa.is_empty():
		errors.append(_error("initial_gongfa_empty", path, "gongfa", "expected at least one id"))
	for ability_id_v in jineng_use:
		var ability_id := str(ability_id_v)
		if ability_id not in jineng:
			errors.append(_error("initial_jineng_use_unknown", path, "jineng_use", "unknown id '%s'" % ability_id))
	for index in str(value["equip_slots"]).split(":", true).size():
		var entry := str(str(value["equip_slots"]).split(":", true)[index]).strip_edges()
		if not entry.is_valid_int():
			errors.append(_error("initial_equip_slot_type", path, "equip_slots[%d]" % index, "expected integer"))
	return errors


static func _normalize_activities(value: Dictionary) -> Dictionary:
	var out := value.duplicate(true)
	for row_key_v in out.keys():
		var row := out[row_key_v] as Dictionary
		for field in ["days", "cultivation_gain", "injury_recovery"]:
			if row.has(field):
				row[field] = int(row[field])
	return out


static func _normalize_initial_player(value: Dictionary) -> Dictionary:
	var out := value.duplicate(true)
	out["jineng"] = _split_string_array(str(value["jineng"]), false)
	out["jineng_use"] = _split_string_array(str(value["jineng_use"]), false)
	out["gongfa"] = _split_string_array(str(value["gongfa"]), false)
	out["equips"] = []
	out["item_slots"] = _split_string_array(str(value["item_slots"]), true)
	var equip_slots: Array = []
	for entry in str(value["equip_slots"]).split(":", true):
		equip_slots.append(int(str(entry).strip_edges()))
	out["equip_slots"] = equip_slots
	return out


static func _split_string_array(value: String, allow_empty: bool) -> Array:
	var out: Array = []
	for entry in value.split(":", true):
		var text := str(entry).strip_edges()
		if allow_empty or text != "":
			out.append(text)
	return out


static func _validate_positive_integer(
		errors: PackedStringArray,
		row: Dictionary,
	field: String,
	row_key: String,
	path: String,
	allow_integer_text: bool
) -> void:
	var value: Variant = row.get(field)
	if not _is_integer_value(value, allow_integer_text) or int(value) <= 0:
		errors.append(_error("activity_positive_integer", path, "%s.%s" % [row_key, field], "expected integer > 0"))


static func _validate_non_negative_integer(
		errors: PackedStringArray,
		row: Dictionary,
	field: String,
	row_key: String,
	path: String,
	allow_integer_text: bool
) -> void:
	var value: Variant = row.get(field)
	if not _is_integer_value(value, allow_integer_text) or int(value) < 0:
		errors.append(_error("activity_non_negative_integer", path, "%s.%s" % [row_key, field], "expected integer >= 0"))


static func _is_integer_value(value: Variant, allow_integer_text: bool) -> bool:
	if value is int:
		return true
	if value is float:
		return is_equal_approx(float(value), roundf(float(value)))
	return allow_integer_text and value is String and str(value).strip_edges().is_valid_int()


static func _accept_or_report(value: Dictionary, errors: PackedStringArray) -> Dictionary:
	if errors.is_empty():
		return value.duplicate(true)
	for message in errors:
		push_error(message)
	return {}


static func _error(code: String, path: String, field: String, detail: String) -> String:
	return "[moni_catalog:%s] file=%s field=%s %s" % [code, path, field, detail]
