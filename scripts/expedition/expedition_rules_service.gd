class_name ExpeditionRulesService
extends RefCounted

const BATTLE_TYPES := ["battle", "elite", "boss"]


static func rules() -> Dictionary:
	var cm := _config_manager()
	if cm != null and cm.has_method("expedition_rules"):
		return cm.call("expedition_rules") as Dictionary
	return {}


static func elapsed_days(steps: int) -> int:
	var cfg := rules()
	var per_day := maxi(1, int(cfg.get("steps_per_day", 3)))
	var minimum := maxi(1, int(cfg.get("minimum_elapsed_days", 1)))
	return maxi(minimum, int(ceil(float(maxi(0, steps)) / float(per_day))))


static func enemy_depth_multiplier(depth: int) -> float:
	var growth := float(rules().get("enemy_depth_growth", 0.08))
	return 1.0 + float(maxi(1, depth) - 1) * growth


static func reward_depth_multiplier(depth: int) -> float:
	var growth := float(rules().get("reward_depth_growth", 0.05))
	return 1.0 + float(maxi(1, depth) - 1) * growth


static func is_battle_type(event_type: String) -> bool:
	return event_type in BATTLE_TYPES


static func _config_manager() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")
