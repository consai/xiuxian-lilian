class_name ExpeditionEventService
extends RefCounted

const ExpeditionRulesServiceScript := preload("res://scripts/expedition/expedition_rules_service.gd")
const ExpeditionRewardServiceScript := preload("res://scripts/expedition/expedition_reward_service.gd")
const ExpeditionLogServiceScript := preload("res://scripts/expedition/expedition_log_service.gd")
const CharacterStatsScript := preload("res://scripts/sim/character_stats.gd")
const COMMON_ID_PREFIX := "common::"


static func by_id(event_id: String) -> Dictionary:
	if event_id.begins_with(COMMON_ID_PREFIX):
		var parts := event_id.split("::", false)
		if parts.size() == 3:
			var location := _location_by_id(str(parts[1]))
			return _build_common_event(location, str(parts[2]))
	var cm := _config_manager()
	if cm != null and cm.has_method("expedition_event_by_id"):
		return cm.call("expedition_event_by_id", event_id) as Dictionary
	return {}


static func event_pool_for_location(location: Dictionary) -> Array:
	var pool: Array = []
	for template_id_v in location.get("common_event_pool", []) as Array:
		var common_event := _build_common_event(location, str(template_id_v))
		if not common_event.is_empty():
			pool.append(common_event)
	for event_id_v in location.get("map_event_pool", location.get("event_pool", [])) as Array:
		var event_id := str(event_id_v)
		var event := by_id(event_id)
		if not event.is_empty():
			pool.append(event)
	return pool


static func _build_common_event(location: Dictionary, template_id: String) -> Dictionary:
	var location_id := str(location.get("id", "")).strip_edges()
	if location_id == "" or template_id.strip_edges() == "":
		return {}
	var cm := _config_manager()
	if cm == null or not cm.has_method("common_expedition_event_by_id"):
		return {}
	var event := cm.call("common_expedition_event_by_id", template_id) as Dictionary
	if event.is_empty():
		return {}
	var generation := location.get("common_event_generation", {}) as Dictionary
	var overrides := generation.get("overrides", {}) as Dictionary
	var override_v: Variant = overrides.get(template_id, {})
	if override_v is Dictionary:
		for key in (override_v as Dictionary).keys():
			event[key] = (override_v as Dictionary)[key]
	var reward_pool_id := str(event.get("reward_pool", "")).strip_edges()
	if reward_pool_id != "":
		var reward_pools := generation.get("reward_pools", {}) as Dictionary
		event["rewards"] = (reward_pools.get(reward_pool_id, []) as Array).duplicate(true)
	var generated_options: Array = []
	for option_v in event.get("options", []) as Array:
		if not option_v is Dictionary:
			continue
		var option := (option_v as Dictionary).duplicate(true)
		var option_reward_pool_id := str(option.get("reward_pool", "")).strip_edges()
		if option_reward_pool_id != "":
			var option_reward_pools := generation.get("reward_pools", {}) as Dictionary
			option["rewards"] = (option_reward_pools.get(option_reward_pool_id, []) as Array).duplicate(true)
		generated_options.append(option)
	if not generated_options.is_empty():
		event["options"] = generated_options
	var enemy_pool_id := str(event.get("enemy_pool", "")).strip_edges()
	if enemy_pool_id != "":
		var enemy_pools := generation.get("enemy_pools", {}) as Dictionary
		var enemy_v: Variant = enemy_pools.get(enemy_pool_id, {})
		if enemy_v is Dictionary:
			event["enemy"] = (enemy_v as Dictionary).duplicate(true)
	var duration_key := str(event.get("duration_key", event.get("type", ""))).strip_edges()
	var durations := generation.get("duration_days", {}) as Dictionary
	event["duration_days"] = maxi(1, int(durations.get(duration_key, event.get("duration_days", 1))))
	event["id"] = "%s%s::%s" % [COMMON_ID_PREFIX, location_id, template_id]
	event["template_id"] = template_id
	event["location_id"] = location_id
	event["scope"] = "common"
	return event


static func is_decision_event(event: Dictionary) -> bool:
	return str(event.get("mode", "auto")).strip_edges() == "decision"


