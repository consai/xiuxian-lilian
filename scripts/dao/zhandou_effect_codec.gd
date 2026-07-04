class_name ZhandouEffectCodec
extends RefCounted

## 解析 exportjson 中 positional effects。

const SCHEMA_PATH := "res://data/exportjson/战斗effects效果介绍.json"

## 导出表属性名 → ZhandouAttr 键。
const ATTR_EXPORT_TO_FIGHT: Dictionary = {
	"castspd": ZhandouAttr.SPD,
	"spd": ZhandouAttr.SPD,
	"atk": ZhandouAttr.PHYSICAL_ATK,
	"physical_atk": ZhandouAttr.PHYSICAL_ATK,
	"magic_atk": ZhandouAttr.MAGIC_ATK,
	"def": ZhandouAttr.PHYSICAL_DEF,
	"physical_def": ZhandouAttr.PHYSICAL_DEF,
	"magic_def": ZhandouAttr.MAGIC_DEF,
	"hp_max": ZhandouAttr.HP_MAX,
	"mp_max": ZhandouAttr.MP_MAX,
	"hp_regen": ZhandouAttr.HP_REGEN,
	"mp_regen": ZhandouAttr.MP_REGEN,
	"damage_bonus": ZhandouAttr.DAMAGE_BONUS,
	"control_resist": ZhandouAttr.CONTROL_RESIST,
}

## attrschange 属性 → 技能配置 effectId（供校验/悬停）。
const ATTR_EXPORT_TO_EFFECT_ID: Dictionary = {
	"castspd": "cast_speed",
	"spd": "cast_speed",
	"atk": "physical_attack",
	"physical_atk": "physical_attack",
	"magic_atk": "magic_attack",
	"def": "physical_defense",
	"physical_def": "physical_defense",
	"magic_def": "magic_defense",
	"hp_max": "max_hp",
	"mp_max": "max_mana",
	"hp_regen": "hp_regen",
	"mp_regen": "mana_regen",
	"damage_bonus": "damage_bonus",
	"control_resist": "control_resist",
}

static var _schema: Dictionary = {}


static func load_schema() -> Dictionary:
	if not _schema.is_empty():
		return _schema
	_schema = JsonLoader.load_zhandou_effect_schema()
	return _schema


static func is_null_sentinel(value: Variant) -> bool:
	if value == null:
		return true
	var s := str(value).strip_edges().to_lower()
	return s == "" or s == "null" or s == "~"


static func split_csv_tags(raw: Variant) -> Array:
	if raw is Array:
		var out: Array = []
		for item_v in raw as Array:
			var token := str(item_v).strip_edges()
			if token == "" or token == "[]":
				continue
			for part in token.split(",", false):
				var p := str(part).strip_edges()
				if p != "":
					out.append(p)
		return out
	var text := str(raw).strip_edges()
	if text == "" or text == "[]":
		return []
	var tags: Array = []
	for part in text.split(",", false):
		var p := str(part).strip_edges()
		if p != "":
			tags.append(p)
	return tags


static func schema_effect_ids() -> Array[String]:
	var out: Array[String] = []
	for key in load_schema().keys():
		out.append(str(key))
	return out


static func is_schema_effect_id(effect_id: String) -> bool:
	return load_schema().has(effect_id.strip_edges().to_lower())


## 将一行 positional cells 解析为战斗运行时效果字典（含 type/value/scaling）。
static func parse_positional_runtime(cells: Array) -> Dictionary:
	if cells.is_empty():
		return {}
	if not cells[0] is String:
		return {}
	var effect_id := str(cells[0]).strip_edges().to_lower()
	match effect_id:
		"damage", "shield", "heal_hp", "restore_mana":
			return _parse_scaled_instant(effect_id, cells)
		"attrschange":
			return _parse_attrschange_runtime(cells)
		"buff":
			return _parse_buff_runtime(cells)
		"damage_def", "damage_add":
			return _parse_damage_mod_runtime(effect_id, cells)
		_:
			return {}


