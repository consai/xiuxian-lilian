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
		"timed_modifier":
			return _format_timed_modifier_effect(effect, target_label)
		"control":
			return _format_control_effect(effect, target_label)
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
		"enemy_lowest_hp":
			return "低血敌人"
		"ally":
			return StringsZh.getp("hover.target.ally", "友方")
		"position":
			return "位置"
		"area":
			return "区域"
		"allies":
			return "友方全体"
		"world":
			return "世界"
		"controlled_entity":
			return "控制对象"
		_:
			return StringsZh.getp("hover.target.default", "目标")


static func format_raw_ability_lines(effects_v: Variant, knowledge_mastery: float = 0.0) -> Array[String]:
	var out: Array[String] = []
	if not effects_v is Array:
		return out
	for eff_v in effects_v as Array:
		if not eff_v is Dictionary:
			continue
		var line := _format_raw_ability_effect(eff_v as Dictionary, knowledge_mastery)
		if line != "":
			out.append(line)
	return out


static func _format_raw_ability_effect(effect: Dictionary, knowledge_mastery: float) -> String:
	var effect_id := str(effect.get("effectId", "")).strip_edges()
	if effect_id == "":
		return ""
	var base := float(effect.get("base", 0.0))
	var growth := float(effect.get("knowledgeGrowth", effect.get("masteryGrowth", 0.0)))
	var value := base + growth * clampf(knowledge_mastery, 0.0, 1.0)
	var operation := str(effect.get("operation", "add_flat"))
	var attrs: Dictionary = effect.get("attributes", {}) as Dictionary
	var target := _target_label(str(effect.get("target", attrs.get("target", ""))))
	var value_text := _fmt_effect_value(value, operation)
	var label := _effect_id_label(effect_id)
	return "%s：%s %s" % [target, label, value_text]


static func _format_timed_modifier_effect(effect: Dictionary, target_label: String) -> String:
	var name := str(effect.get("name", "临时加成")).strip_edges()
	var duration := float(effect.get("duration", 0.0))
	var parts: PackedStringArray = []
	var modifiers_v: Variant = effect.get("modifiers", {})
	if modifiers_v is Dictionary:
		for key in (modifiers_v as Dictionary).keys():
			parts.append("%s %s" % [_attr_label(str(key)), _signed_num(float((modifiers_v as Dictionary)[key]))])
	var percent_v: Variant = effect.get("percent_modifiers", {})
	if percent_v is Dictionary:
		for key in (percent_v as Dictionary).keys():
			parts.append("%s %s" % [_attr_label(str(key)), _signed_percent(float((percent_v as Dictionary)[key]))])
	var effect_text := "、".join(parts) if not parts.is_empty() else "临时状态"
	if duration > 0.0:
		return "对%s施加 %s：%s，持续 %s 秒" % [target_label, name, effect_text, _fmt_num(duration)]
	return "对%s施加 %s：%s" % [target_label, name, effect_text]


static func _format_control_effect(effect: Dictionary, target_label: String) -> String:
	var name := str(effect.get("name", "控制")).strip_edges()
	var duration := float(effect.get("duration", 0.0))
	var chance := float(effect.get("control_chance", 0.0))
	var line := "对%s施加 %s" % [target_label, name]
	if duration > 0.0:
		line += " %s 秒" % _fmt_num(duration)
	if chance > 0.0:
		line += "（基础成功率 %d%%）" % int(roundf(chance * 100.0))
	return line


static func _fmt_num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%0.1f" % value


static func _fmt_effect_value(value: float, operation: String) -> String:
	if operation == "add_percent":
		return _signed_percent(value)
	return _signed_num(value)


static func _signed_num(value: float) -> String:
	var prefix := "+" if value >= 0.0 else ""
	return "%s%s" % [prefix, _fmt_num(value)]


static func _signed_percent(value: float) -> String:
	var prefix := "+" if value >= 0.0 else ""
	return "%s%s%%" % [prefix, _fmt_num(value * 100.0)]


