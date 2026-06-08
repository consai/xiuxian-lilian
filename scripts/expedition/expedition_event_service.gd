class_name ExpeditionEventService
extends RefCounted

const ExpeditionRulesServiceScript := preload("res://scripts/expedition/expedition_rules_service.gd")
const ExpeditionRewardServiceScript := preload("res://scripts/expedition/expedition_reward_service.gd")


static func by_id(event_id: String) -> Dictionary:
	var cm := _config_manager()
	if cm != null and cm.has_method("expedition_event_by_id"):
		return cm.call("expedition_event_by_id", event_id) as Dictionary
	return {}


static func event_pool_for_location(location: Dictionary) -> Array:
	var pool: Array = []
	for event_id_v in location.get("event_pool", []) as Array:
		var event_id := str(event_id_v)
		var event := by_id(event_id)
		if not event.is_empty():
			pool.append(event)
	return pool


static func generate_choices(
		location: Dictionary,
		depth: int,
		visited_once: Array,
		rng: RandomNumberGenerator
) -> Array:
	var rules := ExpeditionRulesServiceScript.rules()
	var choice_count := maxi(1, int(rules.get("choice_count", 3)))
	var max_battle := maxi(0, int(rules.get("max_battle_choices", 1)))
	var candidates := _filter_candidates(location, depth, visited_once)
	var battle_candidates: Array = []
	var other_candidates: Array = []
	for event_v in candidates:
		var event := event_v as Dictionary
		if ExpeditionRulesServiceScript.is_battle_type(str(event.get("type", ""))):
			battle_candidates.append(event)
		else:
			other_candidates.append(event)
	var chosen_ids := {}
	var out: Array = []
	var battle_count := 0
	if not battle_candidates.is_empty() and max_battle > 0 and rng.randf() < 0.55:
		var battle_pick := _weighted_pick(battle_candidates, rng)
		if not battle_pick.is_empty():
			out.append(battle_pick)
			chosen_ids[str(battle_pick.get("id", ""))] = true
			battle_count += 1
	while out.size() < choice_count:
		var pool := other_candidates.duplicate(true)
		if out.size() < choice_count and battle_count < max_battle:
			for event_v in battle_candidates:
				var event := event_v as Dictionary
				var eid := str(event.get("id", ""))
				if not chosen_ids.has(eid):
					pool.append(event)
		pool = pool.filter(func(row_v: Variant) -> bool:
			return not chosen_ids.has(str((row_v as Dictionary).get("id", "")))
		)
		if pool.is_empty():
			break
		var pick := _weighted_pick(pool, rng)
		if pick.is_empty():
			break
		if ExpeditionRulesServiceScript.is_battle_type(str(pick.get("type", ""))):
			if battle_count >= max_battle:
				continue
			battle_count += 1
		out.append(pick)
		chosen_ids[str(pick.get("id", ""))] = true
	return out


static func resolve_non_battle_event(
		event: Dictionary,
		runtime: Dictionary,
		player_attrs: Dictionary,
		depth: int,
		rng: RandomNumberGenerator
) -> Dictionary:
	var event_type := str(event.get("type", ""))
	var feedback_parts: PackedStringArray = []
	match event_type:
		"gather":
			var rewards := ExpeditionRewardServiceScript.roll_event_rewards(event, depth, rng)
			feedback_parts.append("获得战利品")
			return {"ok": true, "rewards": rewards, "feedback": " ".join(feedback_parts)}
		"recover", "hazard":
			for effect_v in event.get("effects", []) as Array:
				if not effect_v is Dictionary:
					continue
				var effect := effect_v as Dictionary
				var effect_type := str(effect.get("type", ""))
				var value := float(effect.get("value", 0.0))
				match effect_type:
					"heal_hp_percent":
						var hp_max := float(player_attrs.get(FightAttr.HP_MAX, 100.0))
						var before := float(runtime.get("hp", 0.0))
						runtime["hp"] = minf(hp_max, before + hp_max * value)
						feedback_parts.append("恢复气血")
					"restore_mp_percent":
						var mp_max := float(player_attrs.get(FightAttr.MP_MAX, 100.0))
						var mp_before := float(runtime.get("mp", 0.0))
						runtime["mp"] = minf(mp_max, mp_before + mp_max * value)
						feedback_parts.append("恢复法力")
					"damage_hp_percent":
						var hp_max_d := float(player_attrs.get(FightAttr.HP_MAX, 100.0))
						var hp_before := float(runtime.get("hp", 0.0))
						runtime["hp"] = maxf(1.0, hp_before - hp_max_d * value)
						feedback_parts.append("受到伤害")
					"drain_mp_percent":
						var mp_max_d := float(player_attrs.get(FightAttr.MP_MAX, 100.0))
						var mp_now := float(runtime.get("mp", 0.0))
						runtime["mp"] = maxf(0.0, mp_now - mp_max_d * value)
						feedback_parts.append("法力流失")
			return {"ok": true, "rewards": [], "feedback": " ".join(feedback_parts)}
		_:
			return {"ok": false, "error": "unsupported event type"}


static func build_battle_enemy(event: Dictionary, depth: int) -> Dictionary:
	var enemy := (event.get("enemy", {}) as Dictionary).duplicate(true)
	var multiplier := ExpeditionRulesServiceScript.enemy_depth_multiplier(depth)
	var attrs := (enemy.get("attrs", {}) as Dictionary).duplicate(true)
	for key in [FightAttr.HP_MAX, FightAttr.ATK, FightAttr.DEF]:
		if attrs.has(key):
			attrs[key] = float(attrs[key]) * multiplier
	enemy["attrs"] = attrs
	if enemy.has("hp"):
		enemy["hp"] = float(enemy["hp"]) * multiplier
	if attrs.has(FightAttr.HP_MAX):
		enemy["hp"] = float(attrs[FightAttr.HP_MAX])
	var enemy_skills: Array = []
	for sid_v in enemy.get("skills", [0]) as Array:
		enemy_skills.append({"id": int(sid_v), "cd": 0.0})
	enemy["skills"] = enemy_skills
	enemy["items"] = []
	enemy["equips"] = []
	return enemy


static func _filter_candidates(location: Dictionary, depth: int, visited_once: Array) -> Array:
	var out: Array = []
	for event_v in event_pool_for_location(location):
		var event := event_v as Dictionary
		var event_id := str(event.get("id", ""))
		if bool(event.get("once_per_expedition", false)) and visited_once.has(event_id):
			continue
		var min_depth := maxi(1, int(event.get("min_depth", 1)))
		if depth < min_depth:
			continue
		var max_depth := int(event.get("max_depth", 0))
		if max_depth > 0 and depth > max_depth:
			continue
		out.append(event)
	return out


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


static func _config_manager() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")
