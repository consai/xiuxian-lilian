class_name ExpeditionDataValidator
extends RefCounted

const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")
const ExpeditionEventServiceScript := preload("res://scripts/expedition/expedition_event_service.gd")
const ExpeditionRulesServiceScript := preload("res://scripts/expedition/expedition_rules_service.gd")


static func collect_errors(game_state: Node = null) -> PackedStringArray:
	var errors: PackedStringArray = []
	for location_v in LocationServiceScript.all_locations():
		var location := location_v as Dictionary
		var location_id := str(location.get("id", ""))
		var min_difficulty := maxi(1, int(location.get("min_difficulty", 1)))
		var max_difficulty := int(location.get("max_difficulty", 0))
		if max_difficulty > 0 and max_difficulty < min_difficulty:
			errors.append("地点 %s 的 max_difficulty 小于 min_difficulty" % location_id)
		var common_ids := location.get("common_event_pool", []) as Array
		var map_ids := location.get("map_event_pool", location.get("event_pool", [])) as Array
		for template_id_v in common_ids:
			var template_id := str(template_id_v)
			var common_event := ExpeditionEventServiceScript.event_pool_for_location(location).filter(
				func(event_v: Variant) -> bool:
					return str((event_v as Dictionary).get("template_id", "")) == template_id
			)
			if common_event.is_empty():
				errors.append("地点 %s 引用了不存在或无法生成的公共事件 %s" % [location_id, template_id])
		for event_id_v in map_ids:
			var event_id := str(event_id_v)
			var event := ExpeditionEventServiceScript.by_id(event_id)
			if event.is_empty():
				errors.append("地点 %s 引用了不存在的事件 %s" % [location_id, event_id])
				continue
			if str(event.get("location_id", "")) != location_id:
				errors.append("事件 %s 的 location_id 与地点 %s 不一致" % [event_id, location_id])
			var event_difficulty := maxi(1, int(event.get("difficulty", 0)))
			if int(event.get("difficulty", 0)) < 1:
				errors.append("事件 %s 缺少有效 difficulty" % event_id)
			elif max_difficulty > 0 and event_difficulty > max_difficulty:
				errors.append("事件 %s 难度 %d 超出地点 %s 上限 %d" % [event_id, event_difficulty, location_id, max_difficulty])
			elif event_difficulty < min_difficulty:
				errors.append("事件 %s 难度 %d 低于地点 %s 下限 %d" % [event_id, event_difficulty, location_id, min_difficulty])
			if ExpeditionEventServiceScript.is_decision_event(event):
				errors.append_array(_validate_decision_event(event, event_id))
			elif ExpeditionRulesServiceScript.is_battle_type(str(event.get("type", ""))):
				var init := _build_sample_battle_init(event, game_state)
				for msg in BattleInitData.collect_errors(init):
					errors.append("事件 %s: %s" % [event_id, msg])
			for reward_v in event.get("rewards", []) as Array:
				if not reward_v is Dictionary:
					continue
				errors.append_array(_validate_reward(reward_v as Dictionary, "事件 %s" % event_id))
		for generated_v in ExpeditionEventServiceScript.event_pool_for_location(location):
			var generated := generated_v as Dictionary
			if str(generated.get("scope", "")) != "common":
				continue
			errors.append_array(_validate_generated_common_event(generated, location_id, game_state))
	return errors


static func _validate_generated_common_event(event: Dictionary, location_id: String, game_state: Node) -> PackedStringArray:
	var errors: PackedStringArray = []
	var event_id := str(event.get("id", ""))
	if int(event.get("duration_days", 0)) < 1:
		errors.append("地点 %s 的公共事件 %s 缺少有效 duration_days" % [location_id, event_id])
	if str(event.get("reward_pool", "")).strip_edges() != "" and (event.get("rewards", []) as Array).is_empty():
		errors.append("地点 %s 的公共事件 %s 未生成奖励池" % [location_id, event_id])
	if str(event.get("enemy_pool", "")).strip_edges() != "" and (event.get("enemy", {}) as Dictionary).is_empty():
		errors.append("地点 %s 的公共事件 %s 未生成敌人池" % [location_id, event_id])
	if ExpeditionRulesServiceScript.is_battle_type(str(event.get("type", ""))):
		for msg in BattleInitData.collect_errors(_build_sample_battle_init(event, game_state)):
			errors.append("公共事件 %s: %s" % [event_id, msg])
	for reward_v in event.get("rewards", []) as Array:
		if reward_v is Dictionary:
			errors.append_array(_validate_reward(reward_v as Dictionary, "公共事件 %s" % event_id))
	return errors


