class_name JsonLoader
extends RefCounted

const ITEMS_PATH := "res://data/item.json"
const DAO_TREE_PATH := "res://data/dao_tree.json"
const CULTIVATION_METHODS_PATH := "res://data/cultivation_methods.json"
const ABILITIES_PATH := "res://data/abilities.json"
const EFFECT_CATALOG_PATH := "res://data/effect_catalog.json"
const EQUIPS_PATH := "res://data/equip.json"
const BUFFS_PATH := "res://data/buff.json"
const COMBAT_VFX_INDEX_PATH := "res://data/combat/vfx_index.json"
const COMBAT_FLOAT_STYLES_PATH := "res://data/combat/float_styles.json"
const COMBAT_VFX_PRESETS_DIR := "res://data/combat/presets"
const ItemDefScript = preload("res://scripts/core/item_def.gd")
const EquipDefScript = preload("res://scripts/fight/equip_def.gd")
const BuffDefScript = preload("res://scripts/fight/buff_def.gd")

## 配置 JSON 中的文档用元数据键（加载后剔除）。
const JSON_COMMENT_KEYS: Array[String] = ["_comment", "_说明", "_doc", "_备注"]
const COMBAT_EFFECT_TYPES := {
	"damage": true,
	"heal": true,
	"shield": true,
	"restore_mp": true,
	"buff": true,
	"apply_buff": true,
	"buff_add": true,
}
const COMBAT_EFFECT_TARGETS := {"self": true, "enemy": true}


## 配置表 id 统一为 String（空串表示无效/缺省）。
static func config_id_to_string(v: Variant) -> String:
	return str(v).strip_edges()


static func _read_json_root_object(path: String) -> Dictionary:
	var v: Variant = _read_json_variant(path)
	if v == null:
		return {}
	if v is Dictionary:
		return v as Dictionary
	push_error("JsonLoader: root must be a JSON object: %s" % path)
	return {}


