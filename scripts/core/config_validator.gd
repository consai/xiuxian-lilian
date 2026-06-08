class_name ConfigValidator
extends RefCounted

const ExpeditionDataValidatorScript := preload("res://scripts/expedition/expedition_data_validator.gd")
const SceneManagerScript := preload("res://scripts/core/scene_manager.gd")


static func collect_all_errors(config_manager: Node, game_state: Node = null) -> PackedStringArray:
	var errors: PackedStringArray = []
	if config_manager == null:
		errors.append("ConfigManager 不可用")
		return errors
	errors.append_array(_validate_unique_ids(config_manager))
	errors.append_array(_validate_scene_paths())
	errors.append_array(_validate_expedition_rules(config_manager))
	errors.append_array(_validate_location_preview_rewards(config_manager))
	errors.append_array(ExpeditionDataValidatorScript.collect_errors(game_state))
	return errors


static func _validate_unique_ids(config_manager: Node) -> PackedStringArray:
	var errors: PackedStringArray = []
	errors.append_array(_validate_no_duplicate_keys(config_manager.items(), "item.id", "物品"))
	errors.append_array(_validate_no_duplicate_dict_keys(config_manager.all_skill_ids(), "技能"))
	errors.append_array(_validate_no_duplicate_dict_keys(config_manager.all_equip_ids(), "法宝"))
	errors.append_array(_validate_no_duplicate_dict_keys(config_manager.all_buff_ids(), "Buff"))
	errors.append_array(_validate_no_duplicate_dict_keys(config_manager.all_location_ids(), "地点"))
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
		"steps_per_day", "minimum_elapsed_days", "choice_count",
		"max_battle_choices", "defeat_hp_floor_ratio", "defeat_injury_days",
	]
	for key in required:
		if not rules.has(key):
			errors.append("远征规则缺少字段: %s" % key)
	if int(rules.get("steps_per_day", 0)) < 1:
		errors.append("steps_per_day 必须 >= 1")
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