static func roll_next_event(
		location: Dictionary,
		visited_once: Array,
		rng: RandomNumberGenerator
) -> Dictionary:
	var candidates := _filter_candidates(location, visited_once)
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
	var cid := choice_id.strip_edges()
	var sep_pos := cid.rfind("::")
	if sep_pos < 0:
		return {}
	var parent_id := cid.substr(0, sep_pos).strip_edges()
	var option_id := cid.substr(sep_pos + 2).strip_edges()
	if parent_id == "" or option_id == "":
		return {}
	return {"parent_id": parent_id, "option_id": option_id}


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
		var chained := resolve_non_battle_event(triggered, runtime, player_attrs, rng)
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
		rng: RandomNumberGenerator
) -> Dictionary:
	var event_type := str(event.get("type", ""))
	var scene := str(event.get("desc", "")).strip_edges()
	match event_type:
		"gather":
			var rewards := ExpeditionRewardServiceScript.roll_event_rewards(event, rng)
			var gather_result := ExpeditionLogServiceScript.gather_outcome(event, rewards)
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


static func build_battle_enemy(event: Dictionary) -> Dictionary:
	var enemy := (event.get("enemy", {}) as Dictionary).duplicate(true)
	return _normalize_battle_enemy(enemy)


static func build_battle_enemies(event: Dictionary) -> Array:
	var configured_v: Variant = event.get("enemies", [])
	var out: Array = []
	if configured_v is Array and not (configured_v as Array).is_empty():
		for enemy_v in configured_v as Array:
			if enemy_v is Dictionary:
				out.append(_normalize_battle_enemy(enemy_v as Dictionary))
		return out
	var base := build_battle_enemy(event)
	if base.is_empty():
		return []
	var count := _battle_enemy_count(event)
	for i in count:
		out.append(_scale_enemy_for_group(base, event, i, count))
	return out


static func _normalize_battle_enemy(enemy_src: Dictionary) -> Dictionary:
	var enemy := enemy_src.duplicate(true)
	var attrs := (enemy.get("attrs", {}) as Dictionary).duplicate(true)
	if enemy.has("foundations"):
		attrs = CharacterStatsScript.build_combat_attrs(enemy.get("foundations", {}))
	else:
		attrs = CharacterStatsScript.finalize_combat_attrs(attrs)
	enemy["attrs"] = attrs
	if attrs.has(FightAttr.HP_MAX):
		enemy["hp"] = float(attrs[FightAttr.HP_MAX])
	elif enemy.has("hp"):
		enemy["hp"] = float(enemy["hp"])
	var enemy_skills: Array = []
	for sid_v in enemy.get("skills", [0]) as Array:
		if sid_v is Dictionary:
			var slot := (sid_v as Dictionary).duplicate(true)
			slot["id"] = int(slot.get("id", -1))
			slot["cd"] = maxf(0.0, float(slot.get("cd", 0.0)))
			enemy_skills.append(slot)
		else:
			enemy_skills.append({"id": int(sid_v), "cd": 0.0})
	enemy["skills"] = enemy_skills
	enemy["items"] = []
	enemy["equips"] = []
	return enemy


static func _battle_enemy_count(event: Dictionary) -> int:
	if event.has("enemy_count"):
		return clampi(int(event.get("enemy_count", 1)), 1, 8)
	var event_type := str(event.get("type", "")).strip_edges()
	if event_type == "boss":
		return 1
	var difficulty := maxi(1, int(event.get("difficulty", 1)))
	if event_type == "elite":
		return clampi(1 + int(floor(float(difficulty - 3) / 2.0)), 1, 3)
	return clampi(1 + int(floor(float(difficulty - 2) / 2.0)), 1, 4)


static func _scale_enemy_for_group(
		base: Dictionary,
		event: Dictionary,
		index: int,
		count: int
) -> Dictionary:
	var enemy := base.duplicate(true)
	var attrs := (enemy.get("attrs", {}) as Dictionary).duplicate(true)
	var hp_scale := 1.0
	var atk_scale := 1.0
	if count > 1:
		hp_scale = 0.48 if count <= 2 else 0.38
		atk_scale = 0.58 if count <= 2 else 0.45
	if attrs.has(FightAttr.HP_MAX):
		attrs[FightAttr.HP_MAX] = maxf(1.0, float(attrs[FightAttr.HP_MAX]) * hp_scale)
	for key in [FightAttr.PHYSICAL_ATK, FightAttr.MAGIC_ATK]:
		if attrs.has(key):
			attrs[key] = maxf(1.0, float(attrs[key]) * atk_scale)
	if attrs.has(FightAttr.SPD):
		var offset := (float(index) - float(count - 1) * 0.5) * 3.0
		attrs[FightAttr.SPD] = maxf(1.0, float(attrs[FightAttr.SPD]) + offset)
	enemy["attrs"] = attrs
	if attrs.has(FightAttr.HP_MAX):
		enemy["hp"] = float(attrs[FightAttr.HP_MAX])
	var skill_effect_scale := _enemy_skill_effect_scale(event, atk_scale, count)
	enemy["skills"] = _scale_enemy_skill_slots(enemy.get("skills", []), skill_effect_scale)
	var base_name := str(base.get("name", "敌人")).strip_edges()
	if count > 1:
		enemy["name"] = "%s·%d" % [base_name, index + 1]
	return enemy


