extends RefCounted
class_name EquipHoverTipBuilder

## 根据法宝配置构建 Hover Tip 载荷。


static func build(
	equip_id: int,
	icon: Texture2D = null,
	slot_effects: Variant = null
) -> Dictionary:
	var cfg := ConfigManager.equip_by_id(equip_id)
	if cfg.is_empty():
		return {}
	var title := str(cfg.get("name", "")).strip_edges()
	if title == "":
		title = "法宝 %d" % equip_id
	var quality := maxi(1, int(cfg.get("quality", 1)))
	var lines: Array[String] = []
	lines.append(StringsZh.getp("hover.equip.kind", "战斗法宝"))
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
	var effects_v: Variant = slot_effects
	if effects_v == null or (effects_v is Array and (effects_v as Array).is_empty()):
		effects_v = cfg.get("effects", [])
	for effect_line in HoverTipEffectFormatter.format_lines(effects_v):
		lines.append(effect_line)
	var payload_fields := {
		"title": title,
		"title_color": EnumQuality.get_color(quality),
		"lines": lines,
	}
	if icon != null:
		payload_fields["icon"] = icon
	else:
		var tex := BattleInitData._resolve_icon_texture(cfg)
		if tex != null:
			payload_fields["icon"] = tex
	return HoverTipPayload.make(payload_fields)


static func _fmt(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%0.1f" % value