static func _build_sample_battle_init(event: Dictionary, game_state: Node) -> Dictionary:
	var runtime := {
		"hp": 100.0,
		"mp": 100.0,
		"item_slots": ["", ""],
		"inventory": {},
	}
	var player: Dictionary = {}
	if game_state != null and game_state.has_method("build_player_battle_snapshot"):
		var built: Dictionary = game_state.build_player_battle_snapshot(runtime)
		if PlayerBattleSnapshot.collect_errors(built).is_empty():
			player = built
	if player.is_empty():
		player = {
			"hp": 100.0,
			"mp": 100.0,
			"attrs": FightAttr.from_stat_block({
				FightAttr.HP_MAX: 100.0,
				FightAttr.MP_MAX: 100.0,
				FightAttr.ATK: 100.0,
				FightAttr.DEF: 100.0,
				FightAttr.SPD: 100.0,
			}),
			"skills": [{"id": 0, "cd": 0.0}, {"id": -1, "cd": 0.0}, {"id": -1, "cd": 0.0}, {"id": -1, "cd": 0.0}, {"id": -1, "cd": 0.0}],
			"items": [],
			"equips": [{"id": -1, "cd": 0.0}, {"id": -1, "cd": 0.0}],
		}
	return {
		"player": player,
		"enemy": ExpeditionEventServiceScript.build_battle_enemy(event),
		"battle_time_limit": 200.0,
	}


static func _validate_reward(reward: Dictionary, label: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	var kind := str(reward.get("kind", "item"))
	if kind == "equip":
		var eid := int(reward.get("id", -1))
		var cm := _config_manager()
		if cm != null and cm.has_method("equip_by_id") and (cm.call("equip_by_id", eid) as Dictionary).is_empty():
			errors.append("%s 引用了未知法宝 %d" % [label, eid])
	elif kind == "item":
		var iid := str(reward.get("id", ""))
		var cm := _config_manager()
		if cm != null and cm.has_method("item_def_by_id") and cm.call("item_def_by_id", iid) == null:
			errors.append("%s 引用了未知物品 %s" % [label, iid])
	elif kind == "currency":
		var currency_id := str(reward.get("id", "ling_stones"))
		if currency_id != "ling_stones":
			errors.append("%s 引用了未知货币 %s" % [label, currency_id])
	return errors


static func _validate_decision_event(event: Dictionary, event_id: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	var options_v: Variant = event.get("options", [])
	if not options_v is Array or (options_v as Array).is_empty():
		errors.append("抉择事件 %s 缺少 options" % event_id)
		return errors
	var option_ids := {}
	for option_v in options_v as Array:
		if not option_v is Dictionary:
			continue
		var option := option_v as Dictionary
		var oid := str(option.get("id", "")).strip_edges()
		if oid == "":
			errors.append("抉择事件 %s 含空 option id" % event_id)
			continue
		if option_ids.has(oid):
			errors.append("抉择事件 %s 的 option id 重复: %s" % [event_id, oid])
		option_ids[oid] = true
		var trigger_id := str(option.get("trigger_event", "")).strip_edges()
		if trigger_id != "" and ExpeditionEventServiceScript.by_id(trigger_id).is_empty():
			errors.append("抉择事件 %s 引用了未知 trigger_event %s" % [event_id, trigger_id])
		for reward_v in option.get("rewards", []) as Array:
			if reward_v is Dictionary:
				errors.append_array(_validate_reward(reward_v as Dictionary, "抉择事件 %s option %s" % [event_id, oid]))
	return errors


static func _config_manager() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")
