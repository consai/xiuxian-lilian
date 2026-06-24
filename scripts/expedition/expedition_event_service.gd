class_name ExpeditionEventService
extends RefCounted

const ExpeditionRulesServiceScript := preload("res://scripts/expedition/expedition_rules_service.gd")
const ExpeditionRewardServiceScript := preload("res://scripts/expedition/expedition_reward_service.gd")
const ExpeditionLogServiceScript := preload("res://scripts/expedition/expedition_log_service.gd")
const EnumExpeditionNodeTypeScript := preload("res://scripts/enum/enum_expedition_node_type.gd")
const CharacterStatsScript := preload("res://scripts/sim/character_stats.gd")
const ConditionServiceScript := preload("res://scripts/sim/condition_service.gd")


static func by_id(event_id: String) -> Dictionary:
	var generated := _generated_event_by_id(event_id)
	if not generated.is_empty():
		return generated
	var cm := _config_manager()
	if cm != null and cm.has_method("expedition_event_by_id"):
		var event := cm.call("expedition_event_by_id", event_id) as Dictionary
		if not event.is_empty():
			return event
	if cm != null and cm.has_method("common_expedition_event_by_id"):
		return cm.call("common_expedition_event_by_id", event_id) as Dictionary
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


static func materialize_event_for_context(
		location: Dictionary,
		node: Dictionary,
		event: Dictionary,
		rng: RandomNumberGenerator
) -> Dictionary:
	return _materialize_event_for_context(location, node, event, rng)


static func roll_next_event(
		location: Dictionary,
		visited_once: Array,
		rng: RandomNumberGenerator
) -> Dictionary:
	var candidates := _filter_candidates(location, visited_once)
	var pick := _weighted_pick(candidates, rng)
	if pick.is_empty():
		return {}
	return _materialize_event_for_context(location, {}, pick, rng)


static func roll_event_for_node(
		location: Dictionary,
		node: Dictionary,
		visited_once: Array,
		rng: RandomNumberGenerator
) -> Dictionary:
	var fixed_event_id := str(node.get("fixed_event_id", "")).strip_edges()
	if fixed_event_id != "":
		var fixed_event := by_id(fixed_event_id)
		if not fixed_event.is_empty():
			return _materialize_event_for_context(location, node, fixed_event, rng)
	var candidates := candidates_for_node(location, node, visited_once)
	var pick := _weighted_pick(candidates, rng)
	if not pick.is_empty():
		return _materialize_event_for_context(location, node, pick, rng)
	var generated := _generated_battle_event_for_node(location, node, rng)
	if not generated.is_empty():
		_store_generated_event(generated)
	return generated


static func candidates_for_node(location: Dictionary, node: Dictionary, visited_once: Array) -> Array:
	var type_id := str(node.get("type", EnumExpeditionNodeTypeScript.ID_TRAVEL))
	var candidates := _filter_candidates(location, visited_once, _event_context(location, node))
	var typed: Array = []
	for fallback_type in _node_type_fallbacks(type_id):
		typed = _candidates_matching_node_type(candidates, fallback_type)
		if not typed.is_empty():
			return typed
	return _candidates_matching_node_type(candidates, EnumExpeditionNodeTypeScript.ID_TRAVEL)


static func _node_type_fallbacks(type_id: String) -> PackedStringArray:
	match type_id:
		EnumExpeditionNodeTypeScript.ID_BOSS:
			return PackedStringArray([
				EnumExpeditionNodeTypeScript.ID_BOSS,
				EnumExpeditionNodeTypeScript.ID_ELITE,
				EnumExpeditionNodeTypeScript.ID_BATTLE,
			])
		EnumExpeditionNodeTypeScript.ID_ELITE:
			return PackedStringArray([
				EnumExpeditionNodeTypeScript.ID_ELITE,
				EnumExpeditionNodeTypeScript.ID_BATTLE,
			])
		_:
			return PackedStringArray([type_id])


