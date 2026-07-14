class_name BuffCatalog
extends RefCounted

const PATH := "res://data/exportjson/buff.json"
const EXPECTED_ROW_COUNT := 14
const REQUIRED_FIELDS: Array[String] = [
	"id", "name", "icon", "desc", "type", "duration", "max_stacks", "ticktime",
	"modifiers", "tick_effects",
]
const ALLOWED_TAGS: Array[String] = ["buff", "debuff", "control"]

static var _loaded := false
static var _buff_by_id: Dictionary = {}


static func buff_by_id(buff_id: String) -> Dictionary:
	_ensure_loaded()
	var bid := buff_id.strip_edges()
	var found: Variant = _buff_by_id.get(bid)
	if found is BuffDef:
		return (found as BuffDef).to_dict()
	return {}


static func all_buff_ids() -> Array:
	_ensure_loaded()
	var ids: Array = _buff_by_id.keys()
	ids.sort()
	return ids.duplicate()


static func all_buffs_snapshot() -> Dictionary:
	_ensure_loaded()
	var out: Dictionary = {}
	for buff_id_v in all_buff_ids():
		var buff_id := str(buff_id_v)
		out[buff_id] = buff_by_id(buff_id)
	return out


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_buff_by_id.clear()
	var raw_v: Variant = JsonReader.read_variant(PATH)
	if raw_v == null:
		_fail("read_failed", "root", "unable to read exported JSON")
		return
	if not raw_v is Dictionary:
		_fail("invalid_root", "root", "expected Dictionary, got %s" % type_string(typeof(raw_v)))
		return
	var rows := raw_v as Dictionary
	if rows.size() != EXPECTED_ROW_COUNT:
		_fail("invalid_row_count", "root", "expected %d rows, got %d" % [EXPECTED_ROW_COUNT, rows.size()])
		return
	var valid := true
	var keys: Array = rows.keys()
	keys.sort()
	for key_v in keys:
		valid = _validate_raw_row(str(key_v), rows[key_v]) and valid
	if not valid:
		_buff_by_id.clear()
		return
	for key_v in keys:
		var buff_id := str(key_v)
		var normalized := _normalize_export_row(buff_id, rows[key_v] as Dictionary)
		var buff := BuffDef.from_dict(normalized)
		if buff == null:
			_fail("normalization_failed", "buff[%s]" % buff_id, "BuffDef rejected validated row")
			_buff_by_id.clear()
			return
		_buff_by_id[buff_id] = buff


static func _validate_raw_row(buff_id: String, row_v: Variant) -> bool:
	var field_root := "buff[%s]" % buff_id
	if buff_id.strip_edges() == "":
		_fail("invalid_key", field_root, "key must be a non-empty String")
		return false
	if not row_v is Dictionary:
		_fail("invalid_row", field_root, "expected Dictionary, got %s" % type_string(typeof(row_v)))
		return false
	var row := row_v as Dictionary
	var valid := true
	for field in REQUIRED_FIELDS:
		if not row.has(field):
			_fail("missing_field", "%s.%s" % [field_root, field], "required")
			valid = false
	if not valid:
		return false
	if not row["id"] is String or str(row["id"]).strip_edges() != buff_id:
		_fail("id_mismatch", "%s.id" % field_root, "expected '%s', got '%s'" % [buff_id, str(row["id"])])
		valid = false
	for field in ["name", "icon", "desc", "type"]:
		if not row[field] is String:
			_fail("invalid_field", "%s.%s" % [field_root, field], "expected String")
			valid = false
	if row["name"] is String and str(row["name"]).strip_edges() == "":
		_fail("invalid_field", "%s.name" % field_root, "must be non-empty")
		valid = false
	if row["type"] is String:
		valid = _validate_type_tags(str(row["type"]), "%s.type" % field_root) and valid
	if not _is_number(row["duration"]) or float(row["duration"]) < 0.0:
		_fail("invalid_field", "%s.duration" % field_root, "expected number >= 0")
		valid = false
	if not _is_number(row["max_stacks"]) \
			or not is_equal_approx(float(row["max_stacks"]), roundf(float(row["max_stacks"]))) \
			or int(row["max_stacks"]) < 1:
		_fail("invalid_field", "%s.max_stacks" % field_root, "expected integer number >= 1")
		valid = false
	if not _is_number(row["ticktime"]):
		_fail("invalid_field", "%s.ticktime" % field_root, "expected number")
		valid = false
	else:
		var ticktime := float(row["ticktime"])
		if ticktime < 0.0 and not is_equal_approx(ticktime, -1.0):
			_fail("invalid_field", "%s.ticktime" % field_root, "expected -1 or number >= 0")
			valid = false
	valid = _validate_modifiers(row["modifiers"], "%s.modifiers" % field_root) and valid
	valid = _validate_tick_effects(row["tick_effects"], "%s.tick_effects" % field_root) and valid
	return valid


