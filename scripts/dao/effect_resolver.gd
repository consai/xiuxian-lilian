class_name EffectResolver
extends RefCounted

const ZhandouAttrScript := preload("res://scripts/zhandou/zhandou_attr.gd")

const EFFECT_TO_FIGHT := {
	"damage_spiritual": {"type": EnumCombatEffectType.LABEL_DAMAGE, "damage_type": "magic"},
	"damage_sword": {"type": EnumCombatEffectType.LABEL_DAMAGE, "damage_type": "magic"},
	"damage_sword_area": {"type": EnumCombatEffectType.LABEL_DAMAGE, "damage_type": "magic"},
	"damage_elemental": {"type": EnumCombatEffectType.LABEL_DAMAGE, "damage_type": "magic"},
	"damage_physical": {"type": EnumCombatEffectType.LABEL_DAMAGE, "damage_type": "physical"},
	"damage_physical_area": {"type": EnumCombatEffectType.LABEL_DAMAGE, "damage_type": "physical"},
	"damage_thunder": {"type": EnumCombatEffectType.LABEL_DAMAGE, "damage_type": "magic"},
	"damage_spirit": {"type": EnumCombatEffectType.LABEL_DAMAGE, "damage_type": "magic"},
	"damage_spirit_sword": {"type": EnumCombatEffectType.LABEL_DAMAGE, "damage_type": "magic"},
	"damage_void": {"type": EnumCombatEffectType.LABEL_DAMAGE, "damage_type": "true"},
	"damage_law": {"type": EnumCombatEffectType.LABEL_DAMAGE, "damage_type": "true"},
	"damage_law_area": {"type": EnumCombatEffectType.LABEL_DAMAGE, "damage_type": "true"},
	"damage_tribulation": {"type": EnumCombatEffectType.LABEL_DAMAGE, "damage_type": "true"},
	"damage_true": {"type": EnumCombatEffectType.LABEL_DAMAGE, "damage_type": "true"},
	"shield_flat": {"type": EnumCombatEffectType.LABEL_SHIELD},
	"shield_spiritual": {"type": EnumCombatEffectType.LABEL_SHIELD},
	"heal_hp": {"type": EnumCombatEffectType.LABEL_HEAL},
	"restore_mana": {"type": EnumCombatEffectType.LABEL_RESTORE_MP},
	"mana_regen": {ZhandouAttrScript.MP_REGEN: true},
	"max_mana": {ZhandouAttrScript.MP_MAX: true},
	"max_hp": {ZhandouAttrScript.HP_MAX: true},
	"max_health": {ZhandouAttrScript.HP_MAX: true},
	"health_regen": {ZhandouAttrScript.HP_REGEN: true},
	"physical_attack": {ZhandouAttrScript.PHYSICAL_ATK: true},
	"magic_attack": {ZhandouAttrScript.MAGIC_ATK: true},
	"physical_defense": {ZhandouAttrScript.PHYSICAL_DEF: true},
	"magic_defense": {ZhandouAttrScript.MAGIC_DEF: true},
	"damage_bonus": {ZhandouAttrScript.DAMAGE_BONUS: true},
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
	"all_resistance": {ZhandouAttrScript.PHYSICAL_DEF: true, ZhandouAttrScript.MAGIC_DEF: true},
	"mental_resistance": {ZhandouAttrScript.MAGIC_DEF: true},
	# 知识/功法被动：与战斗内 evasion_window 短时提速同属性，永久叠到出手速度
	"evasion_window": {ZhandouAttrScript.SPD: true},
}

const COMBAT_MODIFIER_EFFECTS := {
	"evasion_window": {
		"type": EnumCombatEffectType.LABEL_TIMED_MODIFIER, "target": EnumZhandouTarget.LABEL_SELF, "stat": ZhandouAttrScript.SPD,
		"duration": 2.0, "name": "流风护身", "percent": true,
	},
	"elemental_vulnerability": {
		"type": EnumCombatEffectType.LABEL_TIMED_MODIFIER, "target": EnumZhandouTarget.LABEL_ENEMY, "stat": ZhandouAttrScript.DAMAGE_TAKEN,
		"duration": 5.0, "name": "五行易伤",
	},
	"spirit_suppression": {
		"type": EnumCombatEffectType.LABEL_TIMED_MODIFIER, "target": EnumZhandouTarget.LABEL_ENEMY, "stat": ZhandouAttrScript.CONTROL_RESIST,
		"duration": 4.0, "name": "神识压制", "negative": true, "percent": true,
	},
	"enemy_all_resistance": {
		"type": EnumCombatEffectType.LABEL_TIMED_MODIFIER, "target": EnumZhandouTarget.LABEL_ENEMY, "stat": ZhandouAttrScript.DAMAGE_TAKEN,
		"duration": 6.0, "name": "抗性崩解", "invert_negative": true,
	},
	"tribulation_mark": {
		"type": EnumCombatEffectType.LABEL_TIMED_MODIFIER, "target": EnumZhandouTarget.LABEL_ENEMY, "stat": ZhandouAttrScript.DAMAGE_TAKEN,
		"duration": 10.0, "name": "劫痕",
	},
	"healing_reduction": {
		"type": EnumCombatEffectType.LABEL_TIMED_MODIFIER, "target": EnumZhandouTarget.LABEL_ENEMY, "stat": ZhandouAttrScript.HP_REGEN,
		"duration": 8.0, "name": "疗愈阻断", "negative": true, "percent": true,
	},
}