static func _candidates_matching_node_type(
		candidates: Array,
		type_id: String
) -> Array:
	var out: Array = []
	for event_v in candidates:
		if not event_v is Dictionary:
			continue
		var event := event_v as Dictionary
		if not _event_matches_node_type(event, type_id):
			continue
		out.append(event)
	return out


static func _battle_candidates(candidates: Array) -> Array:
	var out: Array = []
	for event_v in candidates:
		if not event_v is Dictionary:
			continue
		var event := event_v as Dictionary
		if ExpeditionRulesServiceScript.is_battle_type(str(event.get("type", ""))):
			out.append(event)
	return out


static func _generated_battle_event_for_node(
		location: Dictionary,
		node: Dictionary,
		rng: RandomNumberGenerator
) -> Dictionary:
	var type_id := str(node.get("type", ""))
	if type_id not in [
		EnumExpeditionNodeTypeScript.ID_BATTLE,
		EnumExpeditionNodeTypeScript.ID_ELITE,
		EnumExpeditionNodeTypeScript.ID_BOSS,
	]:
		return {}
	var monster := _pick_location_monster_for_node(location, type_id, rng)
	if monster.is_empty():
		return {}
	var monster_id := str(monster.get("id", "")).strip_edges()
	if monster_id == "":
		return {}
	var difficulty := maxi(1, int(node.get("difficulty", location.get("min_difficulty", 1))))
	var event_type := "battle"
	if type_id == EnumExpeditionNodeTypeScript.ID_ELITE:
		event_type = "elite"
	elif type_id == EnumExpeditionNodeTypeScript.ID_BOSS:
		event_type = "boss"
	var location_id := str(location.get("id", location.get("location_id", ""))).strip_edges()
	var node_id := str(node.get("id", "node")).strip_edges()
	var event_id := "generated::%s::%s::%s::%s" % [location_id, node_id, event_type, monster_id]
	return {
		"id": event_id,
		"location_id": location_id,
		"type": event_type,
		"mode": "auto",
		"name": _generated_battle_name(event_type, monster),
		"desc": _generated_battle_desc(event_type, monster),
		"risk_text": str(node.get("risk_text", EnumExpeditionNodeTypeScript.label(type_id))),
		"weight": 1,
		"difficulty": difficulty,
		"enemy_pool": monster_id,
		"drop_pool": "monster:%s" % monster_id,
		"duration_days": 3 if event_type == "boss" else 2,
		"enemy_difficulty_scale": clampf(1.0 + float(difficulty - 1) * 0.12, 0.5, 2.5),
		"once_per_expedition": false,
		"tags": ["generated", event_type, "battle"],
		"conditions": [],
		"results": [{
			"type": "drop",
			"drop_pool": "monster:%s" % monster_id,
			"rolls": 4 if event_type == "boss" else (3 if event_type == "elite" else 2),
		}],
	}


static func _materialize_event_for_context(
		location: Dictionary,
		node: Dictionary,
		event: Dictionary,
		rng: RandomNumberGenerator
) -> Dictionary:
	var current := event.duplicate(true)
	var context := _event_context(location, node)
	current["difficulty"] = int(context.get("difficulty", 1))
	current["location_id"] = str(context.get("location_id", current.get("location_id", "")))
	current["node_type"] = str(context.get("node_type", current.get("node_type", "")))
	if ExpeditionRulesServiceScript.is_battle_type(str(current.get("type", ""))):
		current = _materialize_battle_event(location, node, current, rng)
	if not current.is_empty() and str(current.get("id", "")).strip_edges() != "":
		_store_generated_event(current)
	return current


