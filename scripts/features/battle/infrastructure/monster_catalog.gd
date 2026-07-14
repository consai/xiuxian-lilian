class_name MonsterCatalog
extends RefCounted

const PATH := "res://data/exportjson/guaiwu.json"
const EXPECTED_ROW_COUNT := 10
const REQUIRED_STRING_FIELDS: Array[String] = ["key", "id", "name", "obj", "headicon", "type"]
const COMBAT_STAT_FIELDS: Array[String] = [
	"hp_max", "mp_max", "shield", "physical_atk", "magic_atk",
	"physical_def", "magic_def", "spd",
]
const DROP_KINDS: Array[String] = ["item", "equip", "currency"]
const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")

static var _loaded := false
static var _monsters_by_id: Dictionary = {}


static func monster_by_id(monster_id: String) -> Dictionary:
	_ensure_loaded()
	var mid := monster_id.strip_edges()
	var row_v: Variant = _monsters_by_id.get(mid)
	if not row_v is Dictionary:
		return {}
	return (row_v as Dictionary).duplicate(true)


static func all_monster_ids() -> Array:
	_ensure_loaded()
	var ids: Array = _monsters_by_id.keys()
	ids.sort()
	return ids.duplicate()


static func all_monsters_snapshot() -> Dictionary:
	_ensure_loaded()
	return _monsters_by_id.duplicate(true)


static func validate_table(value: Variant, path: String = PATH) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not value is Dictionary:
		errors.append(_error("invalid_root", path, "$", "expected Dictionary, got %s" % type_string(typeof(value))))
		return errors
	var rows := value as Dictionary
	if rows.size() != EXPECTED_ROW_COUNT:
		errors.append(_error(
			"invalid_row_count", path, "$",
			"expected %d rows, got %d" % [EXPECTED_ROW_COUNT, rows.size()]
		))
	var keys: Array = rows.keys()
	keys.sort()
	for key_v in keys:
		_validate_row(errors, key_v, rows[key_v], path)
	return errors


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_monsters_by_id.clear()
	var raw_v: Variant = JsonReaderScript.read_variant(PATH)
	var errors := validate_table(raw_v)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		return
	_monsters_by_id = (raw_v as Dictionary).duplicate(true)


static func _validate_row(
		errors: PackedStringArray,
		key_v: Variant,
		row_v: Variant,
		path: String
) -> void:
	if not key_v is String or str(key_v).strip_edges() == "":
		errors.append(_error("invalid_key", path, "$", "row key must be a non-empty String"))
		return
	var row_key := str(key_v)
	var root := "monster[%s]" % row_key
	if not row_v is Dictionary:
		errors.append(_error("invalid_row", path, root, "expected Dictionary"))
		return
	var row := row_v as Dictionary
	for field in REQUIRED_STRING_FIELDS:
		var field_v: Variant = row.get(field)
		if not field_v is String or str(field_v).strip_edges() == "":
			errors.append(_error(
				"invalid_field", path, "%s.%s" % [root, field],
				"expected non-empty String"
			))
	if row.get("key") is String and str(row["key"]).strip_edges() != row_key:
		errors.append(_error(
			"key_mismatch", path, "%s.key" % root,
			"expected '%s', got '%s'" % [row_key, str(row["key"])]
		))
	if row.get("id") is String and str(row["id"]).strip_edges() != row_key:
		errors.append(_error(
			"id_mismatch", path, "%s.id" % root,
			"expected '%s', got '%s'" % [row_key, str(row["id"])]
		))
	_validate_dropitem(errors, row.get("dropitem"), "%s.dropitem" % root, path)
	_validate_skills(errors, row.get("skills"), "%s.skills" % root, path)
	for field in COMBAT_STAT_FIELDS:
		var field_v: Variant = row.get(field)
		if not _is_number(field_v):
			errors.append(_error(
				"invalid_stat", path, "%s.%s" % [root, field], "expected number"
			))


static func _validate_dropitem(
		errors: PackedStringArray,
		value: Variant,
		field: String,
		path: String
) -> void:
	if not value is Array:
		errors.append(_error("invalid_dropitem", path, field, "expected Array"))
		return
	var rows := value as Array
	if rows.is_empty():
		errors.append(_error("empty_dropitem", path, field, "expected at least one five-cell row"))
	for index in rows.size():
		var row_field := "%s[%d]" % [field, index]
		var row_v: Variant = rows[index]
		if not row_v is Array or (row_v as Array).size() != 5:
			errors.append(_error(
				"invalid_drop_row", path, row_field,
				"expected [kind, id, min, max, weight]"
			))
			continue
		var cells := row_v as Array
		var kind := str(cells[0]).strip_edges()
		if not cells[0] is String or kind not in DROP_KINDS:
			errors.append(_error(
				"invalid_drop_kind", path, "%s[0]" % row_field,
				"expected one of %s" % str(DROP_KINDS)
			))
		if not _valid_reward_id(kind, cells[1]):
			errors.append(_error(
				"invalid_drop_id", path, "%s[1]" % row_field,
				"expected non-empty id"
			))
		for cell_index in [2, 3, 4]:
			if not _is_integer_cell(cells[cell_index]):
				errors.append(_error(
					"invalid_drop_number", path, "%s[%d]" % [row_field, cell_index],
					"expected integer cell"
				))
		if _is_integer_cell(cells[2]) and _is_integer_cell(cells[3]) \
				and (int(cells[2]) < 1 or int(cells[3]) < int(cells[2])):
			errors.append(_error(
				"invalid_drop_range", path, row_field, "expected 1 <= min <= max"
			))
		if _is_integer_cell(cells[4]) and int(cells[4]) <= 0:
			errors.append(_error(
				"invalid_drop_weight", path, "%s[4]" % row_field, "expected > 0"
			))


static func _validate_skills(
		errors: PackedStringArray,
		value: Variant,
		field: String,
		path: String
) -> void:
	if not value is Array:
		errors.append(_error("invalid_skills", path, field, "expected Array"))
		return
	var skills := value as Array
	if skills.is_empty():
		errors.append(_error("empty_skills", path, field, "expected at least one skill id"))
	for index in skills.size():
		var skill_v: Variant = skills[index]
		if not _is_integer_number(skill_v) or int(skill_v) < 0:
			errors.append(_error(
				"invalid_skill_id", path, "%s[%d]" % [field, index],
				"expected non-negative int"
			))


static func _valid_reward_id(kind: String, value: Variant) -> bool:
	if kind == "equip":
		return (typeof(value) == TYPE_INT and int(value) >= 0) \
			or (value is String and str(value).is_valid_int())
	return value is String and str(value).strip_edges() != ""


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _is_integer_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return value is float and is_equal_approx(float(value), roundf(float(value)))


static func _is_integer_cell(value: Variant) -> bool:
	if _is_integer_number(value):
		return true
	return value is String and str(value).is_valid_int()


static func _error(code: String, path: String, field: String, detail: String) -> String:
	return "[monster_catalog:%s] file=%s field=%s %s" % [code, path, field, detail]
