class_name ExpeditionDirectorService
extends RefCounted

const EventService := preload("res://scripts/expedition/expedition_event_service.gd")


static func select_next_event(context: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var location := context.get("location", {}) as Dictionary
	var beats := location.get("journey_beats", []) as Array
	var journey_step := int(context.get("journey_step", 0))
	if journey_step < 0 or journey_step >= beats.size():
		return {}
	var beat := beats[journey_step] as Dictionary
	var candidates: Array = []
	for event_id_v in beat.get("event_ids", []) as Array:
		var event := EventService.by_id(str(event_id_v))
		if _is_available(event, context):
			event["director_beat"] = str(beat.get("beat", ""))
			candidates.append(event)
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
	if _resource_ratio(context) < 0.35 and str(beat.get("beat", "")) == "respite":
		for event_v in candidates:
			var event := event_v as Dictionary
			if str(event.get("type", "")) == "recover":
				return event.duplicate(true)
	return _weighted_pick(candidates, context.get("world_state", {}) as Dictionary, rng)


static func _weighted_pick(candidates: Array, world_state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var weights: Array[int] = []
	var total := 0
	for event_v in candidates:
		var chain_id := str((event_v as Dictionary).get("chain_id", ""))
		var weight := 10
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
	if ExpeditionRulesService.is_battle_type(str(event.get("type", ""))) and int(stats.get("battles", 0)) >= 2:
		return false
	return true


static func _resource_ratio(context: Dictionary) -> float:
	var runtime := context.get("runtime", {}) as Dictionary
	var attrs := context.get("player_attrs", {}) as Dictionary
	var hp_ratio := float(runtime.get("hp", 0.0)) / maxf(1.0, float(attrs.get(FightAttr.HP_MAX, 100.0)))
	var mp_ratio := float(runtime.get("mp", 0.0)) / maxf(1.0, float(attrs.get(FightAttr.MP_MAX, 100.0)))
	return minf(hp_ratio, mp_ratio)
