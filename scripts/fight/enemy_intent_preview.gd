class_name EnemyIntentPreview
extends RefCounted

const OVERLAY_DAMAGE := "damage"
const OVERLAY_SHIELD := "shield"

const _SHIELD_ICON := preload("res://assets/art/ui_new/hudun_icon.png")
const EnemyAiActionPickerScript := preload("res://scripts/fight/ai/enemy_ai_action_picker.gd")


static func enrich_skill_row(
		row: Dictionary,
		attacker: FightObj,
		defender: FightObj,
		skill_cfg: Dictionary,
		skill_id: int,
) -> Dictionary:
	if attacker == null or defender == null:
		return row
	var resolved_cfg := _attacker_skill_cfg(attacker, skill_cfg, skill_id)
	var overlay := _resolve_overlay(attacker, defender, resolved_cfg, skill_id)
	if overlay.is_empty():
		return row
	var out := row.duplicate(true)
	out.merge(overlay, true)
	return out


static func _resolve_overlay(
		attacker: FightObj,
		defender: FightObj,
		skill_cfg: Dictionary,
		skill_id: int,
) -> Dictionary:
	if skill_id == 0:
		var basic_damage := FightAttr.estimate_basic_damage(attacker.attrs, defender.attrs)
		if basic_damage <= 0.0:
			return {}
		return {
			"intent_overlay": OVERLAY_DAMAGE,
			"estimated_damage": _display_hp_damage(basic_damage, defender),
		}
	var damage_total := 0.0
	var has_shield := false
	var power_scale := float(skill_cfg.get("power", 1000.0)) / 1000.0
	var default_damage_type := _damage_type_from_cfg(skill_cfg)
	for eff_v in skill_cfg.get("effects", []) as Array:
		if not eff_v is Dictionary:
			continue
		var eff := eff_v as Dictionary
		var eff_type := str(eff.get("type", "")).strip_edges().to_lower()
		match eff_type:
			EnumCombatEffectType.LABEL_DAMAGE:
				if not _targets_player(eff):
					continue
				damage_total += FightAttr.estimate_skill_damage(
					attacker.attrs,
					defender.attrs,
					power_scale,
					_scaled_effect_value(attacker, eff),
					str(eff.get("damage_type", default_damage_type)),
					float(eff.get("armor_pierce", 0.0)),
				)
			EnumCombatEffectType.LABEL_SHIELD:
				has_shield = true
	if damage_total > 0.0:
		return {
			"intent_overlay": OVERLAY_DAMAGE,
			"estimated_damage": _display_hp_damage(damage_total, defender),
		}
	if has_shield or _cfg_has_shield_tag(skill_cfg):
		return {
			"intent_overlay": OVERLAY_SHIELD,
			"intent_icon": _SHIELD_ICON,
		}
	return {}


## 与 [method FightObj.use_skill] 一致：合并攻击方技能槽上的缩放与覆盖。
static func _attacker_skill_cfg(attacker: FightObj, skill_cfg: Dictionary, skill_id: int) -> Dictionary:
	if skill_id <= 0 or attacker == null or skill_cfg.is_empty():
		return skill_cfg
	var slot_index := EnemyAiActionPickerScript.find_skill_slot(attacker, skill_id)
	if slot_index < 0:
		return skill_cfg
	var slot := attacker.get_skill_slot_at(slot_index)
	if slot.is_empty():
		return skill_cfg
	return FightObj.merged_slot_runtime_cfg(slot, skill_cfg)


static func _targets_player(effect: Dictionary) -> bool:
	var target_key := str(effect.get("target", "")).strip_edges().to_lower()
	if target_key == EnumCombatTarget.LABEL_ENEMY:
		return true
	if target_key == "":
		return true
	return false


static func _scaled_effect_value(attacker: FightObj, effect: Dictionary) -> float:
	var value := float(effect.get("value", 0.0))
	var scaling_v: Variant = effect.get("scaling", {})
	if not scaling_v is Dictionary:
		return value
	for key in (scaling_v as Dictionary).keys():
		value += attacker.get_attr(str(key), 0.0) * float((scaling_v as Dictionary)[key])
	return value


static func _damage_type_from_cfg(cfg: Dictionary) -> String:
	var explicit := str(cfg.get("damage_type", "")).strip_edges().to_lower()
	if explicit in [FightAttr.DAMAGE_PHYSICAL, FightAttr.DAMAGE_MAGIC, FightAttr.DAMAGE_TRUE]:
		return explicit
	var tags_v: Variant = cfg.get("tags", [])
	if tags_v is Array:
		for tag_v in tags_v as Array:
			if str(tag_v).strip_edges().to_lower() == FightAttr.DAMAGE_PHYSICAL:
				return FightAttr.DAMAGE_PHYSICAL
			if str(tag_v).strip_edges().to_lower() == FightAttr.DAMAGE_TRUE:
				return FightAttr.DAMAGE_TRUE
	return FightAttr.DAMAGE_MAGIC


static func _cfg_has_shield_tag(cfg: Dictionary) -> bool:
	var tags_v: Variant = cfg.get("tags", [])
	if not tags_v is Array:
		return false
	for tag_v in tags_v as Array:
		if str(tag_v).strip_edges().to_lower() == "shield":
			return true
	return false


## 预览展示扣盾后的预计气血伤害，与 [method FightObj.be_attacked] 一致。
static func _hp_damage_after_shield(raw_damage: float, defender: FightObj) -> float:
	if defender == null or raw_damage <= 0.0:
		return maxf(0.0, raw_damage)
	var shield := maxf(0.0, defender.get_attr(FightAttr.SHIELD, 0.0))
	return maxf(0.0, raw_damage - shield)


static func _display_hp_damage(raw_damage: float, defender: FightObj) -> int:
	return maxi(0, int(roundf(_hp_damage_after_shield(raw_damage, defender))))
