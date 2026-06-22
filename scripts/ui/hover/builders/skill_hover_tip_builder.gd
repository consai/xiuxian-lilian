extends RefCounted
class_name SkillHoverTipBuilder

## 根据技能配置构建 Hover Tip 载荷。

const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")


static func build(skill_id: int, icon: Texture2D = null) -> Dictionary:
	var cfg := ConfigManager.skill_by_id(skill_id)
	if cfg.is_empty():
		return {}
	return build_from_runtime(cfg, icon)


static func build_from_runtime(cfg: Dictionary, icon: Texture2D = null) -> Dictionary:
	var title := str(cfg.get("name", "")).strip_edges()
	if title == "":
		title = "技能"
	var quality := maxi(1, int(cfg.get("quality", 1)))
	var lines: Array[String] = []
	var desc := str(cfg.get("desc", cfg.get("description", ""))).strip_edges()
	if desc != "":
		lines.append(desc)
	var cost_text := str(cfg.get("cost_text", "")).strip_edges()
	if cost_text != "":
		lines.append("消耗：%s" % cost_text)
	else:
		var mp_cost := float(cfg.get("mp_cost", 0.0))
		if mp_cost > 0.0:
			lines.append(StringsZh.format_template(
				StringsZh.getp("hover.skill.mp_cost", "法力消耗：{value}"),
				{"value": _fmt_num(mp_cost)}
			))
	var cd := float(cfg.get("cd", cfg.get("cd_total", 0.0)))
	if cd > 0.0:
		lines.append(StringsZh.format_template(
			StringsZh.getp("hover.skill.cd", "冷却：{value}秒"),
			{"value": _fmt_num(cd)}
		))
	var power := float(cfg.get("power", 0.0))
	if power > 0.0 and int(cfg.get("id", -1)) != 0:
		lines.append(StringsZh.format_template(
			StringsZh.getp("hover.skill.power", "威力：{value}"),
			{"value": _fmt_num(power)}
		))
	for effect_line in HoverTipEffectFormatter.format_lines(cfg.get("effects", [])):
		lines.append(effect_line)
	var tags_v: Variant = cfg.get("tags", [])
	if tags_v is Array and not (tags_v as Array).is_empty():
		var tag_text := ", ".join(_tag_labels(tags_v as Array))
		if tag_text != "":
			lines.append(StringsZh.format_template(
				StringsZh.getp("hover.skill.tags", "标签：{value}"),
				{"value": tag_text}
			))
	var payload_fields := {
		"title": title,
		"title_color": EnumQuality.get_color(quality),
		"lines": lines,
	}
	if icon != null:
		payload_fields["icon"] = icon
	elif cfg.has("icon"):
		var tex := BattleInitData._resolve_icon_texture(cfg)
		if tex != null:
			payload_fields["icon"] = tex
	return HoverTipPayload.make(payload_fields)