## 将一行 positional cells 解析为技能配置 effects[] 项（effectId/base/operation...）。
static func parse_positional_config(cells: Array) -> Dictionary:
	if cells.is_empty():
		return {}
	var effect_id := str(cells[0]).strip_edges().to_lower()
	match effect_id:
		"damage", "shield", "heal_hp", "restore_mana":
			var base := _cell_float(cells, 1, 0.0)
			return _default_config_effect(effect_id, base, "add_flat")
		"attrschange":
			return _parse_attrschange_config(cells)
		"buff":
			var buff_id := _cell_string(cells, 1, "")
			if buff_id == "":
				return {}
			return {
				"effectId": "buff",
				"base": 0.0,
				"operation": "add_flat",
				"stackGroup": "buff:%s" % buff_id,
				"stackPolicy": "ability_instance",
				"scalingMode": "positive",
				"buffId": buff_id,
			}
		"damage_def", "damage_add":
			var flat := _cell_float(cells, 1, 0.0)
			var mapped := "physical_def" if effect_id == "damage_def" else "damage_bonus"
			return _default_config_effect(mapped, flat, "add_flat")
		_:
			return {}


static func parse_positional_effects(
		effects_v: Variant,
		caster_attrs: Dictionary = {},
		target_attrs: Dictionary = {}
) -> Array:
	var out: Array = []
	if not effects_v is Array:
		return out
	for row_v in effects_v as Array:
		if row_v is Array:
			var runtime := parse_positional_runtime(row_v as Array)
			if runtime.is_empty():
				continue
			if not caster_attrs.is_empty() or not target_attrs.is_empty():
				runtime["value"] = _resolve_scaled_value(row_v as Array, caster_attrs, target_attrs)
			out.append(runtime)
	return out


static func parse_positional_config_effects(effects_v: Variant) -> Array:
	var out: Array = []
	if not effects_v is Array:
		return out
	for row_v in effects_v as Array:
		if not row_v is Array:
			continue
		var cfg := parse_positional_config(row_v as Array)
		if not cfg.is_empty():
			out.append(cfg)
	return out