static func _read_json_variant(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("JsonLoader: file not found: %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("JsonLoader: invalid JSON: %s" % path)
		return null
	return parsed


static func load_items() -> Array:
	var parsed: Variant = _read_json_variant(ITEMS_PATH)
	var out: Array = []
	var raw: Array = []
	if parsed is Dictionary:
		var d := parsed as Dictionary
		if d.has("items") and d["items"] is Array:
			raw = d["items"] as Array
		else:
			push_error("JsonLoader: item.json object missing 'items' array")
			return out
	elif parsed is Array:
		raw = parsed as Array
	else:
		push_error("JsonLoader: item.json root must be object or array")
		return out
	for item in raw:
		if not item is Dictionary:
			continue
		var it = ItemDefScript.from_dict(item as Dictionary)
		if it != null:
			out.append(it)
	return out


static func _sort_skill_dict_keys(a: Variant, b: Variant) -> bool:
	var sa := str(a)
	var sb := str(b)
	if sa.is_valid_int() and sb.is_valid_int():
		return int(sa) < int(sb)
	return sa.naturalnocasecmp_to(sb) < 0


static func load_equips_bundle() -> Dictionary:
	var root := _read_json_root_object(EQUIPS_PATH)
	if root.is_empty():
		return {"equips": []}
	return {"equips": _parse_equip_rows(root.get("equips", {}))}


static func _parse_equip_rows(raw: Variant) -> Array:
	var equips_out: Array = []
	if not raw is Dictionary:
		push_error("JsonLoader: equip.json 'equips' must be an object keyed by equip id")
		return equips_out
	var d := raw as Dictionary
	var keys: Array = d.keys()
	keys.sort_custom(_sort_skill_dict_keys)
	for k in keys:
		var key_str := str(k).strip_edges()
		if not key_str.is_valid_int():
			push_error("JsonLoader: equip.json equips key must be numeric id, got '%s'" % key_str)
			continue
		var eid := int(key_str)
		if eid <= 0:
			push_error("JsonLoader: equip id must be positive, got %d" % eid)
			continue
		var row_v: Variant = d[k]
		if not row_v is Dictionary:
			push_error("JsonLoader: equip %d entry must be an object" % eid)
			continue
		var row := (row_v as Dictionary).duplicate(true)
		row["id"] = eid
		var equip = EquipDefScript.from_dict(row)
		if equip != null:
			equips_out.append(equip)
	return equips_out


static func load_buffs() -> Array:
	var root := _read_json_root_object(BUFFS_PATH)
	var out: Array = []
	if root.is_empty():
		return out
	var raw: Variant = root.get("buffs", {})
	if not raw is Dictionary:
		push_error("JsonLoader: buff.json 'buffs' must be an object keyed by buff id")
		return out
	var d := raw as Dictionary
	for k in d.keys():
		var bid := str(k).strip_edges()
		if bid == "":
			push_error("JsonLoader: buff.json buffs key must be non-empty string")
			continue
		var row_v: Variant = d[k]
		if not row_v is Dictionary:
			push_error("JsonLoader: buff '%s' entry must be an object" % bid)
			continue
		var row := (row_v as Dictionary).duplicate(true)
		row["id"] = bid
		_validate_combat_effects_schema(
			row.get("tick_effects", []),
			"buff.json buffs['%s'].tick_effects" % bid,
			false
		)
		var buff = BuffDefScript.from_dict(row)
		if buff != null:
			out.append(buff)
	return out


static func _validate_combat_effects_schema(raw: Variant, path_label: String, allow_target: bool) -> void:
	if raw == null:
		return
	if not raw is Array:
		push_error("JsonLoader: %s must be Array" % path_label)
		return
	for i in (raw as Array).size():
		var item_v: Variant = (raw as Array)[i]
		if not item_v is Dictionary:
			push_error("JsonLoader: %s[%d] must be object" % [path_label, i])
			continue
		var item := item_v as Dictionary
		var etype := str(item.get("type", "")).strip_edges().to_lower()
		if etype == "":
			push_error("JsonLoader: %s[%d].type is required" % [path_label, i])
			continue
		if not COMBAT_EFFECT_TYPES.has(etype):
			push_error("JsonLoader: %s[%d].type '%s' is unsupported" % [path_label, i, etype])
		if allow_target and item.has("target"):
			var target := str(item.get("target", "")).strip_edges().to_lower()
			if target != "" and not COMBAT_EFFECT_TARGETS.has(target):
				push_error("JsonLoader: %s[%d].target '%s' is unsupported" % [path_label, i, target])
		if etype in ["damage", "heal", "shield", "restore_mp"] and not item.has("value"):
			push_error("JsonLoader: %s[%d].value is required for type '%s'" % [path_label, i, etype])


static func strip_json_comments(variant: Variant) -> Variant:
	if variant is Dictionary:
		var out := {}
		for key in (variant as Dictionary).keys():
			var ks := str(key)
			if ks in JSON_COMMENT_KEYS:
				continue
			out[key] = strip_json_comments((variant as Dictionary)[key])
		return out
	if variant is Array:
		var arr: Array = []
		for item in variant as Array:
			arr.append(strip_json_comments(item))
		return arr
	return variant


static func normalize_combat_vfx_preset_id(ref: String) -> String:
	var s := ref.strip_edges()
	if s == "":
		return ""
	if s.ends_with(".json"):
		s = s.substr(0, s.length() - 5)
	var slash := s.rfind("/")
	if slash >= 0:
		s = s.substr(slash + 1)
	var backslash := s.rfind("\\")
	if backslash >= 0:
		s = s.substr(backslash + 1)
	return s


static func combat_vfx_preset_path(preset_id: String) -> String:
	var id := normalize_combat_vfx_preset_id(preset_id)
	if id == "":
		return ""
	return "%s/%s.json" % [COMBAT_VFX_PRESETS_DIR, id]


static func load_combat_float_styles() -> Dictionary:
	var raw: Variant = _read_json_variant(COMBAT_FLOAT_STYLES_PATH)
	if raw == null or not raw is Dictionary:
		return {"version": 1, "jitter_x": 18.0, "max_per_unit_per_frame": 6, "styles": {}}
	return strip_json_comments(raw) as Dictionary


static func load_combat_vfx_index() -> Dictionary:
	var raw: Variant = _read_json_variant(COMBAT_VFX_INDEX_PATH)
	if raw == null or not raw is Dictionary:
		return {"version": 1, "default": "melee_default", "impact_preset": "hit_default", "preset_dir": "presets"}
	return strip_json_comments(raw) as Dictionary


static func load_combat_vfx_preset_file(preset_ref: String) -> Dictionary:
	var path := combat_vfx_preset_path(preset_ref)
	if path == "" or not FileAccess.file_exists(path):
		push_warning("JsonLoader: combat vfx preset not found: %s" % path)
		return {}
	var raw: Variant = _read_json_variant(path)
	if raw == null or not raw is Dictionary:
		return {}
	return strip_json_comments(raw) as Dictionary


static func load_dao_tree() -> Dictionary:
	return _read_json_root_object(DAO_TREE_PATH)


static func load_cultivation_methods_bundle() -> Dictionary:
	return _read_json_root_object(CULTIVATION_METHODS_PATH)


static func load_abilities_bundle() -> Dictionary:
	return _read_json_root_object(ABILITIES_PATH)


static func load_effect_catalog() -> Dictionary:
	return _read_json_root_object(EFFECT_CATALOG_PATH)


static func load_combat_vfx_presets() -> Dictionary:
	var index := load_combat_vfx_index()
	var names: Array = []
	var dir := DirAccess.open(COMBAT_VFX_PRESETS_DIR)
	if dir != null:
		dir.list_dir_begin()
		var fn := dir.get_next()
		while fn != "":
			if not dir.current_is_dir() and fn.ends_with(".json"):
				names.append(fn.get_basename())
			fn = dir.get_next()
		dir.list_dir_end()
	return {
		"version": index.get("version", 1),
		"defaults": index.get("default", "melee_default"),
		"impact_preset": index.get("impact_preset", "hit_default"),
		"preset_names": names,
	}
