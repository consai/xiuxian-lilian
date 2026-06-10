class_name ExpeditionDirectorService
extends RefCounted

const EventService := preload("res://scripts/expedition/expedition_event_service.gd")


static func select_next_event(context: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var location := context.get("location", {}) as Dictionary
	var candidates := _pool_candidates(location, context)
	if candidates.is_empty():
		return {}
	var active_chain_id := str(context.get("active_chain_id", ""))
	if active_chain_id != "":
		var chain_candidates := candidates.filter(func(event_v: Variant) -> bool:
			var chain_id := str((event_v as Dictionary).get("chain_id", ""))
			return chain_id == "" or chain_id == active_chain_id
		)
		if not chain_candidates.is_empty():
			candidates = chain_candidates
	if _resource_ratio(context) < 0.35:
		for event_v in candidates:
			var event := event_v as Dictionary
			if str(event.get("type", "")) == "recover":
				return event.duplicate(true)
	return _weighted_pick(candidates, context.get("world_state", {}) as Dictionary, rng)


static func _pool_candidates(location: Dictionary, context: Dictionary) -> Array:
	var depth := int(context.get("depth", 1))
	var out: Array = []
	for event_id_v in location.get("event_pool", []) as Array:
		var event := EventService.by_id(str(event_id_v))
		if event.is_empty():
			continue
		var min_depth := maxi(1, int(event.get("min_depth", 1)))
		if depth < min_depth:
			continue
		var max_depth := int(event.get("max_depth", 0))
		if max_depth > 0 and depth > max_depth:
			continue
		if _is_available(event, context):
			out.append(event)
	return out


static func _weighted_pick(candidates: Array, world_state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var weights: Array[int] = []
	var total := 0
	for event_v in candidates:
		var event := event_v as Dictionary
		var chain_id := str(event.get("chain_id", ""))
		var weight := maxi(1, int(event.get("weight", 10)))
		if chain_id == "wolf_king":
			weight += int(world_state.get("wolf_threat", 0))
		elif chain_id == "sword_tomb":
			weight += int(world_state.get("sword_tomb_opening", 0))
		elif chain_id == "demonic_ritual":
			weight += int(world_state.get("sect_unrest", 0))
		weights.append(maxi(1, weight))
		total += maxi(1, weight)
	var roll := rng.randi_range(1, total)
	for index in candidates.size():
		roll -= weights[index]
		if roll <= 0:
			return (candidates[index] as Dictionary).duplicate(true)
	return (candidates.back() as Dictionary).duplicate(true)


static func _is_available(event: Dictionary, context: Dictionary) -> bool:
	if event.is_empty():
		return false
	var completed := context.get("completed_events", []) as Array
	if bool(event.get("once_per_expedition", false)) and completed.has(str(event.get("id", ""))):
		return false
	var stats := context.get("stats", {}) as Dictionary
	var rules := ExpeditionRulesService.rules()
	var max_battles := maxi(1, int(rules.get("max_battle_choices", 1)))
	if ExpeditionRulesService.is_battle_type(str(event.get("type", ""))) and int(stats.get("battles", 0)) >= max_battles:
		return false
	var chain_id := str(event.get("chain_id", ""))
	var active_chain_id := str(context.get("active_chain_id", ""))
	if chain_id != "" and active_chain_id != "" and chain_id != active_chain_id:
		return false
	if str(event.get("risk_text", "")) == "结局":
		if active_chain_id == "" or chain_id != active_chain_id:
			return false
	return true


static func _resource_ratio(context: Dictionary) -> float:
	var runtime := context.get("runtime", {}) as Dictionary
	var attrs := context.get("player_attrs", {}) as Dictionary
	var hp_ratio := float(runtime.get("hp", 0.0)) / maxf(1.0, float(attrs.get(FightAttr.HP_MAX, 100.0)))
	var mp_ratio := float(runtime.get("mp", 0.0)) / maxf(1.0, float(attrs.get(FightAttr.MP_MAX, 100.0)))
	return minf(hp_ratio, mp_ratio)
