class_name ConfigValidator
extends RefCounted

const ExpeditionDataValidatorScript := preload("res://scripts/expedition/expedition_data_validator.gd")
const WorldMapDataValidatorScript := preload("res://scripts/map/world_map_data_validator.gd")
const SceneManagerScript := preload("res://scripts/core/scene_manager.gd")
const AbilityServiceScript := preload("res://scripts/dao/ability_service.gd")
const CultivationMethodServiceScript := preload("res://scripts/sim/cultivation_method_service.gd")
const EffectResolverScript := preload("res://scripts/dao/effect_resolver.gd")
const RealmBalanceServiceScript := preload("res://scripts/sim/realm_balance_service.gd")


static func collect_all_errors(config_manager: Node, game_state: Node = null) -> PackedStringArray:
	var errors: PackedStringArray = []
	if config_manager == null:
		errors.append("ConfigManager 不可用")
		return errors
	errors.append_array(_validate_unique_ids(config_manager))
	errors.append_array(_validate_scene_paths())
	errors.append_array(_validate_expedition_rules(config_manager))
	errors.append_array(_validate_realm_balance())
	errors.append_array(_validate_location_preview_rewards(config_manager))
	errors.append_array(_validate_v1_abilities())
	errors.append_array(_validate_method_stack_policies())
	errors.append_array(ExpeditionDataValidatorScript.collect_errors(game_state))
	errors.append_array(WorldMapDataValidatorScript.collect_errors())
	return errors


static func _validate_realm_balance() -> PackedStringArray:
	var simulation := JsonLoader._read_json_root_object("res://data/simulation.json")
	var realms_v: Variant = simulation.get("realms", [])
	var realms := realms_v as Array if realms_v is Array else []
	return RealmBalanceServiceScript.collect_config_errors(realms)


static func _validate_v1_abilities() -> PackedStringArray:
	var errors: PackedStringArray = []
	for ability_v in AbilityServiceScript.all_abilities():
		var ability := ability_v as Dictionary
		if not ability.get("tags") is Array:
			errors.append("技能 %s tags 必须是数组" % str(ability.get("id", "")))
		if not ability.get("trigger") is Dictionary:
			errors.append("技能 %s trigger 必须是对象" % str(ability.get("id", "")))
		if not ability.get("upgrade_options") is Array:
			errors.append("技能 %s upgrade_options 必须是数组" % str(ability.get("id", "")))
		if not ability.get("evolution_conditions") is Array:
			errors.append("技能 %s evolution_conditions 必须是数组" % str(ability.get("id", "")))
		for effect_v in ability.get("effects", []) as Array:
			var effect := effect_v as Dictionary
			if effect.has("masteryGrowth"):
				errors.append("技能 %s 的效果 %s 使用了禁用字段 masteryGrowth" % [
					ability.get("id", ""), effect.get("effectId", ""),
				])
		if str(ability.get("type", "")) != "combat_active":
			continue
		var combat := ability.get("combat", {}) as Dictionary
		if not combat.has("powerScale") or float(combat.get("powerScale", -1.0)) < 0.0:
			errors.append("技能 %s 缺少有效 powerScale" % str(ability.get("id", "")))
		errors.append_array(_validate_combat_costs(ability, combat))
		for effect_v in ability.get("effects", []) as Array:
			var effect := effect_v as Dictionary
			var effect_id := str(effect.get("effectId", ""))
			if not EffectResolverScript.has_combat_mapping(effect_id):
				errors.append("技能 %s 的效果 %s 未映射到战斗运行时" % [ability.get("id", ""), effect_id])
			if str(effect.get("operation", "")) == "add_percent" \
					and (not effect.has("clampMin") or not effect.has("clampMax")):
				errors.append("技能 %s 的百分比效果 %s 缺少上下限" % [ability.get("id", ""), effect_id])
	return errors


