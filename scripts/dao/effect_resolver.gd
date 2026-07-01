class_name EffectResolver
extends RefCounted

const ZhandouAttrScript := preload("res://scripts/zhandou/zhandou_attr.gd")

## 即时战斗效果；键名与 EnumZhandouActiveEffect 一致。
const INSTANT_COMBAT_EFFECTS := {
	"damage": {"type": EnumCombatEffectType.LABEL_DAMAGE},
	"shield": {"type": EnumCombatEffectType.LABEL_SHIELD},
	"heal_hp": {"type": EnumCombatEffectType.LABEL_HEAL},
	"restore_mana": {"type": EnumCombatEffectType.LABEL_RESTORE_MP},
}

## 属性修正；功法/战斗被动共用映射，旧 ID 保留兼容功法配置。
const EFFECT_TO_FIGHT := {
	"cast_speed": {ZhandouAttrScript.SPD: true},
	"physical_def": {ZhandouAttrScript.PHYSICAL_DEF: true},
	"magic_def": {ZhandouAttrScript.MAGIC_DEF: true},
	"all_resistance": {ZhandouAttrScript.PHYSICAL_DEF: true, ZhandouAttrScript.MAGIC_DEF: true},
	"damage_bonus": {ZhandouAttrScript.DAMAGE_BONUS: true},
	"hp_regen": {ZhandouAttrScript.HP_REGEN: true},
	"control_resist": {ZhandouAttrScript.CONTROL_RESIST: true},
	"max_hp": {ZhandouAttrScript.HP_MAX: true},
	"evasion_window": {ZhandouAttrScript.SPD: true},
	"mana_regen": {ZhandouAttrScript.MP_REGEN: true},
	"max_mana": {ZhandouAttrScript.MP_MAX: true},
	"max_health": {ZhandouAttrScript.HP_MAX: true},
	"health_regen": {ZhandouAttrScript.HP_REGEN: true},
	"physical_attack": {ZhandouAttrScript.PHYSICAL_ATK: true},
	"magic_attack": {ZhandouAttrScript.MAGIC_ATK: true},
	"physical_defense": {ZhandouAttrScript.PHYSICAL_DEF: true},
	"magic_defense": {ZhandouAttrScript.MAGIC_DEF: true},
	"sword_damage": {ZhandouAttrScript.DAMAGE_BONUS: true},
	"spell_damage": {ZhandouAttrScript.DAMAGE_BONUS: true},
	"thunder_damage": {ZhandouAttrScript.DAMAGE_BONUS: true},
	"melee_damage": {ZhandouAttrScript.DAMAGE_BONUS: true},
	"spirit_power": {ZhandouAttrScript.DAMAGE_BONUS: true},
	"poison_power": {ZhandouAttrScript.DAMAGE_BONUS: true},
	"curse_power": {ZhandouAttrScript.DAMAGE_BONUS: true},
	"tribulation_damage": {ZhandouAttrScript.DAMAGE_BONUS: true},
	"physical_resistance": {ZhandouAttrScript.PHYSICAL_DEF: true},
	"spiritual_resistance": {ZhandouAttrScript.MAGIC_DEF: true},
	"mental_resistance": {ZhandouAttrScript.MAGIC_DEF: true},
	"soul_resistance": {ZhandouAttrScript.MAGIC_DEF: true},
	"tribulation_resistance": {ZhandouAttrScript.MAGIC_DEF: true},
	"control_resistance": {ZhandouAttrScript.CONTROL_RESIST: true},
}


static func resolve_method_modifiers(effects: Array, mastery: float, knowledge_bonus: float = 1.0) -> Dictionary:
	var flat: Dictionary = {}
	var percent: Dictionary = {}
	for effect_v in effects:
		if not effect_v is Dictionary:
			continue
		var effect := effect_v as Dictionary
		var effect_id := str(effect.get("effectId", ""))
		var base := float(effect.get("base", 0.0))
		var growth := float(effect.get("masteryGrowth", 0.0))
		var magnitude := (base + growth * clampf(mastery, 0.0, 1.0)) * knowledge_bonus
		var operation := str(effect.get("operation", "add_flat"))
		var mapping: Variant = _attr_mapping(effect_id)
		if mapping is Dictionary:
			var map := mapping as Dictionary
			if map.has("type"):
				continue
			for attr_key in map.keys():
				var attr_name := str(attr_key)
				if operation == "add_percent":
					percent[attr_name] = float(percent.get(attr_name, 0.0)) + magnitude
				else:
					flat[attr_name] = float(flat.get(attr_name, 0.0)) + magnitude
	return {"flat": flat, "percent": percent}


