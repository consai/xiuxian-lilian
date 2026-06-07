class_name EnemyAiActionPicker
extends RefCounted

const EnemyAiTypesScript = preload("res://scripts/fight/ai/enemy_ai_types.gd")


static func find_skill_slot(enemy: FightObj, skill_id: int) -> int:
	if enemy == null or not enemy.skills is Array:
		return -1
	for i in (enemy.skills as Array).size():
		var slot := enemy.get_skill_slot_at(i)
		if slot.is_empty():
			continue
		if int(slot.get("id", -1)) == skill_id:
			return i
	return -1


static func find_basic_slot(enemy: FightObj) -> int:
	if enemy == null or not enemy.skills is Array:
		return -1
	for i in (enemy.skills as Array).size():
		if int(enemy.get_skill_slot_at(i).get("id", -1)) == 0:
			return i
	return -1


static func can_use_skill(enemy: FightObj, skill_id: int, skill_cfg: Dictionary) -> bool:
	if enemy == null or skill_id <= 0:
		return false
	var slot_index := find_skill_slot(enemy, skill_id)
	if slot_index < 0:
		return false
	return _is_skill_usable_at_slot(enemy, slot_index, skill_id, skill_cfg)


static func can_use_basic(enemy: FightObj) -> bool:
	return find_basic_slot(enemy) >= 0


static func can_use_item(enemy: FightObj, slot_index: int, item_cfg: Dictionary) -> bool:
	if enemy == null or slot_index < 0:
		return false
	var slot := enemy.get_item_slot_at(slot_index)
	if slot.is_empty():
		return false
	var item_id := int(slot.get("id", -1))
	if item_id < 0:
		return false
	if float(slot.get("cd", 0.0)) > 0.0:
		return false
	if int(slot.get("count", 0)) <= 0:
		return false
	var cfg := FightObj._lookup_cfg(item_cfg, item_id)
	if cfg.is_empty():
		return false
	var mp_cost := float(cfg.get("mp_cost", 0.0))
	return mp_cost <= 0.0 or enemy.mp >= mp_cost


static func can_use_equip(enemy: FightObj, slot_index: int, equip_cfg: Dictionary) -> bool:
	if enemy == null or slot_index < 0:
		return false
	var slot := enemy.get_equip_slot_at(slot_index)
	if slot.is_empty():
		return false
	var equip_id := int(slot.get("id", -1))
	if equip_id < 0:
		return false
	if float(slot.get("cd", 0.0)) > 0.0:
		return false
	var base_cfg := FightObj._lookup_cfg(equip_cfg, equip_id)
	var mp_cost := float(slot.get("mp_cost", base_cfg.get("mp_cost", 0.0)))
	return mp_cost <= 0.0 or enemy.mp >= mp_cost


static func resolve_action(
		ctx: EnemyAiContext,
		action: Dictionary,
		phase_id: String = "",
		reason_prefix: String = ""
) -> Dictionary:
	if ctx == null or ctx.self_unit == null:
		return EnemyAiTypesScript.fail(EnemyAiTypesScript.REASON_INVALID_AI_CONFIG, phase_id)
	var action_type := str(action.get("type", "")).strip_edges().to_lower()
	var reason := reason_prefix
	if reason == "":
		reason = "action:%s" % action_type
	match action_type:
		"skill":
			var sid := int(action.get("skill_id", -1))
			if not can_use_skill(ctx.self_unit, sid, ctx.skill_cfg):
				return EnemyAiTypesScript.fail(EnemyAiTypesScript.REASON_NO_SKILL_USABLE, phase_id)
			var slot_index := find_skill_slot(ctx.self_unit, sid)
			return EnemyAiTypesScript.ok_skill(sid, slot_index, reason, phase_id)
		"basic":
			var basic_slot := find_basic_slot(ctx.self_unit)
			if basic_slot < 0:
				return EnemyAiTypesScript.fail(EnemyAiTypesScript.REASON_NO_BASIC_SLOT, phase_id)
			return EnemyAiTypesScript.ok_basic(basic_slot, reason, phase_id)
		"item":
			var item_slot := int(action.get("slot_index", -1))
			if not can_use_item(ctx.self_unit, item_slot, ctx.item_cfg):
				return EnemyAiTypesScript.fail(EnemyAiTypesScript.REASON_NO_SKILL_USABLE, phase_id)
			return EnemyAiTypesScript.ok_item(item_slot, reason, phase_id)
		"equip":
			var equip_slot := int(action.get("slot_index", -1))
			if not can_use_equip(ctx.self_unit, equip_slot, ctx.equip_cfg):
				return EnemyAiTypesScript.fail(EnemyAiTypesScript.REASON_NO_SKILL_USABLE, phase_id)
			return EnemyAiTypesScript.ok_equip(equip_slot, reason, phase_id)
		_:
			return EnemyAiTypesScript.fail(EnemyAiTypesScript.REASON_INVALID_AI_CONFIG, phase_id)


static func _is_skill_usable_at_slot(
		enemy: FightObj,
		slot_index: int,
		skill_id: int,
		skill_cfg: Dictionary
) -> bool:
	var slot := enemy.get_skill_slot_at(slot_index)
	if slot.is_empty():
		return false
	if enemy.get_skill_cd_at(slot_index) > 0.0:
		return false
	var cfg := FightObj._lookup_cfg(skill_cfg, skill_id)
	if cfg.is_empty():
		return false
	return enemy.mp >= float(cfg.get("mp_cost", 0.0))
