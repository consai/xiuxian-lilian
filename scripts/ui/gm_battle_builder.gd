class_name GmBattleBuilder
extends RefCounted

const LilianEventServiceScript := preload("res://scripts/lilian/lilian_event_service.gd")


static func build(
		monster_id: String,
		count: int,
		game_state: Node,
		config_manager: Node
) -> Dictionary:
	var mid := monster_id.strip_edges()
	if mid == "" or game_state == null or config_manager == null:
		return {}
	if not config_manager.has_method("monster_by_id"):
		return {}
	var monster := config_manager.call("monster_by_id", mid) as Dictionary
	if monster.is_empty():
		return {}
	var safe_count := clampi(count, 1, 8)
	var enemies: Array = []
	for i in safe_count:
		var enemy := monster.duplicate(true)
		if safe_count > 1:
			enemy["name"] = "%s·%d" % [str(monster.get("name", mid)), i + 1]
		enemies.append(enemy)
	var event := {
		"id": "gm_battle:%s" % mid,
		"type": _event_type_for_monster(monster),
		"name": "GM 战斗：%s" % str(monster.get("name", mid)),
		"enemies": enemies,
	}
	var battle_enemies := LilianEventServiceScript.build_battle_enemies(event)
	if battle_enemies.is_empty():
		return {}
	var runtime := {
		"hp": game_state.get("hp"),
		"mp": game_state.get("mp"),
		"inventory": game_state.get("inventory"),
		"item_slots": game_state.get("item_slots"),
	}
	var player := game_state.call("build_player_battle_snapshot", runtime) as Dictionary
	if not PlayerBattleSnapshot.collect_errors(player).is_empty():
		return {}
	return {
		"player": player,
		"enemy": battle_enemies[0],
		"enemies": battle_enemies,
		"enemy_formation": LilianEventServiceScript.build_enemy_formation(event, battle_enemies),
		"battle_time_limit": 200.0,
		"auto_battle": {"player": bool(game_state.get("auto_battle_enabled")), "enemy": true},
		"spd_jitter_ratio": 0.0,
	}


static func _event_type_for_monster(monster: Dictionary) -> String:
	var species := str(monster.get("species", "")).strip_edges()
	var tags := monster.get("tags", []) as Array
	if species == "boss" or tags.has("boss"):
		return "boss"
	if species == "elite" or tags.has("elite"):
		return "elite"
	return "battle"
