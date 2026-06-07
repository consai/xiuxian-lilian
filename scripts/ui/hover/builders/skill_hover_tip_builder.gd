extends RefCounted
class_name SkillHoverTipBuilder

## 根据技能配置构建 Hover Tip 载荷。


static func build(skill_id: int, icon: Texture2D = null) -> Dictionary:
	var cfg := ConfigManager.skill_by_id(skill_id)
	if cfg.is_empty():
		return {}
	var title := str(cfg.get("name", "")).strip_edges()
	if title == "":
		title = "技能 %d" % skill_id
	var quality := maxi(1, int(cfg.get("quality", 1)))
	var lines: Array[String] = []
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
	if power > 0.0 and skill_id != 0:
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


static func _tag_labels(tags: Array) -> Array[String]:
	var out: Array[String] = []
	for tag_v in tags:
		var tag := str(tag_v).strip_edges().to_lower()
		if tag == "":
			continue
		var label := StringsZh.getp("hover.skill.tag.%s" % tag, tag)
		out.append(label)
	return out


static func _fmt_num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%0.1f" % value