const COMBAT_CONTROL_EFFECTS := {
	"stagger_power": {"duration": 0.6, "name": "踉跄"},
	"control_duration": {"duration_from_value": true, "name": "封印"},
	"stun_chance": {"duration": 1.0, "name": "麻痹"},
	"delay_special_action_chance": {"duration": 0.4, "duration_from_value": true, "name": "延缓"},
	"knockdown_duration": {"duration_from_value": true, "name": "击倒"},
	"law_suppression": {"duration": 1.5, "duration_from_value": true, "name": "律令压制"},
}

const PRESENTATION_ONLY_EFFECTS := {
	"dash_distance": true,
	"array_duration": true,
	"remote_control_range": true,
	"controlled_entity_damage": true,
	"command_duration": true,
	"damage_spirit_over_time": true,
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
		var mapping: Variant = EFFECT_TO_FIGHT.get(effect_id)
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


static func resolve_combat_effects(effect_rows: Array) -> Array:
	var out: Array = []
	for effect_v in effect_rows:
		if not effect_v is Dictionary:
			continue
		var effect := effect_v as Dictionary
		var effect_id := str(effect.get("effectId", ""))
		var magnitude := float(effect.get("base", 0.0))
		if effect.has("clampMin"):
			magnitude = maxf(magnitude, float(effect["clampMin"]))
		if effect.has("clampMax"):
			magnitude = minf(magnitude, float(effect["clampMax"]))
		var mapping: Variant = EFFECT_TO_FIGHT.get(effect_id)
		if mapping is Dictionary and (mapping as Dictionary).has("type"):
			var map := mapping as Dictionary
			var row := {
				"type": str(map.get("type", EnumCombatEffectType.LABEL_DAMAGE)),
				"value": magnitude,
				"target": str(effect.get("target", EnumZhandouTarget.LABEL_ENEMY)),
			}
			if map.has("damage_type"):
				row["damage_type"] = str(map["damage_type"])
			out.append(row)
			continue
		var modifier_v: Variant = COMBAT_MODIFIER_EFFECTS.get(effect_id)
		if modifier_v is Dictionary:
			var modifier := modifier_v as Dictionary
			var value := -absf(magnitude) if bool(modifier.get("negative", false)) else magnitude
			if bool(modifier.get("invert_negative", false)) and magnitude < 0.0:
				value = absf(magnitude)
			var modifier_row := {
				"type": EnumCombatEffectType.LABEL_TIMED_MODIFIER,
				"id": "ability_%s" % effect_id,
				"name": str(modifier.get("name", effect_id)),
				"target": str(modifier.get("target", effect.get("target", EnumZhandouTarget.LABEL_ENEMY))),
				"duration": float(modifier.get("duration", 3.0)),
			}
			if bool(modifier.get("percent", false)):
				modifier_row["percent_modifiers"] = {str(modifier["stat"]): value}
			else:
				modifier_row["modifiers"] = {str(modifier["stat"]): value}
			out.append(modifier_row)
			continue
		var control_v: Variant = COMBAT_CONTROL_EFFECTS.get(effect_id)
		if control_v is Dictionary:
			var control := control_v as Dictionary
			out.append({
				"type": EnumCombatEffectType.LABEL_CONTROL,
				"id": "ability_%s" % effect_id,
				"name": str(control.get("name", effect_id)),
				"target": str(effect.get("target", EnumZhandouTarget.LABEL_ENEMY)),
				"duration": magnitude if bool(control.get("duration_from_value", false)) else float(control.get("duration", 0.5)),
			})
			continue
		if effect_id == "armor_pierce":
			_apply_pierce_to_previous_damage(out, magnitude)
			continue
		if effect_id in ["space_pierce", "law_pierce"]:
			_apply_pierce_to_previous_damage(out, magnitude)
			continue
		# These effects need battlefield entities or channel systems that are not present in v1.
		if PRESENTATION_ONLY_EFFECTS.has(effect_id):
			continue
	return out


static func _apply_pierce_to_previous_damage(out: Array, magnitude: float) -> void:
	for index in range(out.size() - 1, -1, -1):
		var previous := out[index] as Dictionary
		if str(previous.get("type", "")) == EnumCombatEffectType.LABEL_DAMAGE:
			previous["armor_pierce"] = magnitude
			break


static func has_combat_mapping(effect_id: String) -> bool:
	return EFFECT_TO_FIGHT.has(effect_id) or COMBAT_MODIFIER_EFFECTS.has(effect_id) \
		or COMBAT_CONTROL_EFFECTS.has(effect_id) or effect_id == "armor_pierce" \
		or effect_id in ["space_pierce", "law_pierce"] or PRESENTATION_ONLY_EFFECTS.has(effect_id)


static func has_method_mapping(effect_id: String) -> bool:
	var mapping: Variant = EFFECT_TO_FIGHT.get(effect_id)
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
