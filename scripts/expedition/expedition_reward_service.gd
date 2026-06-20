class_name ExpeditionRewardService
extends RefCounted

const RewardServiceScript := preload("res://scripts/sim/reward_service.gd")
const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")
const ExpeditionRulesServiceScript := preload("res://scripts/expedition/expedition_rules_service.gd")
const DropPoolServiceScript := preload("res://scripts/sim/drop_pool_service.gd")


static func roll_event_rewards(event: Dictionary, rng: RandomNumberGenerator) -> Array:
	var rewards := DropPoolServiceScript.roll_event_rewards(event, rng, _reward_context_for_event(event))
	return apply_reward_budget(event, rewards)


static func reward_budget_value_for_event(event: Dictionary) -> float:
	var rules := ExpeditionRulesServiceScript.rules()
	var budget := _reward_budget_rules(rules)
	if not bool(budget.get("enabled", true)):
		return 0.0
	var base_per_day := maxf(0.0, float(budget.get("daily_base_value", 10.0)))
	var difficulty := maxi(1, int(event.get("difficulty", 1)))
	var duration_days := maxi(1, int(event.get("duration_days", 1)))
	var growth := maxf(0.0, float(budget.get("difficulty_growth", 0.18)))
	var type_multipliers := budget.get("event_type_multipliers", {}) as Dictionary
	var event_type := str(event.get("type", "travel"))
	var type_multiplier := maxf(0.0, float(type_multipliers.get(event_type, 1.0)))
	return base_per_day * float(duration_days) * (1.0 + float(difficulty - 1) * growth) * type_multiplier


static func apply_reward_budget(event: Dictionary, rewards: Array) -> Array:
	if rewards.is_empty():
		return rewards
	var rules := ExpeditionRulesServiceScript.rules()
	var budget := _reward_budget_rules(rules)
	if not bool(budget.get("enabled", true)):
		return rewards
	var target_value := reward_budget_value_for_event(event)
	if target_value <= 0.0:
		return rewards
	var current_value := reward_value(rewards)
	if current_value <= 0.0:
		return rewards
	var min_scale := maxf(0.01, float(budget.get("min_scale", 0.5)))
	var max_scale := maxf(min_scale, float(budget.get("max_scale", 3.0)))
	var scale := clampf(target_value / current_value, min_scale, max_scale)
	var out: Array = []
	for reward_v in rewards:
		if not reward_v is Dictionary:
			continue
		var reward := (reward_v as Dictionary).duplicate(true)
		var kind := str(reward.get("kind", "item"))
		var count := maxi(1, int(reward.get("count", 1)))
		if kind != "equip":
			reward["count"] = maxi(1, int(round(float(count) * scale)))
		out.append(reward)
	return RewardServiceScript.merge_rewards(out)


static func reward_value(rewards: Array) -> float:
	var total := 0.0
	for reward_v in rewards:
		if not reward_v is Dictionary:
			continue
		var reward := reward_v as Dictionary
		total += _unit_value(reward) * float(maxi(0, int(reward.get("count", 0))))
	return total


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


static func _reward_context_for_event(event: Dictionary) -> Dictionary:
	return {
		"difficulty": maxi(1, int(event.get("difficulty", 1))),
		"location_id": str(event.get("location_id", "")),
		"event_type": str(event.get("type", "")),
		"duration_days": maxi(1, int(event.get("duration_days", 1))),
		"reward_budget_value": reward_budget_value_for_event(event),
	}


static func _reward_budget_rules(rules: Dictionary) -> Dictionary:
	var budget_v: Variant = rules.get("reward_budget", {})
	if budget_v is Dictionary:
		return (budget_v as Dictionary).duplicate(true)
	return {}


static func _unit_value(reward: Dictionary) -> float:
	var budget := _reward_budget_rules(ExpeditionRulesServiceScript.rules())
	var unit_values := budget.get("unit_values", {}) as Dictionary
	var kind := str(reward.get("kind", "item"))
	match kind:
		"currency":
			return maxf(0.01, float(unit_values.get("currency", 1.0)))
		"equip":
			return maxf(0.01, float(unit_values.get("equip", 120.0)))
		_:
			var base := maxf(0.01, float(unit_values.get("item", 10.0)))
			var grade := maxi(1, int(reward.get("material_grade", 1)))
			var grade_multipliers := budget.get("material_grade_multipliers", {}) as Dictionary
			return base * maxf(0.01, float(grade_multipliers.get(str(grade), grade)))
