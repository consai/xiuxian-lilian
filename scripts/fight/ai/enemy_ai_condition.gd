class_name EnemyAiCondition
extends RefCounted

const EnemyAiActionPickerScript = preload("res://scripts/fight/ai/enemy_ai_action_picker.gd")


static func evaluate(when: Variant, ctx: EnemyAiContext) -> bool:
	if ctx == null:
		return false
	if when == null:
		return true
	if not when is Dictionary:
		return false
	var cond := when as Dictionary
	if cond.is_empty():
		return true
	for key in cond.keys():
		if not _eval_key(str(key), cond[key], ctx):
			return false
	return true


static func _eval_key(key: String, value: Variant, ctx: EnemyAiContext) -> bool:
	var enemy := ctx.self_unit
	var player := ctx.target
	match key:
		"self_hp_ratio_lte":
			return ctx.self_hp_ratio <= float(value)
		"self_hp_ratio_gte":
			return ctx.self_hp_ratio >= float(value)
		"target_hp_ratio_lte":
			return ctx.target_hp_ratio <= float(value)
		"target_hp_ratio_gte":
			return ctx.target_hp_ratio >= float(value)
		"self_mp_gte":
			return enemy != null and enemy.mp >= float(value)
		"skill_ready":
			return EnemyAiActionPickerScript.can_use_skill(enemy, int(value), ctx.skill_cfg)
		"skill_on_cd":
			var sid := int(value)
			var slot_index := EnemyAiActionPickerScript.find_skill_slot(enemy, sid)
			if slot_index < 0:
				return true
			return enemy.get_skill_cd_at(slot_index) > 0.0
		"has_buff":
			return _has_buff(enemy, str(value))
		"not_has_buff":
			return not _has_buff(enemy, str(value))
		"item_count_gte":
			return _item_count_gte(enemy, value)
		"equip_ready":
			return _equip_ready(enemy, value, ctx.equip_cfg)
		"battle_elapsed_gte":
			return ctx.battle_elapsed >= float(value)
		_:
			return false


static func _has_buff(unit: FightObj, buff_id: String) -> bool:
	if unit == null:
		return false
	var bid := buff_id.strip_edges()
	if bid == "":
		return false
	return unit.buffs.has(bid)


static func _item_count_gte(enemy: FightObj, value: Variant) -> bool:
	if enemy == null or not value is Dictionary:
		return false
	var spec := value as Dictionary
	var slot_index := int(spec.get("slot", 0))
	var need := int(spec.get("count", 1))
	var slot := enemy.get_item_slot_at(slot_index)
	if slot.is_empty():
		return false
	if int(slot.get("id", -1)) < 0:
		return false
	return int(slot.get("count", 0)) >= need


static func _equip_ready(enemy: FightObj, value: Variant, equip_cfg: Dictionary) -> bool:
	var slot_index := 0
	if value is Dictionary:
		slot_index = int((value as Dictionary).get("slot", 0))
	elif value is int or value is float:
		slot_index = int(value)
	return EnemyAiActionPickerScript.can_use_equip(enemy, slot_index, equip_cfg)
