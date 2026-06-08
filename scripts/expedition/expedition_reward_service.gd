class_name ExpeditionRewardService
extends RefCounted

const RewardServiceScript := preload("res://scripts/sim/reward_service.gd")
const ExpeditionRulesServiceScript := preload("res://scripts/expedition/expedition_rules_service.gd")


static func roll_event_rewards(event: Dictionary, depth: int, rng: RandomNumberGenerator) -> Array:
	var multiplier := ExpeditionRulesServiceScript.reward_depth_multiplier(depth)
	var pool: Array = event.get("rewards", []) as Array
	if pool.is_empty():
		return []
	var rolls := maxi(0, int(event.get("reward_rolls", 1)))
	if rolls <= 0 and not pool.is_empty():
		rolls = 1
	var out: Array = []
	for _i in rolls:
		var row := _weighted_pick(pool, rng)
		if row.is_empty():
			continue
		var reward := row.duplicate(true)
		var min_count := maxi(1, int(row.get("min", 1)))
		var max_count := maxi(min_count, int(row.get("max", min_count)))
		var base_count := rng.randi_range(min_count, max_count)
		var scaled := maxi(1, int(floor(float(base_count) * multiplier)))
		reward["count"] = scaled
		reward.erase("weight")
		reward.erase("min")
		reward.erase("max")
		out.append(reward)
	return RewardServiceScript.merge_rewards(out)


static func roll_fixed_rewards(rewards: Array) -> Array:
	return RewardServiceScript.merge_rewards(rewards)


static func apply_loot_loss_on_defeat(loot: Array) -> Dictionary:
	var rules := ExpeditionRulesServiceScript.rules()
	var keep_ratio := float(rules.get("defeat_loot_item_keep_ratio", 0.5))
	var keep_equips := bool(rules.get("defeat_keep_new_equips", false))
	var kept: Array = []
	var lost: Array = []
	for reward_v in loot:
		if not reward_v is Dictionary:
			continue
		var reward := reward_v as Dictionary
		var kind := str(reward.get("kind", "item"))
		var count := maxi(1, int(reward.get("count", 1)))
		if kind == "equip":
			if keep_equips:
				kept.append(reward.duplicate(true))
			else:
				lost.append(reward.duplicate(true))
			continue
		var kept_count := maxi(0, int(floor(float(count) * keep_ratio)))
		var lost_count := count - kept_count
		if kept_count > 0:
			var kept_row := reward.duplicate(true)
			kept_row["count"] = kept_count
			kept.append(kept_row)
		if lost_count > 0:
			var lost_row := reward.duplicate(true)
			lost_row["count"] = lost_count
			lost.append(lost_row)
	return {"kept": kept, "lost": lost}


static func merge_into_loot(loot: Array, rewards: Array) -> void:
	for reward_v in rewards:
		if not reward_v is Dictionary:
			continue
		var reward := reward_v as Dictionary
		var kind := str(reward.get("kind", "item"))
		var id_key := str(reward.get("id", ""))
		var merged := false
		for existing_v in loot:
			if not existing_v is Dictionary:
				continue
			var existing := existing_v as Dictionary
			if str(existing.get("kind", "")) == kind and str(existing.get("id", "")) == id_key:
				existing["count"] = int(existing.get("count", 0)) + int(reward.get("count", 0))
				merged = true
				break
		if not merged:
			loot.append(reward.duplicate(true))


static func _weighted_pick(pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for row_v in pool:
		if row_v is Dictionary:
			total += maxi(0, int((row_v as Dictionary).get("weight", 1)))
	if total <= 0:
		return {}
	var roll := rng.randi_range(1, total)
	for row_v in pool:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		roll -= maxi(0, int(row.get("weight", 1)))
		if roll <= 0:
			return row.duplicate(true)
	return {}
