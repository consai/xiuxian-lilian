extends RefCounted
class_name HoverTipEffectFormatter

## 战斗效果行文案格式化，供技能/道具/法宝 hover tip 共用。


static func format_lines(effects_v: Variant) -> Array[String]:
	var out: Array[String] = []
	if not effects_v is Array:
		return out
	for eff_v in effects_v as Array:
		if not eff_v is Dictionary:
			continue
		var line := format_one(eff_v as Dictionary)
		if line != "":
			out.append(line)
	return out


static func format_one(effect: Dictionary) -> String:
	var type_name := str(effect.get("type", "")).strip_edges().to_lower()
	var value := float(effect.get("value", 0.0))
	var value_label := _effect_value_label(effect, value)
	var target_key := str(effect.get("target", "")).strip_edges().to_lower()
	var target_label := _target_label(target_key)
	if type_name in ["damage", "heal", "shield", "restore_mp"] and value <= 0.0:
		return ""
	match type_name:
		"damage":
			return StringsZh.format_template(
				StringsZh.getp("hover.skill.effect_damage", "对{target}造成伤害 {value}"),
				{"target": target_label, "value": value_label}
			)
		"heal":
			return StringsZh.format_template(
				StringsZh.getp("hover.skill.effect_heal", "为{target}恢复 {value} 生命"),
				{"target": target_label, "value": value_label}
			)
		"shield":
			return StringsZh.format_template(
				StringsZh.getp("hover.skill.effect_shield", "为{target}获得护盾 {value}"),
				{"target": target_label, "value": value_label}
			)
		"restore_mp":
			return StringsZh.format_template(
				StringsZh.getp("hover.item.effect_restore_mp", "为{target}恢复 {value} 法力"),
				{"target": target_label, "value": value_label}
			)
		"buff":
			return _format_buff_effect(effect, target_label)
		_:
			if type_name != "" and value != 0.0:
				return "%s %s" % [type_name, _fmt_num(value)]
			return ""


static func _format_buff_effect(effect: Dictionary, target_label: String) -> String:
	var modifiers_v: Variant = effect.get("modifiers", {})
	if modifiers_v is Dictionary:
		var mods := modifiers_v as Dictionary
		for buff_key in mods.keys():
			var buff_id := str(buff_key).strip_edges()
			if buff_id == "":
				continue
			var buff_cfg := ConfigManager.buff_by_id(buff_id)
			var buff_name := str(buff_cfg.get("name", buff_id)).strip_edges()
			var line := StringsZh.format_template(
				StringsZh.getp("hover.skill.effect_buff", "对{target}施加 {name}"),
				{"target": target_label, "name": buff_name}
			)
			if effect.has("control_chance"):
				line += "（基础成功率 %d%%，受神识影响）" % int(
					roundf(float(effect.get("control_chance", 1.0)) * 100.0)
				)
			return line
	return StringsZh.format_template(
		StringsZh.getp("hover.skill.effect_buff_plain", "对{target}施加状态"),
		{"target": target_label}
	)


static func _target_label(target_key: String) -> String:
	match target_key:
		"self":
			return StringsZh.getp("hover.target.self", "自身")
		"enemy":
			return StringsZh.getp("hover.target.enemy", "敌人")
		"ally":
			return StringsZh.getp("hover.target.ally", "友方")
		_:
			return StringsZh.getp("hover.target.default", "目标")


static func _fmt_num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%0.1f" % value


static func _effect_value_label(effect: Dictionary, value: float) -> String:
	var parts: PackedStringArray = [_fmt_num(value)]
	var scaling_v: Variant = effect.get("scaling", {})
	if scaling_v is Dictionary:
		for key in (scaling_v as Dictionary).keys():
			parts.append("%s×%s" % [
				_attr_label(str(key)),
				_fmt_num(float((scaling_v as Dictionary)[key])),
			])
	return " + ".join(parts)


static func _attr_label(key: String) -> String:
	var labels := {
		FightAttr.PHYSICAL_ATK: "物攻",
		FightAttr.MAGIC_ATK: "法攻",
		FightAttr.PHYSICAL_DEF: "物防",
		FightAttr.MAGIC_DEF: "法防",
		FightAttr.CONTROL_POWER: "控制",
	}
	return str(labels.get(key, key))
