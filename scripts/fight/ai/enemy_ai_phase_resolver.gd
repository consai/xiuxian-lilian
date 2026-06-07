class_name EnemyAiPhaseResolver
extends RefCounted

const EnemyAiConditionScript = preload("res://scripts/fight/ai/enemy_ai_condition.gd")


static func resolve_active_phase(
		phases: Array,
		ctx: EnemyAiContext,
		runtime: EnemyAiRuntimeState
) -> Dictionary:
	if phases.is_empty():
		return {}
	var active := {}
	var active_id := ""
	for phase_v in phases:
		if not phase_v is Dictionary:
			continue
		var phase := phase_v as Dictionary
		var phase_id := str(phase.get("id", "")).strip_edges()
		if phase_id == "":
			continue
		var once := bool(phase.get("once", false))
		var sticky := once and runtime != null and runtime.entered_phases.has(phase_id)
		var enter_when: Variant = phase.get("enter_when", {})
		if not sticky and not EnemyAiConditionScript.evaluate(enter_when, ctx):
			continue
		active = phase.duplicate(true)
		active_id = phase_id
	if active.is_empty():
		return {}
	if runtime != null and bool(active.get("once", false)):
		runtime.entered_phases[active_id] = true
	if runtime != null:
		runtime.last_phase_id = active_id
	if ctx != null:
		ctx.active_phase_id = active_id
	return active


static func extract_phases(ai_cfg: Dictionary) -> Array:
	if ai_cfg.is_empty():
		return []
	var phases_v: Variant = ai_cfg.get("phases", [])
	if phases_v is Array and not (phases_v as Array).is_empty():
		return phases_v as Array
	return []


static func normalize_policy_cfg(ai_cfg: Dictionary, phase_cfg: Dictionary) -> Dictionary:
	if not phase_cfg.is_empty():
		return phase_cfg.duplicate(true)
	return ai_cfg.duplicate(true)