static func _materialize_battle_event(
		location: Dictionary,
		node: Dictionary,
		event: Dictionary,
		rng: RandomNumberGenerator
) -> Dictionary:
	var type_id := str(node.get("type", EnumExpeditionNodeTypeScript.from_event(event)))
	var monster := _pick_location_monster_for_node(location, type_id, rng)
	if monster.is_empty():
		return event
	var monster_id := str(monster.get("id", "")).strip_edges()
	if monster_id == "":
		return event
	var difficulty := maxi(1, int(event.get("difficulty", node.get("difficulty", location.get("min_difficulty", 1)))))
	var event_type := str(event.get("type", "battle")).strip_edges()
	var current := event.duplicate(true)
	current["enemy_pool"] = monster_id
	current["drop_pool"] = "monster:%s" % monster_id
	current["enemy_difficulty_scale"] = clampf(1.0 + float(difficulty - 1) * 0.12, 0.5, 2.5)
	if not current.has("duration_days"):
		current["duration_days"] = 3 if event_type == "boss" else 2
	var default_rolls := 4 if event_type == "boss" else (3 if event_type == "elite" else 2)
	current["results"] = [{
		"type": "drop",
		"drop_pool": "monster:%s" % monster_id,
		"rolls": int(current.get("reward_rolls", default_rolls)),
	}]
	return current


static func _pick_location_monster_for_node(location: Dictionary, type_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var monsters := _location_monsters(str(location.get("id", location.get("location_id", ""))))
	if monsters.is_empty():
		return {}
	var preferred: Array = []
	for monster_v in monsters:
		if not monster_v is Dictionary:
			continue
		var monster := monster_v as Dictionary
		if _monster_matches_node_type(monster, type_id):
			preferred.append(monster)
	if preferred.is_empty():
		preferred = monsters
	return (preferred[rng.randi_range(0, preferred.size() - 1)] as Dictionary).duplicate(true)


static func _monster_matches_node_type(monster: Dictionary, type_id: String) -> bool:
	var species := str(monster.get("species", "")).strip_edges()
	var tags := monster.get("tags", []) as Array
	match type_id:
		EnumExpeditionNodeTypeScript.ID_BOSS:
			return species == "boss" or tags.has("boss")
		EnumExpeditionNodeTypeScript.ID_ELITE:
			return species == "elite" or tags.has("elite")
		_:
			return species not in ["elite", "boss"] and not tags.has("elite") and not tags.has("boss")


static func _generated_battle_name(event_type: String, monster: Dictionary) -> String:
	var monster_name := str(monster.get("name", "妖兽")).strip_edges()
	match event_type:
		"boss":
			return "%s现身" % monster_name
		"elite":
			return "%s拦路" % monster_name
		_:
			return "%s群袭" % monster_name


static func _generated_battle_desc(event_type: String, monster: Dictionary) -> String:
	var monster_name := str(monster.get("name", "妖兽")).strip_edges()
	match event_type:
		"boss":
			return "深处妖气翻涌，%s踏碎山石而来。" % monster_name
		"elite":
			return "山林忽然沉寂，%s循着你的气息逼近。" % monster_name
		_:
			return "草木摇动，%s自林间扑出，拦住去路。" % monster_name


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
			var location := _location_by_id(str(parent_event.get("location_id", "")))
			if not location.is_empty():
				triggered = _materialize_event_for_context(location, {}, _inherit_parent_difficulty(triggered, parent_event), rng)
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
			"location_id": str(parent_event.get("location_id", "")),
			"type": str(parent_event.get("type", "decision")),
			"difficulty": maxi(1, int(parent_event.get("difficulty", 1))),
			"duration_days": maxi(1, int(parent_event.get("duration_days", 1))),
			"results": option.get("results", []),
			"drop_pool": str(option.get("drop_pool", "")),
		},
		rng
	)
	var effect_lines := _apply_result_effects(option.get("results", []) as Array, option.get("effects", []) as Array, runtime, player_attrs)
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
			var effect_lines := _apply_result_effects(event.get("results", []) as Array, event.get("effects", []) as Array, runtime, player_attrs)
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
	if enemy.is_empty():
		var cm := _config_manager()
		if cm != null and cm.has_method("location_enemy_pool"):
			enemy = cm.call(
				"location_enemy_pool",
				str(event.get("location_id", "")),
				str(event.get("enemy_pool", ""))
			) as Dictionary
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
		out.append(_scale_enemy_for_difficulty_and_group(base, event, i, count))
	return out