static func _validate_combat_costs(ability: Dictionary, combat: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	var ability_id := str(ability.get("id", ""))
	var costs_v: Variant = combat.get("costs", [])
	if not costs_v is Array:
		errors.append("技能 %s combat.costs 必须是数组" % ability_id)
		return errors
	var allowed := {"mana": true, "stamina": true, "spirit": true}
	for cost_v in costs_v as Array:
		if not cost_v is Dictionary:
			errors.append("技能 %s combat.costs 包含非对象项" % ability_id)
			continue
		var cost := cost_v as Dictionary
		var resource := str(cost.get("resource", "")).strip_edges().to_lower()
		if not allowed.has(resource):
			errors.append("技能 %s 使用未知战斗资源 %s" % [ability_id, resource])
		if float(cost.get("value", -1.0)) < 0.0:
			errors.append("技能 %s 的资源消耗不能为负" % ability_id)
	return errors


static func _validate_method_stack_policies() -> PackedStringArray:
	var errors: PackedStringArray = []
	for method_v in CultivationMethodServiceScript.all_methods():
		var method := method_v as Dictionary
		if not method.get("tags") is Array:
			errors.append("功法 %s tags 必须是数组" % str(method.get("id", "")))
		if not method.get("passive_rules") is Array:
			errors.append("功法 %s passive_rules 必须是数组" % str(method.get("id", "")))
		if not method.get("synergy_rules") is Array:
			errors.append("功法 %s synergy_rules 必须是数组" % str(method.get("id", "")))
		for effect_v in method.get("effects", []) as Array:
			var effect := effect_v as Dictionary
			if str(effect.get("stackPolicy", "")) == "add_capped" and not effect.has("cap"):
				errors.append("功法 %s 的效果 %s 使用 add_capped 但缺少 cap" % [
					method.get("id", ""), effect.get("effectId", ""),
				])
	return errors


static func _validate_unique_ids(config_manager: Node) -> PackedStringArray:
	var errors: PackedStringArray = []
	errors.append_array(_validate_no_duplicate_keys(config_manager.items(), "item.id", "物品"))
	errors.append_array(_validate_no_duplicate_dict_keys(config_manager.all_skill_ids(), "技能"))
	errors.append_array(_validate_no_duplicate_dict_keys(config_manager.all_equip_ids(), "法宝"))
	errors.append_array(_validate_no_duplicate_dict_keys(config_manager.all_buff_ids(), "Buff"))
	errors.append_array(_validate_no_duplicate_dict_keys(config_manager.all_location_ids(), "地点"))
	errors.append_array(_validate_no_duplicate_dict_keys(config_manager.all_common_expedition_event_ids(), "公共历练事件"))
	errors.append_array(_validate_no_duplicate_dict_keys(config_manager.all_expedition_event_ids(), "远征事件"))
	return errors


static func _validate_no_duplicate_keys(items: Array, field: String, label: String) -> PackedStringArray:
	var seen := {}
	var errors: PackedStringArray = []
	for item_v in items:
		if not item_v is ItemDef:
			continue
		var item := item_v as ItemDef
		var key := str(item.id)
		if seen.has(key):
			errors.append("%s ID 重复: %s" % [label, key])
		else:
			seen[key] = true
	return errors


static func _validate_no_duplicate_dict_keys(ids: Array, label: String) -> PackedStringArray:
	var seen := {}
	var errors: PackedStringArray = []
	for id_v in ids:
		var key := str(id_v)
		if seen.has(key):
			errors.append("%s ID 重复: %s" % [label, key])
		else:
			seen[key] = true
	return errors


static func _validate_scene_paths() -> PackedStringArray:
	var errors: PackedStringArray = []
	for scene_id in SceneManagerScript.SCENE_PATHS.keys():
		var path := str(SceneManagerScript.SCENE_PATHS[scene_id])
		if not ResourceLoader.exists(path):
			errors.append("场景路径不存在: %s -> %s" % [scene_id, path])
	return errors


static func _validate_expedition_rules(config_manager: Node) -> PackedStringArray:
	var errors: PackedStringArray = []
	var rules: Dictionary = config_manager.expedition_rules()
	if rules.is_empty():
		errors.append("远征规则为空")
		return errors
	var required := [
		"minimum_elapsed_days", "event_day_chance", "max_idle_days", "choice_count",
		"defeat_hp_floor_ratio", "defeat_injury_days",
	]
	for key in required:
		if not rules.has(key):
			errors.append("远征规则缺少字段: %s" % key)
	var event_chance := float(rules.get("event_day_chance", -1.0))
	if event_chance < 0.0 or event_chance > 1.0:
		errors.append("event_day_chance 必须在 0~1 之间")
	if int(rules.get("max_idle_days", 0)) < 1:
		errors.append("max_idle_days 必须 >= 1")
	if int(rules.get("choice_count", 0)) < 1:
		errors.append("choice_count 必须 >= 1")
	var floor_ratio := float(rules.get("defeat_hp_floor_ratio", -1.0))
	if floor_ratio < 0.0 or floor_ratio > 1.0:
		errors.append("defeat_hp_floor_ratio 必须在 0~1 之间")
	return errors


static func _validate_location_preview_rewards(config_manager: Node) -> PackedStringArray:
	var errors: PackedStringArray = []
	for location_v in config_manager.all_locations():
		var location := location_v as Dictionary
		var location_id := str(location.get("id", ""))
		for reward_v in location.get("preview_rewards", []) as Array:
			if reward_v is String:
				var iid := str(reward_v)
				if config_manager.item_def_by_id(iid) == null:
					errors.append("地点 %s preview_rewards 引用了未知物品 %s" % [location_id, iid])
			elif reward_v is int or (reward_v is float and int(reward_v) == reward_v):
				var eid := int(reward_v)
				if config_manager.equip_by_id(eid).is_empty():
					errors.append("地点 %s preview_rewards 引用了未知法宝 %d" % [location_id, eid])
	return errors
