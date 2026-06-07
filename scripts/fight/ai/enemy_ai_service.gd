class_name EnemyAiService
extends RefCounted

const EnemyAiTypesScript = preload("res://scripts/fight/ai/enemy_ai_types.gd")
const EnemyAiContextScript = preload("res://scripts/fight/ai/enemy_ai_context.gd")
const EnemyAiPhaseResolverScript = preload("res://scripts/fight/ai/enemy_ai_phase_resolver.gd")
const EnemyAiPolicyPriorityScript = preload("res://scripts/fight/ai/enemy_ai_policy_priority.gd")
const EnemyAiPolicyRuleListScript = preload("res://scripts/fight/ai/enemy_ai_policy_rule_list.gd")


static func decide_enemy_action(
		enemy: FightObj,
		player: FightObj,
		skill_cfg: Dictionary,
		ai_cfg: Dictionary = {},
		runtime: EnemyAiRuntimeState = null,
		domain_ctx: Dictionary = {},
		item_cfg: Dictionary = {},
		equip_cfg: Dictionary = {}
) -> Dictionary:
	if enemy == null or player == null:
		return EnemyAiTypesScript.fail(EnemyAiTypesScript.REASON_INVALID_AI_CONFIG)
	var cfg := ai_cfg.duplicate(true) if ai_cfg is Dictionary else {}
	var ctx := EnemyAiContextScript.from_units(
		enemy,
		player,
		skill_cfg,
		item_cfg,
		equip_cfg,
		domain_ctx
	)
	var phases := EnemyAiPhaseResolverScript.extract_phases(cfg)
	var policy_cfg := cfg
	if not phases.is_empty():
		var phase_cfg := EnemyAiPhaseResolverScript.resolve_active_phase(phases, ctx, runtime)
		if phase_cfg.is_empty():
			return EnemyAiTypesScript.fail(EnemyAiTypesScript.REASON_INVALID_AI_CONFIG)
		policy_cfg = EnemyAiPhaseResolverScript.normalize_policy_cfg(cfg, phase_cfg)
	var policy := str(policy_cfg.get("policy", cfg.get("policy", "priority"))).strip_edges().to_lower()
	if policy == "":
		policy = "priority"
	var result: Dictionary
	match policy:
		"priority":
			result = EnemyAiPolicyPriorityScript.decide(ctx, policy_cfg)
		"rule_list":
			result = EnemyAiPolicyRuleListScript.decide(ctx, policy_cfg)
		_:
			result = EnemyAiTypesScript.fail(EnemyAiTypesScript.REASON_INVALID_AI_CONFIG)
	BattleDebugLog.write("AI", "敌方决策", {
		"policy": policy,
		"phase_id": str(result.get("phase_id", ctx.active_phase_id)),
		"ok": bool(result.get("ok", false)),
		"action": str(result.get("action_type", "")),
		"skill_id": int(result.get("skill_id", -1)),
		"slot_index": int(result.get("slot_index", -1)),
		"reason": str(result.get("reason", "")),
		"enemy_mp": enemy.mp,
		"enemy_hp": enemy.hp,
		"player_hp": player.hp,
	})
	return result
