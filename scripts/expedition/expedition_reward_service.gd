class_name ExpeditionRewardService
extends RefCounted

const RewardServiceScript := preload("res://scripts/sim/reward_service.gd")
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


static func apply_loot_loss_on_defeat(loot: Array) -> Dictionary:
	var rules := ExpeditionRulesServiceScript.rules()
	var drop_ratio := clampf(float(rules.get("defeat_loot_drop_ratio", 0.3)), 0.0, 1.0)
	if drop_ratio <= 0.0:
		return {"lost": []}
	var candidates: Array = []
	var total_count := 0
	for i in loot.size():
		var row_v: Variant = loot[i]
		if not row_v is Dictionary:
			continue
		var count := int((row_v as Dictionary).get("count", 0))
		if count <= 0:
			continue
		var raw_drop := float(count) * drop_ratio
		candidates.append({
			"idx": i,
			"count": count,
			"drop": int(floor(raw_drop)),
			"fraction": raw_drop - floor(raw_drop),
		})
		total_count += count
	if candidates.is_empty():
		return {"lost": []}
	var target_drop := mini(total_count, maxi(1, int(round(float(total_count) * drop_ratio))))
	var assigned := 0
	for candidate_v in candidates:
		var candidate := candidate_v as Dictionary
		assigned += int(candidate.get("drop", 0))
	var remaining := target_drop - assigned
	if remaining > 0:
		candidates.sort_custom(_sort_loss_candidate)
	for candidate_v in candidates:
		if remaining <= 0:
			break
		var candidate := candidate_v as Dictionary
		var add := mini(remaining, int(candidate.get("count", 0)) - int(candidate.get("drop", 0)))
		candidate["drop"] = int(candidate.get("drop", 0)) + add
		remaining -= add
	candidates.sort_custom(_sort_loss_candidate_by_index)
	var lost: Array = []
	for candidate_v in candidates:
		var candidate := candidate_v as Dictionary
		var idx: int = int(candidate.get("idx", -1))
		var row := loot[idx] as Dictionary
		var kind := str(row.get("kind", "item"))
		var id_key := str(row.get("id", ""))
		var drop := mini(int(row.get("count", 0)), int(candidate.get("drop", 0)))
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


static func _sort_loss_candidate(a: Dictionary, b: Dictionary) -> bool:
	var frac_a := float(a.get("fraction", 0.0))
	var frac_b := float(b.get("fraction", 0.0))
	if not is_equal_approx(frac_a, frac_b):
		return frac_a > frac_b
	return int(a.get("idx", 0)) < int(b.get("idx", 0))


static func _sort_loss_candidate_by_index(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("idx", 0)) < int(b.get("idx", 0))


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
