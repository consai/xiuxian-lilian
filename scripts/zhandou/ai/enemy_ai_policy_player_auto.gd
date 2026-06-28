class_name EnemyAiPolicyPlayerAuto
extends RefCounted

const EnemyAiTypesScript = preload("res://scripts/zhandou/ai/enemy_ai_types.gd")
const EnemyAiConditionScript = preload("res://scripts/zhandou/ai/enemy_ai_condition.gd")
const EnemyAiActionPickerScript = preload("res://scripts/zhandou/ai/enemy_ai_action_picker.gd")


static func decide(ctx: EnemyAiContext, ai_cfg: Dictionary) -> Dictionary:
	if ctx == null or ctx.skill_cfg.is_empty():
		return EnemyAiTypesScript.fail(EnemyAiTypesScript.REASON_SKILL_CFG_MISSING)
	var phase_id := str(ai_cfg.get("id", ctx.active_phase_id))
	var strategies := _extract_strategies(ai_cfg)
	for rule_v in strategies:
		if not rule_v is Dictionary:
			continue
		var rule := rule_v as Dictionary
		if not EnemyAiConditionScript.evaluate(rule.get("when", null), ctx):
			continue
		var action_v: Variant = rule.get("action", null)
		if not action_v is Dictionary:
			continue
		var picked := EnemyAiActionPickerScript.resolve_action(
			ctx,
			action_v as Dictionary,
			phase_id,
			"strategy:%s" % str(rule.get("id", ""))
		)
		if bool(picked.get("ok", false)):
			return picked
	var first_skill := EnemyAiActionPickerScript.find_first_usable_skill_by_slot(
		ctx.self_unit,
		ctx.skill_cfg
	)
	if not first_skill.is_empty():
		return EnemyAiTypesScript.ok_skill(
			int(first_skill.get("skill_id", -1)),
			int(first_skill.get("slot_index", -1)),
			"default_first_skill",
			phase_id
		)
	if EnemyAiActionPickerScript.can_use_basic(ctx.self_unit):
		var basic_slot := EnemyAiActionPickerScript.find_basic_slot(ctx.self_unit)
		return EnemyAiTypesScript.ok_basic(basic_slot, "fallback_basic", phase_id)
	return EnemyAiTypesScript.fail(EnemyAiTypesScript.REASON_NO_RULE_MATCHED, phase_id)


static func _extract_strategies(ai_cfg: Dictionary) -> Array:
	var strategies_v: Variant = ai_cfg.get("strategies", [])
	if strategies_v is Array and not (strategies_v as Array).is_empty():
		return strategies_v as Array
	var rules_v: Variant = ai_cfg.get("rules", [])
	return rules_v as Array if rules_v is Array else []
