extends RefCounted
class_name ItemHoverTipBuilder

## 根据战斗道具配置（fight_id）构建 Hover Tip 载荷。


static func build(fight_item_id: int, icon: Texture2D = null, count: int = -1) -> Dictionary:
	var cfg := ConfigManager.item_by_fight_id(fight_item_id)
	if cfg.is_empty():
		return {}
	var def := ConfigManager.item_def_by_fight_id(fight_item_id)
	var title := str(cfg.get("name", "")).strip_edges()
	if title == "" and def != null:
		title = def.name
	if title == "":
		title = "道具 %d" % fight_item_id
	var quality := maxi(1, int(cfg.get("quality", 1)))
	if def != null:
		quality = maxi(1, def.quality)
	var lines: Array[String] = []
	if def != null:
		var desc := def.desc.strip_edges()
		if desc != "":
			lines.append(desc)
	var mp_cost := float(cfg.get("mp_cost", 0.0))
	if mp_cost > 0.0:
		lines.append(StringsZh.format_template(
			StringsZh.getp("hover.skill.mp_cost", "法力消耗：{value}"),
			{"value": _fmt(mp_cost)}
		))
	var cd := float(cfg.get("cd", cfg.get("cd_total", 0.0)))
	if cd > 0.0:
		lines.append(StringsZh.format_template(
			StringsZh.getp("hover.skill.cd", "冷却：{value}秒"),
			{"value": _fmt(cd)}
		))
	for effect_line in HoverTipEffectFormatter.format_lines(cfg.get("effects", [])):
		lines.append(effect_line)
	var payload_fields := {
		"title": title,
		"title_color": EnumQuality.get_color(quality),
		"lines": lines,
	}
	if count >= 0:
		payload_fields["footer"] = StringsZh.format_template(
			StringsZh.getp("hover.item.count", "数量：{value}"),
			{"value": str(maxi(0, count))}
		)
	if icon != null:
		payload_fields["icon"] = icon
	else:
		var tex := ZhandouInitData._resolve_icon_texture(cfg)
		if tex != null:
			payload_fields["icon"] = tex
	return HoverTipPayload.make(payload_fields)


static func _fmt(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%0.1f" % value
