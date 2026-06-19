class_name ConditionService
extends RefCounted


static func all_met(conditions: Array, context: Dictionary = {}) -> bool:
	for condition_v in conditions:
		if condition_v is Dictionary and not is_met(condition_v as Dictionary, context):
			return false
	return true


static func is_met(condition: Dictionary, context: Dictionary = {}) -> bool:
	var ctype := str(condition.get("type", "")).strip_edges()
	if ctype == "" or ctype == "always":
		return true
	match ctype:
		"tag_at_least":
			var tag := str(condition.get("tag", "")).strip_edges()
			var need := int(condition.get("count", condition.get("value", 1)))
			var stats := context.get("tag_stats", {}) as Dictionary
			return int(stats.get(tag, 0)) >= need
		"realm_at_least":
			var current := str(context.get("realm", context.get("realm_id", "")))
			var need_realm := str(condition.get("realm", condition.get("value", "")))
			return current == need_realm or need_realm == ""
		"difficulty_at_least":
			return int(context.get("difficulty", 1)) >= int(condition.get("value", condition.get("difficulty", 1)))
		"difficulty_at_most":
			return int(context.get("difficulty", 1)) <= int(condition.get("value", condition.get("difficulty", 1)))
		_:
			return false


static func weight_modifier(modifiers: Array, context: Dictionary = {}) -> float:
	var multiplier := 1.0
	for modifier_v in modifiers:
		if not modifier_v is Dictionary:
			continue
		var modifier := modifier_v as Dictionary
		if not all_met(modifier.get("conditions", []) as Array, context):
			continue
		multiplier *= maxf(0.0, float(modifier.get("weight_multiplier", modifier.get("multiplier", 1.0))))
	return multiplier
