class_name ExpeditionRulesService
extends RefCounted

const BATTLE_TYPES := ["battle", "elite", "boss"]


static func rules() -> Dictionary:
	var cm := _config_manager()
	if cm != null and cm.has_method("expedition_rules"):
		return cm.call("expedition_rules") as Dictionary
	return {}


static func elapsed_days(days_elapsed: int) -> int:
	var minimum := maxi(1, int(rules().get("minimum_elapsed_days", 1)))
	return maxi(minimum, maxi(0, days_elapsed))


static func should_trigger_event_today(idle_days: int, rng: RandomNumberGenerator) -> bool:
	var cfg := rules()
	var max_idle := maxi(1, int(cfg.get("max_idle_days", 4)))
	if idle_days >= max_idle:
		return true
	var chance := clampf(float(cfg.get("event_day_chance", 0.55)), 0.0, 1.0)
	if chance >= 1.0:
		return true
	if chance <= 0.0:
		return false
	return rng.randf() < chance


static func is_battle_type(event_type: String) -> bool:
	return event_type in BATTLE_TYPES


static func _config_manager() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")
