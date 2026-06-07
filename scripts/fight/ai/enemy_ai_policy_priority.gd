class_name EnemyAiPolicyPriority
extends RefCounted

const EnemyAiTypesScript = preload("res://scripts/fight/ai/enemy_ai_types.gd")
const EnemyAiActionPickerScript = preload("res://scripts/fight/ai/enemy_ai_action_picker.gd")


static func decide(ctx: EnemyAiContext, ai_cfg: Dictionary) -> Dictionary:
	if ctx == null or ctx.skill_cfg.is_empty():
		return EnemyAiTypesScript.fail(EnemyAiTypesScript.REASON_SKILL_CFG_MISSING)
	var phase_id := str(ai_cfg.get("id", ctx.active_phase_id))
	var enemy := ctx.self_unit
	var preferred_skills := _resolve_skill_priority(enemy, ai_cfg)
	for skill_id in preferred_skills:
		var sid := int(skill_id)
		if sid <= 0:
			continue
		if not EnemyAiActionPickerScript.can_use_skill(enemy, sid, ctx.skill_cfg):
			continue
		var slot_index := EnemyAiActionPickerScript.find_skill_slot(enemy, sid)
		return EnemyAiTypesScript.ok_skill(sid, slot_index, EnemyAiTypesScript.REASON_OK_SKILL, phase_id)
	var basic_slot := EnemyAiActionPickerScript.find_basic_slot(enemy)
	if basic_slot >= 0:
		return EnemyAiTypesScript.ok_basic(basic_slot, EnemyAiTypesScript.REASON_OK_BASIC, phase_id)
	if preferred_skills.is_empty():
		return EnemyAiTypesScript.fail(EnemyAiTypesScript.REASON_NO_SKILL_USABLE, phase_id)
	return EnemyAiTypesScript.fail(EnemyAiTypesScript.REASON_NO_BASIC_SLOT, phase_id)


static func _resolve_skill_priority(enemy: FightObj, ai_cfg: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var used := {}
	var pref_v: Variant = ai_cfg.get("skill_priority", [])
	if pref_v is Array:
		for v in pref_v as Array:
			if not (v is int or v is float):
				continue
			var sid := int(v)
			if sid <= 0 or used.has(sid):
				continue
			used[sid] = true
			out.append(sid)
	if not out.is_empty():
		return out
	if enemy == null or not enemy.skills is Array:
		return out
	for slot_v in enemy.skills as Array:
		if not slot_v is Dictionary:
			continue
		var sid := int((slot_v as Dictionary).get("id", -1))
		if sid <= 0 or used.has(sid):
			continue
		used[sid] = true
		out.append(sid)
	return out