static func _runtime_target_fields(skill_target: String, skill_target_arg: String = "") -> Dictionary:
	var pair := EnumZhandouTargetArg.normalize_pair(skill_target, skill_target_arg)
	var out := {"target": str(pair.get("target", EnumZhandouTarget.LABEL_ENEMY))}
	var target_arg := str(pair.get("target_arg", ""))
	if target_arg != "":
		out["target_arg"] = target_arg
	return out


static func resolve_combat_effects(
		effect_rows: Array,
		skill_target: String = EnumZhandouTarget.LABEL_ENEMY,
		skill_target_arg: String = ""
) -> Array:
	var out: Array = []
	var skill_target_fields := _runtime_target_fields(skill_target, skill_target_arg)
	for effect_v in effect_rows:
		if effect_v is Array:
			var positional := ZhandouEffectCodec.parse_positional_runtime(effect_v as Array)
			if positional.is_empty():
				continue
			var row := positional.duplicate(true)
			if not row.has("target"):
				row["target"] = skill_target_fields["target"]
				if skill_target_fields.has("target_arg"):
					row["target_arg"] = skill_target_fields["target_arg"]
			out.append(row)
			continue
		if not effect_v is Dictionary:
			continue
		var effect := effect_v as Dictionary
		if effect.has("type") and not effect.has("effectId"):
			var runtime_row := effect.duplicate(true)
			if not runtime_row.has("target"):
				runtime_row["target"] = skill_target_fields["target"]
				if skill_target_fields.has("target_arg"):
					runtime_row["target_arg"] = skill_target_fields["target_arg"]
			out.append(runtime_row)
			continue
		var effect_id := str(effect.get("effectId", ""))
		var magnitude := float(effect.get("base", 0.0))
		if effect.has("clampMin"):
			magnitude = maxf(magnitude, float(effect["clampMin"]))
		if effect.has("clampMax"):
			magnitude = minf(magnitude, float(effect["clampMax"]))
		var instant_v: Variant = INSTANT_COMBAT_EFFECTS.get(effect_id)
		if instant_v is Dictionary:
			var instant := instant_v as Dictionary
			var row := {
				"type": str(instant.get("type", EnumCombatEffectType.LABEL_DAMAGE)),
				"value": magnitude,
				"target": skill_target_fields["target"],
			}
			if skill_target_fields.has("target_arg"):
				row["target_arg"] = skill_target_fields["target_arg"]
			out.append(row)
			continue
		# exportjson 表格式经 AbilityExportAdapter 落成 effectId+buffId 字典
		if effect_id == EnumZhandouActiveEffect.LABEL_BUFF:
			var buff_id := str(effect.get("buffId", "")).strip_edges()
			if buff_id == "":
				continue
			var buff_row := {
				"type": EnumCombatEffectType.LABEL_APPLY_BUFF,
				"id": buff_id,
				"target": skill_target_fields["target"],
			}
			if skill_target_fields.has("target_arg"):
				buff_row["target_arg"] = skill_target_fields["target_arg"]
			out.append(buff_row)
			continue
		# cast_speed 等由 attrschange 展开的属性修正走功法/被动管线，战斗主动 v1 仅产出即时效果
		if effect_id == "cast_speed":
			continue
	return out


static func _attr_mapping(effect_id: String) -> Variant:
	return EFFECT_TO_FIGHT.get(effect_id)


static func has_combat_mapping(effect_id: String) -> bool:
	if EnumZhandouActiveEffect.is_valid_label(effect_id):
		return true
	# attrschange 经 ZhandouEffectCodec 展开为具体属性 effectId
	for mapped_v in ZhandouEffectCodec.ATTR_EXPORT_TO_EFFECT_ID.values():
		if str(mapped_v) == effect_id:
			return true
	return false


static func has_method_mapping(effect_id: String) -> bool:
	if EnumZhandouPassiveEffect.is_valid_label(effect_id):
		return _attr_mapping(effect_id) is Dictionary
	var mapping: Variant = _attr_mapping(effect_id)
	return mapping is Dictionary and not (mapping as Dictionary).has("type") \
		or effect_id == "combat_mp_restore_2s"


static func combat_mp_restore_from_method(effects: Array, mastery: float) -> float:
	for effect_v in effects:
		if not effect_v is Dictionary:
			continue
		var effect := effect_v as Dictionary
		if str(effect.get("effectId", "")) == "combat_mp_restore_2s":
			return float(effect.get("base", 0.0)) + float(effect.get("masteryGrowth", 0.0)) * clampf(mastery, 0.0, 1.0)
	return 0.0