static func build_ability(ability_id: String, savedata: Dictionary, icon: Texture2D = null) -> Dictionary:
	var ability := AbilityService.by_id(ability_id)
	if ability.is_empty():
		return {}
	var runtime := AbilityService.to_runtime_dict(ability_id, savedata)
	var title := str(ability.get("name", ability_id)).strip_edges()
	var quality := clampi(int(ability.get("quality", 1)), EnumQuality.Type.LOW, EnumQuality.Type.SUPREME)
	var tier := EnumItemTier.clamp_tier(int(ability.get("tier", 1)))
	var mastery := AbilityService.knowledge_mastery_ratio(ability_id, savedata)
	var lines: Array[String] = []
	var desc := str(ability.get("description", "")).strip_edges()
	if desc != "":
		lines.append(desc)
	lines.append("类型：%s" % ability_type_label(str(ability.get("type", ""))))
	var realm := str(ability.get("realm", "")).strip_edges()
	if realm != "":
		lines.append("境界：%s" % DaoTreeServiceScript.realm_display_name(realm))
	lines.append("阶位：%s" % EnumItemTier.label(tier))
	lines.append("品质：%s" % EnumQuality.display_label(quality))
	var combat_v: Variant = ability.get("combat", {})
	if combat_v is Dictionary:
		var combat := combat_v as Dictionary
		var cost_text := _format_cost_text(combat.get("costs", []))
		if cost_text != "":
			lines.append("消耗：%s" % cost_text)
		var upkeep_text := _format_cost_text(combat.get("upkeepCostsPerSecond", []))
		if upkeep_text != "":
			lines.append("维持：%s/秒" % upkeep_text)
		var cooldown := float(combat.get("cooldown", 0.0))
		if cooldown > 0.0:
			lines.append("冷却：%s秒" % _fmt_num(cooldown))
		var cast_time := float(combat.get("castTime", 0.0))
		if cast_time > 0.0:
			lines.append("施放：%s秒" % _fmt_num(cast_time))
	if mastery > 0.0:
		lines.append("知识加成：%.0f%%" % (mastery * 100.0))
	var effect_lines := HoverTipEffectFormatter.format_lines(runtime.get("effects", []))
	if effect_lines.is_empty():
		effect_lines = HoverTipEffectFormatter.format_raw_ability_lines(ability.get("effects", []), mastery)
	for effect_line in effect_lines:
		lines.append(effect_line)
	var tags_v: Variant = ability.get("tags", [])
	if tags_v is Array and not (tags_v as Array).is_empty():
		var tag_text := ", ".join(_tag_labels(tags_v as Array))
		if tag_text != "":
			lines.append(StringsZh.format_template(
				StringsZh.getp("hover.skill.tags", "标签：{value}"),
				{"value": tag_text}
			))
	var payload_fields := {
		"title": title,
		"title_color": EnumQuality.get_color(quality),
		"lines": lines,
	}
	if icon != null:
		payload_fields["icon"] = icon
	elif not runtime.is_empty() and runtime.has("icon"):
		var tex := BattleInitData._resolve_icon_texture(runtime)
		if tex != null:
			payload_fields["icon"] = tex
	return HoverTipPayload.make(payload_fields)


static func ability_type_label(type_name: String) -> String:
	match type_name:
		"combat_active":
			return "主动"
		"combat_upkeep":
			return "持续"
		"combat_passive":
			return "战斗被动"
		"general_passive":
			return "通用被动"
		_:
			return "技能"


static func _tag_labels(tags: Array) -> Array[String]:
	var out: Array[String] = []
	for tag_v in tags:
		var tag := str(tag_v).strip_edges().to_lower()
		if tag == "":
			continue
		var label := StringsZh.getp("hover.skill.tag.%s" % tag, tag)
		if label == tag:
			label = _tag_label(tag)
		out.append(label)
	return out


static func _format_cost_text(costs_v: Variant) -> String:
	if not costs_v is Array:
		return ""
	var labels: PackedStringArray = []
	for cost_v in costs_v as Array:
		if not cost_v is Dictionary:
			continue
		var cost := cost_v as Dictionary
		var value := float(cost.get("value", 0.0))
		if value <= 0.0:
			continue
		labels.append("%s %s" % [
			_resource_label(str(cost.get("resource", "mana"))),
			_fmt_num(value),
		])
	return "、".join(labels)


static func _resource_label(resource: String) -> String:
	match resource.strip_edges().to_lower():
		"stamina":
			return "体力"
		"spirit":
			return "神魂"
		_:
			return "法力"


static func _tag_label(tag: String) -> String:
	var labels := {
		"attack": "攻击",
		"defense": "防御",
		"support": "辅助",
		"physical": "物理",
		"spell": "术法",
		"ranged": "远程",
		"filler": "填充",
		"mobility": "身法",
		"sword": "剑道",
		"execute": "斩杀",
		"body": "炼体",
		"burst": "爆发",
		"elemental": "五行",
		"control": "控制",
		"thunder": "雷法",
		"soul": "神魂",
		"law": "法则",
		"void": "虚空",
		"domain": "领域",
		"upkeep": "持续",
		"passive": "被动",
		"general": "通用",
		"heal": "治疗",
		"restore": "恢复",
		"shield": "护盾",
		"poison": "毒",
		"fire": "火系",
	}
	return str(labels.get(tag, tag))


static func _fmt_num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%0.1f" % value