static func build_enemy_formation(event: Dictionary, enemies: Array) -> Dictionary:
	if enemies.is_empty():
		return {}
	var formation := {
		"mode": EnumBattleFormationMode.LABEL_COLUMNS,
		"columns": 3,
		"rows": 5,
		"active_columns": 1,
	}
	var formation_type := str(event.get("node_type", event.get("type", ""))).strip_edges()
	match formation_type:
		"boss":
			formation["rank_size"] = 1
		"elite":
			formation["rank_size"] = 2
	return formation


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
	if attrs.has(FightAttr.MP_MAX):
		enemy["mp"] = float(attrs[FightAttr.MP_MAX])
	elif enemy.has("mp"):
		enemy["mp"] = float(enemy["mp"])
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
		return clampi(1 + int(floor(float(difficulty - 2) / 2.0)), 1, 3)
	return clampi(1 + int(floor(float(difficulty) / 2.0)), 1, 4)


static func _scale_enemy_for_difficulty_and_group(
		base: Dictionary,
		event: Dictionary,
		index: int,
		count: int
) -> Dictionary:
	var enemy := base.duplicate(true)
	var attrs := (enemy.get("attrs", {}) as Dictionary).duplicate(true)
	var difficulty_scale := _enemy_difficulty_scale(event)
	if attrs.has(FightAttr.HP_MAX):
		attrs[FightAttr.HP_MAX] = maxf(1.0, float(attrs[FightAttr.HP_MAX]) * difficulty_scale)
	for key in [FightAttr.PHYSICAL_ATK, FightAttr.MAGIC_ATK]:
		if attrs.has(key):
			attrs[key] = maxf(1.0, float(attrs[key]) * difficulty_scale)
	for key in [FightAttr.PHYSICAL_DEF, FightAttr.MAGIC_DEF]:
		if attrs.has(key):
			attrs[key] = maxf(0.0, float(attrs[key]) * (1.0 + (difficulty_scale - 1.0) * 0.65))
	if attrs.has(FightAttr.SPD):
		var offset := (float(index) - float(count - 1) * 0.5) * 3.0
		attrs[FightAttr.SPD] = maxf(1.0, float(attrs[FightAttr.SPD]) * (1.0 + (difficulty_scale - 1.0) * 0.35) + offset)
	enemy["attrs"] = attrs
	if attrs.has(FightAttr.HP_MAX):
		enemy["hp"] = float(attrs[FightAttr.HP_MAX])
	var skill_effect_scale := _enemy_skill_effect_scale(event)
	enemy["skills"] = _scale_enemy_skill_slots(enemy.get("skills", []), skill_effect_scale)
	var base_name := str(base.get("name", "敌人")).strip_edges()
	if count > 1:
		enemy["name"] = "%s·%d" % [base_name, index + 1]
	return enemy


static func _enemy_difficulty_scale(event: Dictionary) -> float:
	if event.has("enemy_difficulty_scale"):
		return clampf(float(event.get("enemy_difficulty_scale", 1.0)), 0.2, 5.0)
	var difficulty := maxi(1, int(event.get("difficulty", 1)))
	var location := _location_by_id(str(event.get("location_id", "")))
	var min_difficulty := maxi(1, int(location.get("min_difficulty", 1)))
	var steps := maxi(0, difficulty - min_difficulty)
	return clampf(1.0 + float(steps) * 0.12, 0.5, 2.5)


static func _enemy_skill_effect_scale(event: Dictionary) -> float:
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


static func _apply_result_effects(
		results: Array,
		fallback_effects: Array,
		runtime: Dictionary,
		player_attrs: Dictionary
) -> PackedStringArray:
	var effects: Array = []
	for result_v in results:
		if not result_v is Dictionary:
			continue
		var result := result_v as Dictionary
		if str(result.get("type", "")) == "effects":
			effects.append_array(result.get("effects", []) as Array)
	if effects.is_empty():
		effects = fallback_effects
	return _apply_effects(effects, runtime, player_attrs)


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


