extends RefCounted
class_name BuffHoverTipBuilder

## 根据 Buff 配置构建 Hover Tip 载荷（仅静态配置，不含运行时层数/剩余时间）。

const BattleConfigQueryApplicationScript := preload(
	"res://scripts/features/battle/application/battle_config_query_application.gd"
)

const _COLOR_BUFF := Color(0.29803923, 0.4862745, 0.34509805, 1.0)
const _COLOR_DEBUFF := Color(0.76862746, 0.34901962, 0.31764707, 1.0)


static func build(buff_id: String, icon: Texture2D = null) -> Dictionary:
	var cfg := BattleConfigQueryApplicationScript.buff_by_id(buff_id)
	if cfg.is_empty():
		return {}
	var title := str(cfg.get("name", buff_id)).strip_edges()
	var lines: Array[String] = []
	var desc := str(cfg.get("desc", "")).strip_edges()
	if desc != "":
		lines.append(desc)
	var duration := float(cfg.get("duration", 0.0))
	if duration > 0.0:
		lines.append(StringsZh.format_template(
			StringsZh.getp("hover.buff.duration", "持续：{value}秒"),
			{"value": _fmt_duration(duration)}
		))
	var max_stacks := maxi(1, int(cfg.get("max_stacks", 1)))
	if max_stacks > 1:
		lines.append(StringsZh.format_template(
			StringsZh.getp("hover.buff.max_stacks", "最大层数：{value}"),
			{"value": str(max_stacks)}
		))
	var ticktime := float(cfg.get("ticktime", 0.0))
	var tick_effects_v: Variant = cfg.get("tick_effects", [])
	if ticktime > 0.0 and tick_effects_v is Array and not (tick_effects_v as Array).is_empty():
		lines.append(StringsZh.format_template(
			StringsZh.getp("hover.buff.ticktime", "周期：{value}秒"),
			{"value": _fmt_duration(ticktime)}
		))
	for mod_line in _format_modifier_lines(cfg.get("modifiers", {})):
		lines.append(mod_line)
	for tick_line in HoverTipEffectFormatter.format_lines(tick_effects_v):
		lines.append(tick_line)
	var tags_v: Variant = cfg.get("tags", [])
	if tags_v is Array and not (tags_v as Array).is_empty():
		var tag_text := ", ".join(_tag_labels(tags_v as Array))
		if tag_text != "":
			lines.append(StringsZh.format_template(
				StringsZh.getp("hover.buff.tags", "标签：{value}"),
				{"value": tag_text}
			))
	var payload_fields := {
		"title": title,
		"title_color": _title_color(tags_v),
		"lines": lines,
	}
	if icon != null:
		payload_fields["icon"] = icon
	elif cfg.has("icon"):
		var tex := ZhandouInitData._resolve_icon_texture(cfg)
		if tex != null:
			payload_fields["icon"] = tex
	return HoverTipPayload.make(payload_fields)


static func _title_color(tags_v: Variant) -> Color:
	if tags_v is Array:
		for tag_v in tags_v as Array:
			if str(tag_v).strip_edges().to_lower() == "debuff":
				return _COLOR_DEBUFF
	return _COLOR_BUFF


static func _format_modifier_lines(raw: Variant) -> Array[String]:
	var mods := BuffDef.normalize_modifiers(raw)
	var out: Array[String] = []
	for key in mods.keys():
		var attr_key := str(key).strip_edges()
		if attr_key == "":
			continue
		var delta := float(mods[attr_key])
		if is_equal_approx(delta, 0.0):
			continue
		var label := StringsZh.getp("hover.buff.attr.%s" % attr_key, attr_key)
		var sign_str := "+" if delta > 0.0 else ""
		out.append(StringsZh.format_template(
			StringsZh.getp("hover.buff.modifier", "{name} {sign}{value}"),
			{"name": label, "sign": sign_str, "value": _fmt_num(absf(delta))}
		))
	return out


static func _tag_labels(tags: Array) -> Array[String]:
	var out: Array[String] = []
	for tag_v in tags:
		var tag := str(tag_v).strip_edges().to_lower()
		if tag == "":
			continue
		out.append(StringsZh.getp("hover.buff.tag.%s" % tag, tag))
	return out


static func _fmt_duration(value: float) -> String:
	return "%0.1f" % maxf(0.0, value)


static func _fmt_num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%0.1f" % value
