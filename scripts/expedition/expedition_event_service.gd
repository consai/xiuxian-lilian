class_name ExpeditionEventService
extends RefCounted

const ExpeditionRulesServiceScript := preload("res://scripts/expedition/expedition_rules_service.gd")
const ExpeditionRewardServiceScript := preload("res://scripts/expedition/expedition_reward_service.gd")
const ExpeditionLogServiceScript := preload("res://scripts/expedition/expedition_log_service.gd")


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


static func is_decision_event(event: Dictionary) -> bool:
	return str(event.get("mode", "auto")).strip_edges() == "decision"


static func roll_next_event(
		location: Dictionary,
		depth: int,
		visited_once: Array,
		rng: RandomNumberGenerator
) -> Dictionary:
	var candidates := _filter_candidates(location, depth, visited_once)
	var pick := _weighted_pick(candidates, rng)
	return pick.duplicate(true) if not pick.is_empty() else {}


static func decision_options_as_choices(event: Dictionary) -> Array:
	var parent_id := str(event.get("id", "")).strip_edges()
	if parent_id == "":
		return []
	var out: Array = []
	for option_v in event.get("options", []) as Array:
		if not option_v is Dictionary:
			continue
		var option := option_v as Dictionary
		var option_id := str(option.get("id", "")).strip_edges()
		if option_id == "":
			continue
		out.append({
			"id": decision_choice_id(parent_id, option_id),
			"type": "decision_option",
			"parent_event_id": parent_id,
			"option_id": option_id,
			"name": str(option.get("label", option_id)),
			"desc": str(option.get("desc", "")),
			"risk_text": str(option.get("risk_text", "抉择")),
		})
	return out


static func decision_choice_id(parent_id: String, option_id: String) -> String:
	return "%s::%s" % [parent_id.strip_edges(), option_id.strip_edges()]


static func parse_decision_choice_id(choice_id: String) -> Dictionary:
	var parts := choice_id.split("::", false)
	if parts.size() != 2:
		return {}
	return {"parent_id": str(parts[0]).strip_edges(), "option_id": str(parts[1]).strip_edges()}


static func find_decision_option(event: Dictionary, option_id: String) -> Dictionary:
	var oid := option_id.strip_edges()
	for option_v in event.get("options", []) as Array:
		if not option_v is Dictionary:
			continue
		var option := option_v as Dictionary
		if str(option.get("id", "")).strip_edges() == oid:
			return option.duplicate(true)
	return {}


static func resolve_decision_option(
		parent_event: Dictionary,
		option: Dictionary,
		runtime: Dictionary,
		player_attrs: Dictionary,
		depth: int,
		rng: RandomNumberGenerator
) -> Dictionary:
	var trigger_id := str(option.get("trigger_event", "")).strip_edges()
	if trigger_id != "":
		var triggered := by_id(trigger_id)
		if triggered.is_empty():
			return {"ok": false, "error": "抉择引用了未知事件"}
		var event_type := str(triggered.get("type", ""))
		if ExpeditionRulesServiceScript.is_battle_type(event_type):
			var choice_text := str(option.get("desc", option.get("label", ""))).strip_edges()
			var enemy_name := str((triggered.get("enemy", {}) as Dictionary).get("name", triggered.get("name", "强敌")))
			var encounter := "%s——%s拦住了去路！" % [choice_text, enemy_name]
			return {
				"ok": true,
				"type": "battle",
				"event": triggered,
				"scene": str(parent_event.get("desc", "")).strip_edges(),
				"outcome": encounter,
				"feedback": encounter,
				"log_name": str(parent_event.get("name", "")),
			}
		var chained := resolve_non_battle_event(
			triggered, runtime, player_attrs, depth, rng
		)
		if not bool(chained.get("ok", false)):
			return chained
		chained["event"] = triggered
		var choice_text := str(option.get("desc", option.get("label", ""))).strip_edges()
		var chain_outcome := str(chained.get("outcome", chained.get("feedback", ""))).strip_edges()
		var outcome_parts: PackedStringArray = []
		if choice_text != "":
			outcome_parts.append(choice_text)
		if chain_outcome != "":
			outcome_parts.append(chain_outcome)
		var merged_outcome := " ".join(outcome_parts)
		chained["scene"] = str(parent_event.get("desc", "")).strip_edges()
		chained["outcome"] = merged_outcome
		chained["feedback"] = merged_outcome
		chained["log_name"] = str(parent_event.get("name", ""))
		return chained
	var rewards := ExpeditionRewardServiceScript.roll_event_rewards(
		{
			"rewards": option.get("rewards", []),
			"reward_rolls": maxi(1, int(option.get("reward_rolls", 1))),
		},
		depth,
		rng
	)
	var effect_lines := _apply_effects(option.get("effects", []) as Array, runtime, player_attrs)
	var scene := str(parent_event.get("desc", "")).strip_edges()
	var choice_text := str(option.get("desc", option.get("label", ""))).strip_edges()
	var outcome_parts: PackedStringArray = []
	if choice_text != "":
		outcome_parts.append(choice_text)
	outcome_parts.append_array(effect_lines)
	var loot := ExpeditionLogServiceScript.format_rewards(rewards)
	if loot != "":
		outcome_parts.append(loot)
	var outcome := " ".join(outcome_parts)
	return {
		"ok": true,
		"rewards": rewards,
		"scene": scene,
		"outcome": outcome,
		"feedback": outcome,
		"log_name": str(parent_event.get("name", "")),
		"event": parent_event,
	}


