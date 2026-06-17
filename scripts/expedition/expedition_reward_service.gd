class_name ExpeditionRewardService
extends RefCounted

const RewardServiceScript := preload("res://scripts/sim/reward_service.gd")
const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")
const ExpeditionRulesServiceScript := preload("res://scripts/expedition/expedition_rules_service.gd")


static func roll_event_rewards(event: Dictionary, rng: RandomNumberGenerator) -> Array:
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
		reward["count"] = rng.randi_range(min_count, max_count)
		reward.erase("weight")
		reward.erase("min")
		reward.erase("max")
		out.append(reward)
	return RewardServiceScript.merge_rewards(out)


static func roll_fixed_rewards(rewards: Array) -> Array:
	return RewardServiceScript.merge_rewards(rewards)


static func grant_to_player(game_state: Node, session_loot: Array, rewards: Array) -> Array:
	if game_state == null or rewards.is_empty():
		return []
	var applied := RewardServiceScript.apply_rewards(game_state, rewards)
	merge_into_loot(session_loot, applied)
	return applied


static func apply_inventory_loss_on_defeat(inventory: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var rules := ExpeditionRulesServiceScript.rules()
	var min_stacks := maxi(0, int(rules.get("defeat_inventory_drop_min_stacks", 1)))
	var max_stacks := maxi(min_stacks, int(rules.get("defeat_inventory_drop_max_stacks", 2)))
	var min_ratio := clampf(float(rules.get("defeat_inventory_drop_min_ratio", 0.25)), 0.0, 1.0)
	var max_ratio := clampf(float(rules.get("defeat_inventory_drop_max_ratio", 0.75)), min_ratio, 1.0)
	var candidates: Array = []
	for iid_v in inventory.keys():
		var iid := str(iid_v)
		if int(inventory.get(iid, 0)) > 0:
			candidates.append(iid)
	if candidates.is_empty():
		return {"lost": []}
	_shuffle_array(candidates, rng)
	var pick_count := mini(candidates.size(), rng.randi_range(min_stacks, max_stacks))
	var lost: Array = []
	for i in pick_count:
		var iid := str(candidates[i])
		var count := int(inventory.get(iid, 0))
		if count <= 0:
			continue
		var min_drop := maxi(1, int(floor(float(count) * min_ratio)))
		var max_drop := maxi(min_drop, int(floor(float(count) * max_ratio)))
		var drop := mini(count, rng.randi_range(min_drop, max_drop))
		if drop <= 0:
			continue
		InventoryServiceScript.remove_item(inventory, iid, drop)
		lost.append({"kind": "item", "id": iid, "count": drop, "source": "inventory"})
	return {"lost": lost}


static func apply_loot_loss_on_defeat(loot: Array, rng: RandomNumberGenerator) -> Dictionary:
	var rules := ExpeditionRulesServiceScript.rules()
	var min_stacks := maxi(0, int(rules.get("defeat_loot_drop_min_stacks", 1)))
	var max_stacks := maxi(min_stacks, int(rules.get("defeat_loot_drop_max_stacks", 2)))
	var min_ratio := clampf(float(rules.get("defeat_loot_drop_min_ratio", 0.25)), 0.0, 1.0)
	var max_ratio := clampf(float(rules.get("defeat_loot_drop_max_ratio", 0.75)), min_ratio, 1.0)
	var candidate_indices: Array = []
	for i in loot.size():
		var row_v: Variant = loot[i]
		if not row_v is Dictionary:
			continue
		if int((row_v as Dictionary).get("count", 0)) > 0:
			candidate_indices.append(i)
	if candidate_indices.is_empty():
		return {"lost": []}
	_shuffle_array(candidate_indices, rng)
	var pick_count := mini(candidate_indices.size(), rng.randi_range(min_stacks, max_stacks))
	var lost: Array = []
	for i in pick_count:
		var idx: int = int(candidate_indices[i])
		var row := loot[idx] as Dictionary
		var kind := str(row.get("kind", "item"))
		var id_key := str(row.get("id", ""))
		var count := int(row.get("count", 0))
		if count <= 0:
			continue
		var min_drop := maxi(1, int(floor(float(count) * min_ratio)))
		var max_drop := maxi(min_drop, int(floor(float(count) * max_ratio)))
		var drop := mini(count, rng.randi_range(min_drop, max_drop))
		if drop <= 0:
			continue
		_remove_reward_count(loot, idx, drop)
		lost.append({"kind": kind, "id": id_key, "count": drop, "source": "session_loot"})
	_prune_empty_loot(loot)
	return {"lost": lost}


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


static func _remove_reward_count(loot: Array, idx: int, amount: int) -> void:
	if idx < 0 or idx >= loot.size():
		return
	var row_v: Variant = loot[idx]
	if not row_v is Dictionary:
		return
	var row := row_v as Dictionary
	row["count"] = maxi(0, int(row.get("count", 0)) - amount)


static func _prune_empty_loot(loot: Array) -> void:
	for i in range(loot.size() - 1, -1, -1):
		var row_v: Variant = loot[i]
		if not row_v is Dictionary:
			loot.remove_at(i)
			continue
		if int((row_v as Dictionary).get("count", 0)) <= 0:
			loot.remove_at(i)


static func _shuffle_array(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = values[i]
		values[i] = values[j]
		values[j] = tmp


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
