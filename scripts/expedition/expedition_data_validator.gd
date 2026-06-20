class_name ExpeditionDataValidator
extends RefCounted

const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")
const ExpeditionEventServiceScript := preload("res://scripts/expedition/expedition_event_service.gd")
const ExpeditionRulesServiceScript := preload("res://scripts/expedition/expedition_rules_service.gd")
const EnumExpeditionNodeTypeScript := preload("res://scripts/enum/enum_expedition_node_type.gd")


static func collect_errors(game_state: Node = null) -> PackedStringArray:
	var errors: PackedStringArray = []
	for location_v in LocationServiceScript.all_locations():
		var location := location_v as Dictionary
		var location_id := str(location.get("id", ""))
		errors.append_array(_validate_location(location, location_id))
		for event_id_v in location.get("event_pool", []) as Array:
			var event_id := str(event_id_v)
			var event := ExpeditionEventServiceScript.by_id(event_id)
			if event.is_empty():
				errors.append("地点 %s 引用了不存在的事件 %s" % [location_id, event_id])
				continue
			errors.append_array(_validate_event(event, location, location_id, game_state))
	return errors


static func _validate_location(location: Dictionary, location_id: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	for old_key in ["common_event_pool", "map_event_pool", "common_event_generation", "expedition_mode", "enemy_pools"]:
		if location.has(old_key):
			errors.append("地点 %s 使用了旧字段 %s" % [location_id, old_key])
	if str(location.get("recommended_realm", "")).strip_edges() == "":
		errors.append("地点 %s 缺少 recommended_realm" % location_id)
	if not location.get("tags") is Array:
		errors.append("地点 %s tags 必须是数组" % location_id)
	if not location.get("event_pool") is Array or (location.get("event_pool", []) as Array).is_empty():
		errors.append("地点 %s 必须配置 event_pool" % location_id)
	else:
		errors.append_array(_validate_location_node_support(location, location_id))
	if not location.get("drop_pools") is Dictionary:
		errors.append("地点 %s drop_pools 必须是对象" % location_id)
	if not location.get("monsters") is Array:
		errors.append("地点 %s monsters 必须是怪物 id 数组" % location_id)
	else:
		errors.append_array(_validate_location_monsters(location, location_id))
	if location.has("materials"):
		if not location.get("materials") is Array:
			errors.append("地点 %s materials 必须是数组" % location_id)
		else:
			errors.append_array(_validate_location_materials(location, location_id))
	var min_difficulty := maxi(1, int(location.get("min_difficulty", 1)))
	var max_difficulty := int(location.get("max_difficulty", 0))
	if max_difficulty > 0 and max_difficulty < min_difficulty:
		errors.append("地点 %s 的 max_difficulty 小于 min_difficulty" % location_id)
	for pool_id in (location.get("drop_pools", {}) as Dictionary).keys():
		var pool := (location.get("drop_pools", {}) as Dictionary).get(pool_id, {}) as Dictionary
		if not pool.get("entries") is Array:
			errors.append("地点 %s 掉落池 %s 缺少 entries" % [location_id, pool_id])
		for reward_v in pool.get("entries", []) as Array:
			if reward_v is Dictionary:
				errors.append_array(_validate_reward(reward_v as Dictionary, "地点 %s 掉落池 %s" % [location_id, pool_id]))
				for variant_v in (reward_v as Dictionary).get("variants", []) as Array:
					if variant_v is Dictionary:
						errors.append_array(_validate_reward(variant_v as Dictionary, "地点 %s 掉落池 %s 变体" % [location_id, pool_id]))
	return errors


static func _validate_location_node_support(location: Dictionary, location_id: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	var supported_types := {}
	for event_id_v in location.get("event_pool", []) as Array:
		var event := ExpeditionEventServiceScript.by_id(str(event_id_v))
		if event.is_empty():
			continue
		var event_type := str(event.get("type", "")).strip_edges()
		if ExpeditionEventServiceScript.is_decision_event(event):
			supported_types[EnumExpeditionNodeTypeScript.ID_DECISION] = true
			continue
		if event_type not in ["travel", "gather", "recover", "hazard", "battle", "elite", "boss"]:
			errors.append("地点 %s 事件 %s 无法映射到路线节点类型" % [location_id, str(event.get("id", ""))])
			continue
		supported_types[EnumExpeditionNodeTypeScript.from_event(event)] = true
	if supported_types.is_empty():
		errors.append("地点 %s 缺少可用于路线节点的事件" % location_id)
	return errors


static func _validate_location_monsters(location: Dictionary, location_id: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	var ids := {}
	for monster_id_v in location.get("monsters", []) as Array:
		var monster_id := str(monster_id_v).strip_edges()
		if monster_id == "":
			errors.append("地点 %s monsters 含空怪物 id" % location_id)
			continue
		if ids.has(monster_id):
			errors.append("地点 %s monsters id 重复: %s" % [location_id, monster_id])
		ids[monster_id] = true
		var monster := _monster_by_id(monster_id)
		if monster.is_empty():
			errors.append("地点 %s 引用了未知怪物 %s" % [location_id, monster_id])
		else:
			errors.append_array(_validate_monster(monster, monster_id))
	return errors


static func _validate_location_materials(location: Dictionary, location_id: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	var drop_pools := location.get("drop_pools", {}) as Dictionary
	var ids := {}
	for row_v in location.get("materials", []) as Array:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		var material_id := str(row.get("id", "")).strip_edges()
		var drop_pool := str(row.get("drop_pool", "")).strip_edges()
		if material_id == "":
			errors.append("地点 %s materials 含空 id" % location_id)
		elif ids.has(material_id):
			errors.append("地点 %s materials id 重复: %s" % [location_id, material_id])
		ids[material_id] = true
		if drop_pool == "" or not drop_pools.has(drop_pool):
			errors.append("地点 %s 材料 %s 引用了未知 drop_pool %s" % [location_id, material_id, drop_pool])
		for item_id_v in row.get("item_ids", []) as Array:
			var cm := _config_manager()
			var item_id := str(item_id_v)
			if cm != null and cm.has_method("item_def_by_id") and cm.call("item_def_by_id", item_id) == null:
				errors.append("地点 %s 材料 %s 引用了未知物品 %s" % [location_id, material_id, item_id])
	return errors


static func _validate_monster(monster: Dictionary, monster_id: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	if str(monster.get("name", "")).strip_edges() == "":
		errors.append("怪物 %s 缺少 name" % monster_id)
	if str(monster.get("species", "")).strip_edges() == "":
		errors.append("怪物 %s 缺少 species" % monster_id)
	var drops := monster.get("drops", {}) as Dictionary
	if drops.is_empty() or not drops.get("entries") is Array:
		errors.append("怪物 %s 缺少 drops.entries" % monster_id)
	for reward_v in drops.get("entries", []) as Array:
		if reward_v is Dictionary:
			errors.append_array(_validate_reward(reward_v as Dictionary, "怪物 %s 掉落" % monster_id))
	var attrs := (ExpeditionEventServiceScript.build_battle_enemy({"enemy": monster}).get("attrs", {}) as Dictionary)
	for key in [
		FightAttr.PHYSICAL_ATK, FightAttr.MAGIC_ATK,
		FightAttr.PHYSICAL_DEF, FightAttr.MAGIC_DEF,
		FightAttr.ACCURACY, FightAttr.EVASION,
		FightAttr.CONTROL_POWER, FightAttr.CONTROL_RESIST,
	]:
		if not attrs.has(key):
			errors.append("怪物 %s 缺少首版属性 %s" % [monster_id, key])
	return errors


static func _validate_event(
		event: Dictionary,
		location: Dictionary,
		location_id: String,
		game_state: Node
) -> PackedStringArray:
	var errors: PackedStringArray = []
	var event_id := str(event.get("id", ""))
	for old_key in ["difficulty", "reward_pool", "rewards", "reward_rolls", "scope"]:
		if event.has(old_key):
			errors.append("事件 %s 使用了旧字段 %s" % [event_id, old_key])
	if str(event.get("location_id", "")) != location_id:
		errors.append("事件 %s 的 location_id 与地点 %s 不一致" % [event_id, location_id])
	if not event.get("tags") is Array:
		errors.append("事件 %s tags 必须是数组" % event_id)
	if not event.get("conditions") is Array:
		errors.append("事件 %s conditions 必须是数组" % event_id)
	if not event.get("results") is Array:
		errors.append("事件 %s results 必须是数组" % event_id)
	if ExpeditionEventServiceScript.is_decision_event(event):
		errors.append_array(_validate_decision_event(event, event_id, location))
	if ExpeditionRulesServiceScript.is_battle_type(str(event.get("type", ""))):
		var sample_event := event.duplicate(true)
		sample_event["difficulty"] = maxi(1, int(location.get("min_difficulty", 1)))
		sample_event["enemy_pool"] = _sample_monster_ref(location, str(event.get("type", "")))
		sample_event["results"] = [{"type": "drop", "drop_pool": "monster:%s" % str(sample_event.get("enemy_pool", "")), "rolls": 1}]
		errors.append_array(_validate_v1_enemy_attrs(sample_event, event_id))
		for msg in BattleInitData.collect_errors(_build_sample_battle_init(sample_event, game_state)):
			errors.append("事件 %s: %s" % [event_id, msg])
	for result_v in event.get("results", []) as Array:
		if result_v is Dictionary:
			errors.append_array(_validate_result(result_v as Dictionary, "事件 %s" % event_id, location))
	return errors


static func _validate_result(result: Dictionary, label: String, location: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	match str(result.get("type", "")):
		"drop":
			var pool_id := str(result.get("drop_pool", "")).strip_edges()
			var known_pool := (location.get("drop_pools", {}) as Dictionary).has(pool_id)
			if pool_id.begins_with("monster:"):
				var monster_ref := pool_id.substr("monster:".length()).strip_edges()
				known_pool = not _location_enemy(str(location.get("id", "")), monster_ref).is_empty()
			if pool_id == "" or not known_pool:
				errors.append("%s 引用了未知 drop_pool %s" % [label, pool_id])
		"rewards":
			for reward_v in result.get("rewards", []) as Array:
				if reward_v is Dictionary:
					errors.append_array(_validate_reward(reward_v as Dictionary, label))
		"effects":
			if not result.get("effects") is Array:
				errors.append("%s effects 结果缺少 effects 数组" % label)
		_:
			errors.append("%s 使用未知结果类型 %s" % [label, str(result.get("type", ""))])
	return errors


static func _validate_v1_enemy_attrs(event: Dictionary, event_id: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	var enemy := ExpeditionEventServiceScript.build_battle_enemy(event)
	var attrs := enemy.get("attrs", {}) as Dictionary
	if enemy.is_empty() or attrs.is_empty():
		return errors
	for key in [
		FightAttr.PHYSICAL_ATK, FightAttr.MAGIC_ATK,
		FightAttr.PHYSICAL_DEF, FightAttr.MAGIC_DEF,
		FightAttr.ACCURACY, FightAttr.EVASION,
		FightAttr.CONTROL_POWER, FightAttr.CONTROL_RESIST,
	]:
		if not attrs.has(key):
			errors.append("事件 %s 的敌人缺少首版属性 %s" % [event_id, key])
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
				FightAttr.PHYSICAL_ATK: 100.0,
				FightAttr.MAGIC_ATK: 100.0,
				FightAttr.PHYSICAL_DEF: 100.0,
				FightAttr.MAGIC_DEF: 100.0,
				FightAttr.SPD: 100.0,
			}),
			"skills": [{"id": 0, "cd": 0.0}, {"id": -1, "cd": 0.0}, {"id": -1, "cd": 0.0}, {"id": -1, "cd": 0.0}, {"id": -1, "cd": 0.0}],
			"items": [],
			"equips": [{"id": -1, "cd": 0.0}, {"id": -1, "cd": 0.0}],
		}
	return {
		"player": player,
		"enemy": ExpeditionEventServiceScript.build_battle_enemy(event),
		"enemies": ExpeditionEventServiceScript.build_battle_enemies(event),
		"battle_time_limit": 200.0,
	}


static func _sample_monster_ref(location: Dictionary, event_type: String) -> String:
	var want_elite := event_type == "elite"
	var want_boss := event_type == "boss"
	for monster_id_v in location.get("monsters", []) as Array:
		var monster_id := str(monster_id_v).strip_edges()
		var monster := _monster_by_id(monster_id)
		var species := str(monster.get("species", "")).strip_edges()
		var tags := monster.get("tags", []) as Array
		if want_boss and (species == "boss" or tags.has("boss")):
			return monster_id
		if want_elite and (species == "elite" or tags.has("elite")):
			return monster_id
		if not want_elite and not want_boss and species not in ["elite", "boss"] and not tags.has("elite") and not tags.has("boss"):
			return monster_id
	for monster_id_v in location.get("monsters", []) as Array:
		var monster_id := str(monster_id_v).strip_edges()
		if monster_id != "":
			return monster_id
	return ""


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


static func _validate_decision_event(event: Dictionary, event_id: String, location: Dictionary) -> PackedStringArray:
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
		for result_v in option.get("results", []) as Array:
			if result_v is Dictionary:
				errors.append_array(_validate_result(result_v as Dictionary, "抉择事件 %s option %s" % [event_id, oid], location))
	return errors


static func _config_manager() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")


static func _monster_by_id(monster_id: String) -> Dictionary:
	var cm := _config_manager()
	if cm != null and cm.has_method("monster_by_id"):
		return cm.call("monster_by_id", monster_id) as Dictionary
	return {}


static func _location_enemy(location_id: String, monster_ref: String) -> Dictionary:
	var cm := _config_manager()
	if cm != null and cm.has_method("location_enemy_pool"):
		return cm.call("location_enemy_pool", location_id, monster_ref) as Dictionary
	return {}