static func normalize_buff_modifiers(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		return (raw as Dictionary).duplicate(true)
	if not raw is Array:
		return {}
	var flat: Dictionary = {}
	var percent: Dictionary = {}
	for row_v in raw as Array:
		if not row_v is Array:
			continue
		var cells := row_v as Array
		if cells.is_empty() or str(cells[0]).strip_edges().to_lower() != "attrschange":
			continue
		var attr_key := _export_attr_key(cells, 1)
		if attr_key == "":
			continue
		var flat_val := _cell_float(cells, 2, 0.0)
		var pct_val := _cell_float(cells, 3, 0.0)
		if flat_val != 0.0:
			flat[attr_key] = float(flat.get(attr_key, 0.0)) + flat_val
		if pct_val != 0.0:
			percent[attr_key] = float(percent.get(attr_key, 0.0)) + pct_val / 1000.0
	var out := flat.duplicate(true)
	if not percent.is_empty():
		out["_percent"] = percent
	return out


static func normalize_buff_tick_effects(raw: Variant) -> Array:
	if raw is Array:
		var out: Array = []
		for row_v in raw as Array:
			if row_v is Array:
				var runtime := parse_positional_runtime(row_v as Array)
				if not runtime.is_empty():
					out.append(runtime)
			elif row_v is Dictionary:
				out.append((row_v as Dictionary).duplicate(true))
		return out
	return []


static func _parse_scaled_instant(effect_id: String, cells: Array) -> Dictionary:
	var runtime_type := effect_id
	if effect_id == "heal_hp":
		runtime_type = EnumCombatEffectType.LABEL_HEAL
	elif effect_id == "restore_mana":
		runtime_type = EnumCombatEffectType.LABEL_RESTORE_MP
	return {
		"type": runtime_type,
		"value": _cell_float(cells, 1, 0.0),
		"_cells": cells.duplicate(true),
	}


static func _parse_attrschange_runtime(cells: Array) -> Dictionary:
	var attr_key := _export_attr_key(cells, 1)
	if attr_key == "":
		return {}
	var flat_val := _cell_float(cells, 2, 0.0)
	var pct_val := _cell_float(cells, 3, 0.0)
	return {
		"type": EnumCombatEffectType.LABEL_TIMED_MODIFIER,
		"id": "attrschange:%s" % attr_key,
		"modifiers": {attr_key: flat_val} if flat_val != 0.0 else {},
		"percent_modifiers": {attr_key: pct_val / 1000.0} if pct_val != 0.0 else {},
		"duration": 0.0,
	}


static func _parse_buff_runtime(cells: Array) -> Dictionary:
	var buff_id := _cell_string(cells, 1, "")
	if buff_id == "":
		return {}
	return {
		"type": EnumCombatEffectType.LABEL_APPLY_BUFF,
		"id": buff_id,
	}


static func _parse_damage_mod_runtime(effect_id: String, cells: Array) -> Dictionary:
	var attr_key := ZhandouAttr.DAMAGE_TAKEN if effect_id == "damage_def" else ZhandouAttr.DAMAGE_BONUS
	var flat_val := _cell_float(cells, 1, 0.0)
	var pct_val := _cell_float(cells, 2, 0.0)
	return {
		"type": EnumCombatEffectType.LABEL_TIMED_MODIFIER,
		"id": effect_id,
		"modifiers": {attr_key: flat_val} if flat_val != 0.0 else {},
		"percent_modifiers": {attr_key: pct_val / 1000.0} if pct_val != 0.0 else {},
		"duration": 0.0,
	}


static func _parse_attrschange_config(cells: Array) -> Dictionary:
	var export_attr := _cell_string(cells, 1, "").to_lower()
	var effect_id := str(ATTR_EXPORT_TO_EFFECT_ID.get(export_attr, export_attr))
	if effect_id == "":
		return {}
	var flat_val := _cell_float(cells, 2, 0.0)
	var pct_val := _cell_float(cells, 3, 0.0)
	var operation := "add_percent" if pct_val != 0.0 and flat_val == 0.0 else "add_flat"
	var base := pct_val / 1000.0 if operation == "add_percent" else flat_val
	var out := _default_config_effect(effect_id, base, operation)
	if operation == "add_percent":
		out["clampMin"] = 0.0
		out["clampMax"] = 2.0
	return out


static func _default_config_effect(effect_id: String, base: float, operation: String) -> Dictionary:
	return {
		"effectId": effect_id,
		"base": base,
		"operation": operation,
		"stackGroup": effect_id,
		"stackPolicy": "ability_instance",
		"scalingMode": "positive",
	}


static func _resolve_scaled_value(cells: Array, caster_attrs: Dictionary, target_attrs: Dictionary) -> float:
	var effect_id := str(cells[0]).strip_edges().to_lower()
	if effect_id not in ["damage", "shield", "heal_hp", "restore_mana"]:
		return _cell_float(cells, 1, 0.0)
	var total := _cell_float(cells, 1, 0.0)
	var self_attr := _export_attr_key(cells, 2)
	var self_pct := _cell_float(cells, 3, 0.0)
	if self_attr != "" and self_pct != 0.0:
		total += ZhandouAttr.get_attr(caster_attrs, self_attr, 0.0) * self_pct / 1000.0
	var target_attr := _export_attr_key(cells, 4)
	var target_pct := _cell_float(cells, 5, 0.0)
	if target_attr != "" and target_pct != 0.0:
		total += ZhandouAttr.get_attr(target_attrs, target_attr, 0.0) * target_pct / 1000.0
	return total


static func _export_attr_key(cells: Array, index: int) -> String:
	var export_name := _cell_string(cells, index, "").to_lower()
	if export_name == "":
		return ""
	return str(ATTR_EXPORT_TO_FIGHT.get(export_name, export_name))


static func _cell_string(cells: Array, index: int, fallback: String) -> String:
	if index >= cells.size():
		return fallback
	if is_null_sentinel(cells[index]):
		return fallback
	return str(cells[index]).strip_edges()


static func _cell_float(cells: Array, index: int, fallback: float) -> float:
	var s := _cell_string(cells, index, "")
	if s == "":
		return fallback
	if s.is_valid_float():
		return float(s)
	if s.is_valid_int():
		return float(int(s))
	return fallback