static func resolve_non_battle_event(
		event: Dictionary,
		runtime: Dictionary,
		player_attrs: Dictionary,
		depth: int,
		rng: RandomNumberGenerator
) -> Dictionary:
	var event_type := str(event.get("type", ""))
	var scene := str(event.get("desc", "")).strip_edges()
	match event_type:
		"gather":
			var rewards := ExpeditionRewardServiceScript.roll_event_rewards(event, depth, rng)
			var gather_result := ExpeditionLogServiceScript.gather_outcome(rewards)
			return {
				"ok": true,
				"rewards": rewards,
				"scene": scene,
				"outcome": gather_result,
				"feedback": gather_result,
				"event": event,
			}
		"travel":
			var travel_result := ExpeditionLogServiceScript.travel_outcome(event)
			return {
				"ok": true,
				"rewards": [],
				"scene": scene,
				"outcome": travel_result,
				"feedback": travel_result,
				"event": event,
			}
		"recover", "hazard":
			var effect_lines := _apply_effects(
				event.get("effects", []) as Array, runtime, player_attrs
			)
			var hazard_result := ExpeditionLogServiceScript.format_effect_lines(effect_lines)
			return {
				"ok": true,
				"rewards": [],
				"scene": scene,
				"outcome": hazard_result,
				"feedback": hazard_result,
				"event": event,
			}
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


static func _apply_effects(
		effects: Array,
		runtime: Dictionary,
		player_attrs: Dictionary
) -> PackedStringArray:
	var feedback_parts: PackedStringArray = []
	for effect_v in effects:
		if not effect_v is Dictionary:
			continue
		var effect := effect_v as Dictionary
		var effect_type := str(effect.get("type", ""))
		var value := float(effect.get("value", 0.0))
		match effect_type:
			"heal_hp_percent":
				var hp_max := float(player_attrs.get(FightAttr.HP_MAX, 100.0))
				var before := float(runtime.get("hp", 0.0))
				var healed := minf(hp_max - before, hp_max * value)
				runtime["hp"] = before + healed
				if healed >= 1.0:
					feedback_parts.append("你盘膝调息，气血回升 %d 点。" % int(round(healed)))
				else:
					feedback_parts.append("伤势已无大碍。")
			"restore_mp_percent":
				var mp_max := float(player_attrs.get(FightAttr.MP_MAX, 100.0))
				var mp_before := float(runtime.get("mp", 0.0))
				var restored := minf(mp_max - mp_before, mp_max * value)
				runtime["mp"] = mp_before + restored
				if restored >= 1.0:
					feedback_parts.append("灵力自丹田涌起，法力恢复 %d 点。" % int(round(restored)))
				else:
					feedback_parts.append("法力充盈，难以再进。")
			"damage_hp_percent":
				var hp_max_d := float(player_attrs.get(FightAttr.HP_MAX, 100.0))
				var hp_before := float(runtime.get("hp", 0.0))
				var damage := minf(hp_before - 1.0, hp_max_d * value)
				runtime["hp"] = maxf(1.0, hp_before - hp_max_d * value)
				if damage >= 1.0:
					feedback_parts.append("猝不及防一阵剧痛，气血受损 %d 点。" % int(round(damage)))
				else:
					feedback_parts.append("虽有磕碰，所幸无大碍。")
			"drain_mp_percent":
				var mp_max_d := float(player_attrs.get(FightAttr.MP_MAX, 100.0))
				var mp_now := float(runtime.get("mp", 0.0))
				var drained := minf(mp_now, mp_max_d * value)
				runtime["mp"] = maxf(0.0, mp_now - mp_max_d * value)
				if drained >= 1.0:
					feedback_parts.append("雾气侵体，法力流失 %d 点。" % int(round(drained)))
				else:
					feedback_parts.append("心神微乱，法力略有损耗。")
	return feedback_parts


static func _join_feedback(prefix: String, body: String) -> String:
	var lead := prefix.strip_edges()
	var tail := body.strip_edges()
	if lead == "":
		return tail
	if tail == "":
		return lead
	return "%s：%s" % [lead, tail]


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
