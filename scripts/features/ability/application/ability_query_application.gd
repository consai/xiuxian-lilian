class_name AbilityQueryApplication
extends RefCounted

## 技能模块的只读查询入口；presentation 不直接依赖技能配置 service。

const AbilityServiceScript := preload("res://scripts/dao/ability_service.gd")


static func all_definitions() -> Array:
	return AbilityServiceScript.all_abilities()


static func runtime_by_combat_id(combat_id: int) -> Dictionary:
	var ability_id := AbilityServiceScript.ability_id_for_combat_id(combat_id)
	if ability_id == "":
		return {}
	return runtime_by_ability_id(ability_id, {})


static func definition_by_id(ability_id: String) -> Dictionary:
	return AbilityServiceScript.by_id(ability_id).duplicate(true)


static func combat_id_for(ability_id: String) -> int:
	return AbilityServiceScript.combat_id_for(ability_id)


static func runtime_by_ability_id(ability_id: String, savedata: Dictionary) -> Dictionary:
	var runtime := AbilityServiceScript.to_runtime_dict(ability_id, savedata)
	return runtime.duplicate(true)


static func tier_for(ability_id: String) -> int:
	var ability := AbilityServiceScript.by_id(ability_id)
	return AbilityServiceScript.ability_tier(ability) if not ability.is_empty() else 0


static func realm_id_for(ability_id: String) -> String:
	var ability := AbilityServiceScript.by_id(ability_id)
	return AbilityServiceScript.ability_realm_id(ability) if not ability.is_empty() else ""