static func _validate_type_tags(raw: String, field: String) -> bool:
	var tags := ZhandouEffectCodec.split_csv_tags(raw)
	if tags.is_empty():
		_fail("invalid_field", field, "must contain at least one tag")
		return false
	var valid := true
	for tag_v in tags:
		var tag := str(tag_v)
		if tag not in ALLOWED_TAGS:
			_fail("invalid_field", field, "unsupported tag '%s'" % tag)
			valid = false
	return valid


static func _validate_modifiers(raw: Variant, field: String) -> bool:
	if not raw is Array:
		_fail("invalid_field", field, "expected Array")
		return false
	var valid := true
	for index in (raw as Array).size():
		var row_v: Variant = (raw as Array)[index]
		var row_field := "%s[%d]" % [field, index]
		if not row_v is Array:
			_fail("invalid_effect", row_field, "expected positional Array")
			valid = false
			continue
		var cells := row_v as Array
		if cells.size() < 3 or str(cells[0]).strip_edges().to_lower() != "attrschange":
			_fail("invalid_effect", row_field, "expected [attrschange, attr, value]")
			valid = false
			continue
		var attr := str(cells[1]).strip_edges()
		if attr not in EnumPlayerAttr.ALL_COMBAT_KEYS:
			_fail("invalid_effect", "%s[1]" % row_field, "unknown combat attr '%s'" % attr)
			valid = false
		if not _is_numeric_cell(cells[2]):
			_fail("invalid_effect", "%s[2]" % row_field, "expected numeric value")
			valid = false
		if cells.size() > 3 and not _is_numeric_cell(cells[3]):
			_fail("invalid_effect", "%s[3]" % row_field, "expected numeric percent value")
			valid = false
	return valid


static func _validate_tick_effects(raw: Variant, field: String) -> bool:
	if not raw is Array:
		_fail("invalid_field", field, "expected Array")
		return false
	var valid := true
	for index in (raw as Array).size():
		var row_v: Variant = (raw as Array)[index]
		var row_field := "%s[%d]" % [field, index]
		if not row_v is Array:
			_fail("invalid_effect", row_field, "expected positional Array")
			valid = false
			continue
		var cells := row_v as Array
		if cells.size() < 2:
			_fail("invalid_effect", row_field, "expected effect id and value")
			valid = false
			continue
		var effect_id := str(cells[0]).strip_edges().to_lower()
		if not ZhandouEffectCodec.is_schema_effect_id(effect_id):
			_fail("invalid_effect", "%s[0]" % row_field, "unsupported effect '%s'" % effect_id)
			valid = false
		if not _is_numeric_cell(cells[1]):
			_fail("invalid_effect", "%s[1]" % row_field, "expected numeric value")
			valid = false
	return valid


static func _normalize_export_row(buff_id: String, raw: Dictionary) -> Dictionary:
	var row := raw.duplicate(true)
	row["id"] = buff_id
	row["tags"] = ZhandouEffectCodec.split_csv_tags(row["type"])
	var ticktime := float(row["ticktime"])
	row["ticktime"] = 0.0 if is_equal_approx(ticktime, -1.0) else ticktime
	row["modifiers"] = ZhandouEffectCodec.normalize_buff_modifiers(row["modifiers"])
	row["tick_effects"] = ZhandouEffectCodec.normalize_buff_tick_effects(row["tick_effects"])
	return row


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _is_numeric_cell(value: Variant) -> bool:
	if _is_number(value):
		return true
	return value is String and str(value).is_valid_float()


static func _fail(code: String, field: String, detail: String) -> void:
	push_error("[buff_catalog:%s] file=%s field=%s %s" % [code, PATH, field, detail])
