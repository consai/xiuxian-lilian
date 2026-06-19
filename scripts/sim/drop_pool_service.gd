class_name DropPoolService
extends RefCounted

const RewardServiceScript := preload("res://scripts/sim/reward_service.gd")
const ConditionServiceScript := preload("res://scripts/sim/condition_service.gd")


static func roll_event_rewards(event: Dictionary, rng: RandomNumberGenerator, context: Dictionary = {}) -> Array:
	var roll_context := context.duplicate(true)
	if not roll_context.has("difficulty"):
		roll_context["difficulty"] = maxi(1, int(event.get("difficulty", 1)))
	if not roll_context.has("location_id"):
		roll_context["location_id"] = str(event.get("location_id", ""))
	if not roll_context.has("event_type"):
		roll_context["event_type"] = str(event.get("type", ""))
	var rewards: Array = []
	for result_v in event.get("results", []) as Array:
		if not result_v is Dictionary:
			continue
		var result := result_v as Dictionary
		match str(result.get("type", "")):
			"drop":
				rewards.append_array(roll_pool_for_event(event, str(result.get("drop_pool", event.get("drop_pool", ""))), rng, int(result.get("rolls", 1)), roll_context))
			"rewards":
				rewards.append_array(_roll_entries(result.get("rewards", []) as Array, rng, int(result.get("rolls", 1)), roll_context))
	if rewards.is_empty() and str(event.get("drop_pool", "")).strip_edges() != "":
		rewards = roll_pool_for_event(event, str(event.get("drop_pool", "")), rng, int(event.get("reward_rolls", 1)), roll_context)
	return RewardServiceScript.merge_rewards(rewards)


static func roll_pool_for_event(
		event: Dictionary,
		pool_id: String,
		rng: RandomNumberGenerator,
		rolls: int = 1,
		context: Dictionary = {}
) -> Array:
	var pool := _drop_pool_for_event(event, pool_id)
	if pool.is_empty():
		return []
	return _roll_entries(pool.get("entries", []) as Array, rng, maxi(1, rolls), context)


static func _drop_pool_for_event(event: Dictionary, pool_id: String) -> Dictionary:
	var location_id := str(event.get("location_id", "")).strip_edges()
	if location_id == "" or pool_id.strip_edges() == "":
		return {}
	var cm := _config_manager()
	if cm != null and cm.has_method("location_drop_pool"):
		return cm.call("location_drop_pool", location_id, pool_id) as Dictionary
	return {}


static func _roll_entries(entries: Array, rng: RandomNumberGenerator, rolls: int, context: Dictionary = {}) -> Array:
	var out: Array = []
	for _i in maxi(0, rolls):
		var row := _weighted_pick(entries, rng, context)
		if row.is_empty():
			continue
		var reward := _resolve_reward_variant(row, rng, context)
		var min_count := maxi(1, int(row.get("min", 1)))
		var max_count := maxi(min_count, int(row.get("max", min_count)))
		reward["count"] = rng.randi_range(min_count, max_count)
		reward.erase("weight")
		reward.erase("min")
		reward.erase("max")
		reward.erase("conditions")
		reward.erase("modifiers")
		reward.erase("variants")
		out.append(reward)
	return out


static func _resolve_reward_variant(row: Dictionary, rng: RandomNumberGenerator, context: Dictionary) -> Dictionary:
	var variants_v: Variant = row.get("variants", [])
	if not variants_v is Array or (variants_v as Array).is_empty():
		return row.duplicate(true)
	var pick := _weighted_pick(variants_v as Array, rng, context)
	if pick.is_empty():
		return row.duplicate(true)
	var reward := row.duplicate(true)
	for key in pick.keys():
		reward[key] = pick[key]
	reward.erase("min_difficulty")
	reward.erase("max_difficulty")
	return reward


static func _weighted_pick(entries: Array, rng: RandomNumberGenerator, context: Dictionary) -> Dictionary:
	var weighted: Array = []
	var total := 0.0
	for row_v in entries:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		if not ConditionServiceScript.all_met(row.get("conditions", []) as Array, context):
			continue
		var weight := maxf(0.0, float(row.get("weight", 1.0)))
		weight *= ConditionServiceScript.weight_modifier(row.get("modifiers", []) as Array, context)
		if weight <= 0.0:
			continue
		total += weight
		weighted.append({"row": row, "weight": weight})
	if total <= 0.0:
		return {}
	var roll := rng.randf_range(0.0, total)
	for entry_v in weighted:
		var entry := entry_v as Dictionary
		roll -= float(entry.get("weight", 0.0))
		if roll <= 0.0:
			return (entry.get("row", {}) as Dictionary).duplicate(true)
	return ((weighted.back() as Dictionary).get("row", {}) as Dictionary).duplicate(true)


static func _config_manager() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")
