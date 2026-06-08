class_name ExpeditionRulesService
extends RefCounted

const PATH := "res://data/expedition_rules.json"

const BATTLE_TYPES := ["battle", "elite", "boss"]


static func rules() -> Dictionary:
	return JsonLoader._read_json_root_object(PATH)


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