static func _effect_id_label(effect_id: String) -> String:
	var labels := {
		"damage_spiritual": "灵力伤害",
		"damage_sword": "剑气伤害",
		"damage_sword_area": "剑阵伤害",
		"damage_elemental": "五行伤害",
		"damage_physical": "物理伤害",
		"damage_physical_area": "范围物理伤害",
		"damage_thunder": "雷法伤害",
		"damage_spirit": "神魂伤害",
		"damage_spirit_sword": "神魂剑伤",
		"damage_void": "虚空伤害",
		"damage_law": "法则伤害",
		"damage_law_area": "范围法则伤害",
		"damage_tribulation": "劫雷伤害",
		"damage_true": "真实伤害",
		"shield_flat": "护盾",
		"shield_spiritual": "灵力护盾",
		"heal_hp": "气血恢复",
		"restore_mana": "法力恢复",
		"mana_regen": "法力回复",
		"activation_speed": "激活速度",
		"cast_speed": "施法速度",
		"cultivation_speed": "修炼速度",
		"formation_setup_speed": "布阵速度",
		"gather_speed": "采集速度",
		"regeneration_speed": "再生速度",
		"sword_attack_speed": "剑道攻速",
		"talisman_activation_speed": "符箓激活速度",
		"void_travel_speed": "虚空遁行速度",
		"max_mana": "法力上限",
		"max_hp": "气血上限",
		"max_health": "气血上限",
		"physical_attack": "物理攻击",
		"magic_attack": "法术攻击",
		"physical_defense": "物理防御",
		"magic_defense": "法术防御",
		"evasion": "闪避",
		"accuracy": "命中",
		"damage_bonus": "伤害加成",
		"armor_pierce": "护甲穿透",
		"space_pierce": "空间穿透",
		"law_pierce": "法则穿透",
		"dash_distance": "位移距离",
		"evasion_window": "闪避窗口",
		"array_duration": "阵法持续",
		"control_duration": "控制时长",
		"stun_chance": "麻痹概率",
		"delay_special_action_chance": "延缓特殊行动概率",
	}
	if labels.has(effect_id):
		return str(labels[effect_id])
	return _humanize_effect_id(effect_id)