static func _filter_candidates(location: Dictionary, visited_once: Array, context: Dictionary = {}) -> Array:
	if context.is_empty():
		context = _event_context(location, {})
	var out: Array = []
	for event_v in event_pool_for_location(location):
		var event := event_v as Dictionary
		var event_id := str(event.get("id", ""))
		if bool(event.get("once_per_expedition", false)) and visited_once.has(event_id):
			continue
		var check_context := context.duplicate(true)
		check_context["location"] = location
		if not ConditionServiceScript.all_met(event.get("conditions", []) as Array, check_context):
			continue
		out.append(event)
	return out


static func _event_context(location: Dictionary, node: Dictionary) -> Dictionary:
	var difficulty := int(node.get("difficulty", location.get("min_difficulty", 1)))
	return {
		"difficulty": maxi(1, difficulty),
		"location_id": str(location.get("id", location.get("location_id", ""))),
		"node_type": str(node.get("type", "")),
	}


static func _inherit_parent_difficulty(event: Dictionary, parent_event: Dictionary) -> Dictionary:
	var current := event.duplicate(true)
	current["difficulty"] = maxi(1, int(parent_event.get("difficulty", current.get("difficulty", 1))))
	return current


static func _event_matches_node_type(event: Dictionary, type_id: String) -> bool:
	if type_id == EnumExpeditionNodeTypeScript.ID_DECISION:
		return is_decision_event(event)
	if is_decision_event(event):
		return false
	var event_type := str(event.get("type", "")).strip_edges()
	match type_id:
		EnumExpeditionNodeTypeScript.ID_GATHER:
			return event_type == "gather" and not bool(event.get("once_per_expedition", false))
		EnumExpeditionNodeTypeScript.ID_TREASURE:
			return event_type == "gather"
		EnumExpeditionNodeTypeScript.ID_RECOVER, EnumExpeditionNodeTypeScript.ID_REST:
			return event_type == "recover"
		EnumExpeditionNodeTypeScript.ID_HAZARD:
			return event_type == "hazard"
		EnumExpeditionNodeTypeScript.ID_BATTLE:
			return event_type == "battle"
		EnumExpeditionNodeTypeScript.ID_ELITE:
			return event_type == "elite"
		EnumExpeditionNodeTypeScript.ID_BOSS:
			return event_type == "boss"
		_:
			return event_type == "travel"


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


static func _generated_event_by_id(event_id: String) -> Dictionary:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return {}
	var data_store := (loop as SceneTree).root.get_node_or_null("DataStore")
	if data_store == null or not data_store.has_method("expedition_runtime"):
		return {}
	var runtime := data_store.call("expedition_runtime") as Dictionary
	var generated_v: Variant = runtime.get("generated_events", {})
	if not generated_v is Dictionary:
		return {}
	var event_v: Variant = (generated_v as Dictionary).get(event_id, {})
	if event_v is Dictionary:
		return (event_v as Dictionary).duplicate(true)
	return {}


static func _store_generated_event(event: Dictionary) -> void:
	var event_id := str(event.get("id", "")).strip_edges()
	if event_id == "":
		return
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return
	var data_store := (loop as SceneTree).root.get_node_or_null("DataStore")
	if data_store == null or not data_store.has_method("expedition_runtime"):
		return
	var runtime := data_store.call("expedition_runtime") as Dictionary
	if not bool(runtime.get("active", false)):
		return
	var generated_v: Variant = runtime.get("generated_events", {})
	var generated := generated_v as Dictionary if generated_v is Dictionary else {}
	generated[event_id] = event.duplicate(true)
	runtime["generated_events"] = generated


static func _location_monsters(location_id: String) -> Array:
	var cm := _config_manager()
	if cm != null and cm.has_method("location_monsters"):
		return cm.call("location_monsters", location_id) as Array
	return []


static func _location_by_id(location_id: String) -> Dictionary:
	var cm := _config_manager()
	if cm != null and cm.has_method("location_by_id"):
		return cm.call("location_by_id", location_id) as Dictionary
	return {}
