class_name EnemyAiPolicyRuleList
extends RefCounted

const EnemyAiTypesScript = preload("res://scripts/zhandou/ai/enemy_ai_types.gd")
const EnemyAiConditionScript = preload("res://scripts/zhandou/ai/enemy_ai_condition.gd")
const EnemyAiActionPickerScript = preload("res://scripts/zhandou/ai/enemy_ai_action_picker.gd")


static func decide(ctx: EnemyAiContext, ai_cfg: Dictionary) -> Dictionary:
	if ctx == null or ctx.skill_cfg.is_empty():
		return EnemyAiTypesScript.fail(EnemyAiTypesScript.REASON_SKILL_CFG_MISSING)
	var phase_id := str(ai_cfg.get("id", ctx.active_phase_id))
	var rules_v: Variant = ai_cfg.get("rules", [])
	if not rules_v is Array:
		return EnemyAiTypesScript.fail(EnemyAiTypesScript.REASON_INVALID_AI_CONFIG, phase_id)
	for rule_v in rules_v as Array:
		if not rule_v is Dictionary:
			continue
		var rule := rule_v as Dictionary
		var when_v: Variant = rule.get("when", null)
		if not EnemyAiConditionScript.evaluate(when_v, ctx):
			continue
		var action_v: Variant = rule.get("action", null)
		if not action_v is Dictionary:
			continue
		var picked := EnemyAiActionPickerScript.resolve_action(
			ctx,
			action_v as Dictionary,
			phase_id,
			"rule_matched:%s" % str(rule.get("id", ""))
		)
		if bool(picked.get("ok", false)):
			return picked
	if EnemyAiActionPickerScript.can_use_basic(ctx.self_unit):
		var basic_slot := EnemyAiActionPickerScript.find_basic_slot(ctx.self_unit)
		return EnemyAiTypesScript.ok_basic(basic_slot, "rule_fallback_basic", phase_id)
	return EnemyAiTypesScript.fail(EnemyAiTypesScript.REASON_NO_RULE_MATCHED, phase_id)
