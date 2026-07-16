class_name DaoTreeService
extends RefCounted

const QueryScript := preload("res://scripts/features/dao/application/dao_tree_query_application.gd")


static func meets_realm_gate(skill_realm: String, player_major_realm: String) -> bool:
	return QueryScript.realm_order(player_major_realm) >= QueryScript.realm_order(skill_realm.strip_edges())


static func required_xp_for_level(skill_id: String, target_level: int) -> float:
	var skill := QueryScript.skill_by_id(skill_id)
	if skill.is_empty():
		return 1.0
	var training := QueryScript.training()
	var base: Dictionary = training.get("base", {}) as Dictionary
	var multipliers: Array = base.get("levelMultipliers", [1, 2, 4, 8, 16]) as Array
	var level_index := clampi(target_level - 1, 0, multipliers.size() - 1)
	var rank := maxf(1.0, float(skill.get("rank", 1)))
	var base_points := maxf(1.0, float(base.get("basePoints", 250)))
	return base_points * rank * float(multipliers[level_index])


static func training_speed(skill_id: String, foundations: Dictionary, aptitudes: Dictionary) -> float:
	var skill := QueryScript.skill_by_id(skill_id)
	if skill.is_empty():
		return 1.0
	var domain := QueryScript.domain_by_id(str(skill.get("domain", "")))
	if domain.is_empty():
		return 1.0
	var primary := _attr_value(str(domain.get("primary", "")), foundations, aptitudes)
	var secondary := _attr_value(str(domain.get("secondary", "")), foundations, aptitudes)
	return maxf(0.0, primary + secondary * 0.5)


static func prereqs_met(skill_id: String, knowledge_levels: Dictionary) -> bool:
	var skill := QueryScript.skill_by_id(skill_id)
	for req_v in skill.get("prereqs", []) as Array:
		if not req_v is Dictionary:
			continue
		var req := req_v as Dictionary
		var parent_id := str(req.get("id", ""))
		var need_level := int(req.get("level", 1))
		var have := float(knowledge_levels.get(parent_id, 0.0))
		if have < float(need_level):
			return false
	return true


static func node_display_state(
		skill_id: String,
		effective_level: float,
		growth_source: String,
		player_major_realm: String,
		knowledge_levels: Dictionary
) -> int:
	if effective_level >= 1.0:
		if growth_source != "" and effective_level < float(QueryScript.skill_by_id(skill_id).get("maxLevel", 5)):
			return EnumDaoNodeState.State.GROWING
		return EnumDaoNodeState.State.LEARNED
	var skill := QueryScript.skill_by_id(skill_id)
	if skill.is_empty():
		return EnumDaoNodeState.State.LOCKED
	if not meets_realm_gate(str(skill.get("realm", "")), player_major_realm):
		return EnumDaoNodeState.State.LOCKED
	if prereqs_met(skill_id, knowledge_levels):
		return EnumDaoNodeState.State.AVAILABLE
	return EnumDaoNodeState.State.LOCKED


static func _attr_value(attr_id: String, foundations: Dictionary, aptitudes: Dictionary) -> float:
	match attr_id:
		EnumPlayerAttr.BODY, EnumPlayerAttr.SENSE, EnumPlayerAttr.SPIRIT, EnumPlayerAttr.AGILITY:
			return float(foundations.get(attr_id, 0.0))
		EnumPlayerAttr.COMPREHENSION, EnumPlayerAttr.WILL, EnumPlayerAttr.FORTUNE:
			return float(aptitudes.get(attr_id, 0.0))
		_:
			return 0.0