static func _enemy_skill_effect_scale(event: Dictionary, atk_scale: float, count: int) -> float:
	if event.has("enemy_skill_effect_scale"):
		return clampf(float(event.get("enemy_skill_effect_scale", 1.0)), 0.1, 1.0)
	var event_type := str(event.get("type", "")).strip_edges()
	if event_type == "boss":
		return 1.0
	var difficulty := maxi(1, int(event.get("difficulty", 1)))
	var scale := 1.0
	if event_type == "elite":
		scale = clampf(0.55 + float(difficulty) * 0.05, 0.65, 0.95)
	else:
		scale = clampf(0.30 + float(difficulty) * 0.05, 0.35, 0.85)
	if count > 1:
		scale = minf(scale, atk_scale)
	return scale


static func _scale_enemy_skill_slots(raw: Variant, effect_scale: float) -> Array:
	var out: Array = []
	if not raw is Array:
		return out
	for slot_v in raw as Array:
		if not slot_v is Dictionary:
			continue
		var slot := (slot_v as Dictionary).duplicate(true)
		var skill_id := int(slot.get("id", -1))
		if skill_id > 0 and effect_scale < 1.0 and not slot.has("effect_value_scale"):
			slot["effect_value_scale"] = clampf(effect_scale, 0.1, 1.0)
		out.append(slot)
	return out


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
				var damage_feedback := _configured_effect_feedback(effect, damage)
				if damage_feedback != "":
					feedback_parts.append(damage_feedback)
				elif damage >= 1.0:
					feedback_parts.append("猝不及防一阵剧痛，气血受损 %d 点。" % int(round(damage)))
				else:
					feedback_parts.append("虽有磕碰，所幸无大碍。")
			"drain_mp_percent":
				var mp_max_d := float(player_attrs.get(FightAttr.MP_MAX, 100.0))
				var mp_now := float(runtime.get("mp", 0.0))
				var drained := minf(mp_now, mp_max_d * value)
				runtime["mp"] = maxf(0.0, mp_now - mp_max_d * value)
				var drain_feedback := _configured_effect_feedback(effect, drained)
				if drain_feedback != "":
					feedback_parts.append(drain_feedback)
				elif drained >= 1.0:
					feedback_parts.append("雾气侵体，法力流失 %d 点。" % int(round(drained)))
				else:
					feedback_parts.append("心神微乱，法力略有损耗。")
	return feedback_parts


static func _configured_effect_feedback(effect: Dictionary, amount: float) -> String:
	var feedback := str(effect.get("feedback", "")).strip_edges()
	if feedback == "":
		return ""
	return feedback.replace("{amount}", str(int(round(amount))))


static func _join_feedback(prefix: String, body: String) -> String:
	var lead := prefix.strip_edges()
	var tail := body.strip_edges()
	if lead == "":
		return tail
	if tail == "":
		return lead
	return "%s：%s" % [lead, tail]


static func _filter_candidates(location: Dictionary, visited_once: Array) -> Array:
	var min_difficulty := maxi(1, int(location.get("min_difficulty", 1)))
	var max_difficulty := int(location.get("max_difficulty", 0))
	var out: Array = []
	for event_v in event_pool_for_location(location):
		var event := event_v as Dictionary
		var event_id := str(event.get("id", ""))
		if bool(event.get("once_per_expedition", false)) and visited_once.has(event_id):
			continue
		var event_difficulty := maxi(1, int(event.get("difficulty", 1)))
		if event_difficulty < min_difficulty:
			continue
		if max_difficulty > 0 and event_difficulty > max_difficulty:
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


static func _location_by_id(location_id: String) -> Dictionary:
	var cm := _config_manager()
	if cm != null and cm.has_method("location_by_id"):
		return cm.call("location_by_id", location_id) as Dictionary
	return {}