static func _humanize_effect_id(effect_id: String) -> String:
	var token_labels := {
		"activation": "激活",
		"alchemy": "炼丹",
		"all": "全",
		"ambient": "环境",
		"appraisal": "鉴定",
		"artifact": "法宝",
		"ascension": "飞升",
		"beast": "灵兽",
		"bloodline": "血脉",
		"body": "体魄",
		"breakthrough": "突破",
		"cast": "施法",
		"causality": "因果",
		"cave": "洞天",
		"chance": "概率",
		"compatibility": "契合",
		"control": "控制",
		"contract": "契约",
		"conversion": "转化",
		"craft": "炼制",
		"critical": "暴击",
		"cultivation": "修炼",
		"curse": "咒法",
		"damage": "伤害",
		"danger": "危险",
		"dao": "大道",
		"decree": "律令",
		"detection": "探查",
		"deviation": "走火",
		"dharma": "法相",
		"domain": "领域",
		"dream": "梦境",
		"efficiency": "效率",
		"element": "五行",
		"elemental": "元素",
		"enemy": "敌方",
		"energy": "能量",
		"environment": "环境",
		"escape": "脱离",
		"evasion": "闪避",
		"evil": "破邪",
		"expedition": "探险",
		"exploration": "探索",
		"fatal": "濒死",
		"find": "发现",
		"forecast": "预报",
		"formation": "阵法",
		"gather": "采集",
		"governance": "治理",
		"growth": "成长",
		"healing": "治疗",
		"health": "气血",
		"heart": "心境",
		"herb": "灵植",
		"hostile": "敌性",
		"immortal": "仙灵",
		"infiltration": "渗透",
		"injury": "伤势",
		"inner": "内在",
		"inscription": "铭刻",
		"karma": "业力",
		"law": "法则",
		"life": "生命",
		"lifespan": "寿元",
		"lightning": "雷链",
		"low": "低血",
		"mana": "法力",
		"material": "材料",
		"medicine": "药性",
		"melee": "近战",
		"mental": "心神",
		"mind": "心神",
		"mobility": "机动",
		"output": "产出",
		"parallel": "并行",
		"physical": "物理",
		"pill": "丹药",
		"plan": "规划",
		"poison": "毒",
		"power": "威力",
		"profit": "收益",
		"puppet": "傀儡",
		"quality": "品质",
		"rare": "稀有",
		"recovery": "恢复",
		"regen": "回复",
		"regeneration": "再生",
		"resistance": "抗性",
		"resource": "资源",
		"resurrection": "复生",
		"route": "路线",
		"safety": "安全",
		"seal": "封印",
		"settlement": "聚落",
		"ship": "飞舟",
		"soul": "神魂",
		"space": "空间",
		"spell": "术法",
		"spirit": "神识",
		"spiritual": "灵力",
		"stability": "稳定",
		"stamina": "体力",
		"star": "星辰",
		"success": "成功",
		"suppression": "压制",
		"survival": "生存",
		"sustained": "持续",
		"sword": "剑道",
		"sync": "同步",
		"talisman": "符箓",
		"teleport": "传送",
		"thunder": "雷法",
		"trade": "交易",
		"travel": "旅行",
		"tribulation": "天劫",
		"true": "真实",
		"void": "虚空",
		"warning": "预警",
		"weapon": "兵器",
		"weather": "天象",
		"weakness": "弱点",
		"world": "世界",
		"yield": "产量",
		"speed": "速度",
	}
	var out: PackedStringArray = []
	for token in effect_id.split("_"):
		var clean := str(token).strip_edges()
		if clean == "":
			continue
		out.append(str(token_labels.get(clean, clean)))
	return "".join(out) if not out.is_empty() else effect_id


static func _effect_value_label(effect: Dictionary, value: float) -> String:
	var parts: PackedStringArray = [_fmt_num(value)]
	var scaling_v: Variant = effect.get("scaling", {})
	if scaling_v is Dictionary:
		for key in (scaling_v as Dictionary).keys():
			parts.append("%s×%s" % [
				_attr_label(str(key)),
				_fmt_num(float((scaling_v as Dictionary)[key])),
			])
	if effect.has("armor_pierce"):
		parts.append("穿透 %s%%" % _fmt_num(float(effect.get("armor_pierce", 0.0)) * 100.0))
	return " + ".join(parts)


static func _attr_label(key: String) -> String:
	var labels := {
		FightAttr.PHYSICAL_ATK: "物攻",
		FightAttr.MAGIC_ATK: "法攻",
		FightAttr.PHYSICAL_DEF: "物防",
		FightAttr.MAGIC_DEF: "法防",
		FightAttr.ACCURACY: "命中",
		FightAttr.EVASION: "闪避",
		FightAttr.SPD: "速度",
		FightAttr.HP_MAX: "气血上限",
		FightAttr.MP_MAX: "法力上限",
		FightAttr.SHIELD: "护盾",
		FightAttr.CRIT: "暴击",
		FightAttr.CRIT_DAMAGE: "暴伤",
		FightAttr.CONTROL_POWER: "控制",
		FightAttr.CONTROL_RESIST: "控制抵抗",
		FightAttr.HP_REGEN: "气血回复",
		FightAttr.MP_REGEN: "法力回复",
		FightAttr.CARRY: "携带",
		FightAttr.DAMAGE_BONUS: "伤害加成",
		FightAttr.DAMAGE_TAKEN: "承伤",
		FightAttr.COMBAT_MP_RESTORE_2S: "战斗回蓝",
	}
	return str(labels.get(key, key))
