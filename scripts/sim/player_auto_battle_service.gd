class_name PlayerAutoBattleService
extends RefCounted

const POLICY := "player_auto"
const VERSION := 2


static func default_settings() -> Dictionary:
	return {
		"global_cooldown_sec": 1.0,
		"duplicate_skill_policy": "highest_priority",
		"cast_range": "in_range",
		"auto_pill": true,
		"opening_buff": true,
	}


static func default_rules() -> Dictionary:
	return {
		"version": VERSION,
		"policy": POLICY,
		"strategies": [],
		"settings": default_settings(),
	}


static func normalize_rules(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return default_rules()
	var source := raw as Dictionary
	if source.is_empty():
		return default_rules()
	var policy := str(source.get("policy", "")).strip_edges().to_lower()
	if policy == POLICY:
		return {
			"version": VERSION,
			"policy": POLICY,
			"strategies": normalize_strategies(source.get("strategies", [])),
			"settings": normalize_settings(source.get("settings", {})),
		}
	return default_rules()


static func normalize_strategies(raw: Variant) -> Array:
	if not raw is Array:
		return []
	var out: Array = []
	for entry_v in raw as Array:
		if not entry_v is Dictionary:
			continue
		var entry := (entry_v as Dictionary).duplicate(true)
		if not entry.get("action", {}) is Dictionary:
			continue
		out.append(entry)
	return out


static func normalize_settings(raw: Variant) -> Dictionary:
	var out := default_settings()
	if not raw is Dictionary:
		return out
	var source := raw as Dictionary
	if source.has("global_cooldown_sec"):
		out["global_cooldown_sec"] = maxf(0.0, float(source["global_cooldown_sec"]))
	if source.has("duplicate_skill_policy"):
		out["duplicate_skill_policy"] = str(source["duplicate_skill_policy"])
	if source.has("cast_range"):
		out["cast_range"] = str(source["cast_range"])
	if source.has("auto_pill"):
		out["auto_pill"] = bool(source["auto_pill"])
	if source.has("opening_buff"):
		out["opening_buff"] = bool(source["opening_buff"])
	return out


static func with_strategies(strategies: Array, settings: Dictionary = {}) -> Dictionary:
	return with_config("balanced", strategies, settings)


static func with_config(preset: String, strategies: Array, settings: Dictionary = {}) -> Dictionary:
	return {
		"version": VERSION,
		"policy": POLICY,
		"preset": preset.strip_edges().to_lower(),
		"strategies": normalize_strategies(strategies),
		"settings": normalize_settings(settings),
	}


static func strategy_templates() -> Array:
	return [
		{
			"id": "low_hp_item",
			"label": "气血≤45% 使用道具1",
			"strategy": {
				"id": "low_hp_item",
				"when": {
					"self_hp_ratio_lte": 0.45,
					"item_count_gte": {"slot": 0, "count": 1},
				},
				"action": {"type": "item", "slot_index": 0},
			},
		},
	]


static func skill_strategy_template(skill_id: int, skill_name: String) -> Dictionary:
	var sid := maxi(0, skill_id)
	var name := skill_name.strip_edges()
	if name == "":
		name = "技能 %d" % sid
	return {
		"id": "skill_%d" % sid,
		"label": "%s 可用时优先施放" % name,
		"strategy": {
			"id": "skill_%d" % sid,
			"when": {"skill_ready": sid},
			"action": {"type": "skill", "skill_id": sid},
		},
	}


static func preset_description(preset: String) -> String:
	match preset.strip_edges().to_lower():
		"aggressive":
			return (
				"激进模式下的释放逻辑：\n"
				+ "为每个已装备技能添加「可用时施放」策略，尽可能高频输出。"
			)
		"conservative":
			return (
				"保守模式下的释放逻辑：\n"
				+ "低气血时优先使用道具，其余时候在技能可用时施放。"
			)
		_:
			return (
				"均衡模式下的释放逻辑：\n"
				+ "优先按技能槽顺位施放第一个可用技能；无自定义策略时自动调息。"
			)


static func build_preset_strategies(preset: String, equipped_skills: Array) -> Array:
	match preset.strip_edges().to_lower():
		"aggressive":
			return _skill_ready_strategies(equipped_skills)
		"conservative":
			var strategies := [strategy_templates()[0]["strategy"]]
			strategies.append_array(_skill_ready_strategies(equipped_skills))
			return strategies
		_:
			return []


static func strategy_target_label(strategy: Dictionary) -> String:
	var action := strategy.get("action", {}) as Dictionary
	match str(action.get("type", "")):
		"skill":
			var skill := _skill_row(int(action.get("skill_id", -1)))
			if _skill_targets_self(skill):
				return "自己"
			return "当前敌人"
		"item", "equip":
			return "自己"
		"basic":
			return "当前敌人"
		_:
			return "—"


static func strategy_condition_label(strategy: Dictionary) -> String:
	var when := strategy.get("when", {}) as Dictionary
	if when.is_empty():
		return "始终释放"
	return _when_label(when)


static func strategy_info_text(strategy: Dictionary) -> String:
	var action := strategy.get("action", {}) as Dictionary
	match str(action.get("type", "")):
		"skill":
			var skill := _skill_row(int(action.get("skill_id", -1)))
			return "%s    %s\n%s" % [
				str(skill.get("name", "技能")),
				_skill_category_label(skill),
				_skill_summary(skill),
			]
		"item":
			return "战斗道具    辅助\n按条件自动使用背包道具。"
		"equip":
			return "法宝    辅助\n按条件自动使用法宝。"
		"basic", "tiaoxi":
			return "调息    辅助\n盘膝调息，按法力恢复速度恢复灵力。"
		_:
			return "未知策略\n请重新配置。"


static func setting_display(setting_key: String, value: Variant) -> String:
	match setting_key:
		"global_cooldown_sec":
			return "%.1f 秒" % float(value)
		"duplicate_skill_policy":
			return "最高优先级" if str(value) == "highest_priority" else "跳过低优先级"
		"cast_range":
			return "攻击范围内" if str(value) == "in_range" else "无视距离"
		"auto_pill", "opening_buff":
			return "开启" if bool(value) else "关闭"
		_:
			return str(value)


static func cycle_setting(setting_key: String, current: Variant) -> Variant:
	match setting_key:
		"global_cooldown_sec":
			var options := [0.5, 1.0, 1.5, 2.0]
			var idx := options.find(float(current))
			return options[(idx + 1) % options.size()]
		"duplicate_skill_policy":
			return "skip_duplicate" if str(current) == "highest_priority" else "highest_priority"
		"cast_range":
			return "any" if str(current) == "in_range" else "in_range"
		"auto_pill", "opening_buff":
			return not bool(current)
		_:
			return current


static func strategy_label(strategy: Dictionary) -> String:
	var action := strategy.get("action", {}) as Dictionary
	var when := strategy.get("when", {}) as Dictionary
	var action_text := _action_label(action)
	if when.is_empty():
		return action_text
	return "%s → %s" % [_when_label(when), action_text]


static func _when_label(when: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if when.has("self_hp_ratio_lte"):
		parts.append("气血≤%.0f%%" % (float(when["self_hp_ratio_lte"]) * 100.0))
	if when.has("self_hp_ratio_gte"):
		parts.append("气血≥%.0f%%" % (float(when["self_hp_ratio_gte"]) * 100.0))
	if when.has("self_mp_gte"):
		parts.append("法力≥%.0f" % float(when["self_mp_gte"]))
	if when.has("skill_ready"):
		parts.append("技能%d可用" % int(when["skill_ready"]))
	if when.has("item_count_gte"):
		var spec := when["item_count_gte"] as Dictionary
		parts.append("道具%d≥%d" % [int(spec.get("slot", 0)) + 1, int(spec.get("count", 1))])
	if parts.is_empty():
		return "任意时机"
	return "且".join(parts)


static func _skill_ready_strategies(equipped_skills: Array) -> Array:
	var out: Array = []
	for sid_v in equipped_skills:
		var sid := int(sid_v)
		if sid <= 0:
			continue
		var skill := _skill_row(sid)
		out.append(skill_strategy_template(sid, str(skill.get("name", "")))["strategy"])
	return out


static func _skill_row(skill_id: int) -> Dictionary:
	var cm := _config_manager()
	if cm != null and cm.has_method("skill_by_id"):
		return cm.call("skill_by_id", skill_id) as Dictionary
	return {}


static func _config_manager() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("ConfigManager")
	return null


static func _skill_category_label(skill: Dictionary) -> String:
	var tags := skill.get("tags", []) as Array
	if tags.has("attack") or tags.has("fire") or tags.has("poison"):
		return "攻击"
	if tags.has("shield"):
		return "防御"
	if tags.has("movement"):
		return "身法"
	return "辅助"


static func _skill_summary(skill: Dictionary) -> String:
	if skill.is_empty():
		return "未配置技能。"
	var desc := str(skill.get("desc", "")).strip_edges()
	if desc != "":
		return desc
	var effects := skill.get("effects", []) as Array
	if effects.is_empty():
		return "基础战斗行动。"
	match str((effects[0] as Dictionary).get("type", "")):
		"damage": return "对敌人造成伤害。"
		"shield": return "为自身提供护盾。"
		"heal": return "恢复自身气血。"
		"restore_mp": return "恢复自身法力。"
		_: return "提供战斗辅助效果。"


static func _skill_targets_self(skill: Dictionary) -> bool:
	var effects := skill.get("effects", []) as Array
	for effect_v in effects:
		if not effect_v is Dictionary:
			continue
		if str((effect_v as Dictionary).get("target", "")) == "self":
			return true
	return false


static func _action_label(action: Dictionary) -> String:
	match str(action.get("type", "")):
		"skill":
			return "施放技能 %d" % int(action.get("skill_id", -1))
		"item":
			return "使用道具 %d" % (int(action.get("slot_index", 0)) + 1)
		"equip":
			return "使用法宝 %d" % (int(action.get("slot_index", 0)) + 1)
		"basic", "tiaoxi":
			return "调息"
		_:
			return "未知行动"
