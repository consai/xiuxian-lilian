class_name LilianRulesService
extends RefCounted

const BATTLE_TYPES := ["battle", "elite", "boss"]
const GameTimeServiceScript := preload("res://scripts/sim/game_time_service.gd")
const EnumActivityTimeScript := preload("res://scripts/enum/enum_activity_time.gd")
const LilianRulesCatalogScript := preload("res://scripts/lilian/lilian_rules_catalog.gd")


static func rules() -> Dictionary:
	return LilianRulesCatalogScript.rules()


static func reward_budget_rules() -> Dictionary:
	return LilianRulesCatalogScript.reward_budget()


static func elapsed_days(days_elapsed: int, major_realm_id: String) -> int:
	var minimum := GameTimeServiceScript.days_for_activity(
		EnumActivityTimeScript.LABEL_LILIAN,
		major_realm_id
	)
	return maxi(minimum, maxi(0, days_elapsed))


static func should_trigger_event_today(idle_days: int, rng: RandomNumberGenerator) -> bool:
	var cfg := rules()
	var max_idle := int(cfg["max_idle_days"])
	if idle_days >= max_idle:
		return true
	var chance := float(cfg["event_day_chance"])
	if chance >= 1.0:
		return true
	if chance <= 0.0:
		return false
	return rng.randf() < chance


static func is_battle_type(event_type: String) -> bool:
	return event_type in BATTLE_TYPES
