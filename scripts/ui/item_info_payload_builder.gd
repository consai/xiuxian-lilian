class_name ItemInfoPayloadBuilder
extends RefCounted

const BattleInitDataScript := preload("res://scripts/fight/battle_init_data.gd")
const ItemDefScript := preload("res://scripts/core/item_def.gd")


static func is_empty(payload: Dictionary) -> bool:
	return str(payload.get("title", "")).strip_edges() == ""


static func from_entry(entry: Dictionary) -> Dictionary:
	if str(entry.get("kind", "item")) == "equip":
		return from_equip_id(int(entry.get("id", -1)))
	return from_item_id(str(entry.get("id", "")), maxi(1, int(entry.get("count", 1))))


static func from_item_id(item_id: String, count: int = 1) -> Dictionary:
	var iid := item_id.strip_edges()
	if iid == "":
		return {}
	var def := _item_def(iid)
	if def == null:
		return {}
	var icon := ItemDefScript.resolve_icon_texture(def.icon_path, null)
	var detail_lines := _item_detail_lines(def)
	var footer_lines: PackedStringArray = []
	if count > 0:
		footer_lines.append(StringsZh.format_template(
			StringsZh.getp("item_info.count", "数量：{value}"),
			{"value": str(count)}
		))
	if def.base_ling_shi > 0:
		footer_lines.append(StringsZh.format_template(
			StringsZh.getp("item_info.price", "灵石估价：{value}"),
			{"value": str(def.base_ling_shi)}
		))
	return {
		"title": def.name,
		"title_color": EnumQuality.get_color(def.quality),
		"icon": icon,
		"quality": def.rarity,
		"meta": _item_meta(def),
		"desc": def.desc.strip_edges(),
		"detail_lines": detail_lines,
		"footer": "\n".join(footer_lines),
	}


static func from_equip_id(equip_id: int) -> Dictionary:
	if equip_id <= 0:
		return {}
	var cfg := ConfigManager.equip_by_id(equip_id)
	if cfg.is_empty():
		return {}
	var title := str(cfg.get("name", "法宝")).strip_edges()
	var quality := maxi(1, int(cfg.get("quality", 1)))
	var detail_lines: Array[String] = []
	detail_lines.append(StringsZh.getp("item_info.equip_kind", "战斗法宝"))
	var mp_cost := float(cfg.get("mp_cost", 0.0))
	if mp_cost > 0.0:
		detail_lines.append(StringsZh.format_template(
			StringsZh.getp("hover.skill.mp_cost", "法力消耗：{value}"),
			{"value": _fmt_num(mp_cost)}
		))
	var cd := float(cfg.get("cd", cfg.get("cd_total", 0.0)))
	if cd > 0.0:
		detail_lines.append(StringsZh.format_template(
			StringsZh.getp("hover.skill.cd", "冷却：{value}秒"),
			{"value": _fmt_num(cd)}
		))
	for effect_line in HoverTipEffectFormatter.format_lines(cfg.get("effects", [])):
		detail_lines.append(effect_line)
	var rarity := _rarity_label_from_int(quality)
	return {
		"title": title,
		"title_color": EnumQuality.get_color(quality),
		"icon": BattleInitDataScript._resolve_icon_texture(cfg),
		"quality": rarity,
		"meta": StringsZh.format_template(
			StringsZh.getp("item_info.type", "类型：{value}"),
			{"value": StringsZh.getp("item_info.type_equip", "法宝")}
		) + " · " + StringsZh.format_template(
			StringsZh.getp("item_info.rarity", "品质：{value}"),
			{"value": rarity}
		),
		"desc": str(cfg.get("desc", "")).strip_edges(),
		"detail_lines": detail_lines,
		"footer": "",
	}


static func _item_meta(def: ItemDef) -> String:
	var parts: PackedStringArray = []
	var item_type := def.item_type.strip_edges()
	if item_type != "":
		parts.append(StringsZh.format_template(
			StringsZh.getp("item_info.type", "类型：{value}"),
			{"value": item_type}
		))
	var rarity := def.rarity.strip_edges()
	if rarity != "":
		parts.append(StringsZh.format_template(
			StringsZh.getp("item_info.rarity", "品质：{value}"),
			{"value": rarity}
		))
	if def.stackable and def.max_stack > 1:
		parts.append(StringsZh.format_template(
			StringsZh.getp("item_info.stack", "可堆叠（上限 {value}）"),
			{"value": str(def.max_stack)}
		))
	return " · ".join(parts)


static func _item_detail_lines(def: ItemDef) -> Array[String]:
	var lines: Array[String] = []
	for use_line in _format_use_effect_lines(def.use_effect):
		lines.append(use_line)
	if def.has_fight_config():
		if def.fight_mp_cost > 0.0:
			lines.append(StringsZh.format_template(
				StringsZh.getp("item_info.fight_mp_cost", "战斗消耗：法力 {value}"),
				{"value": _fmt_num(def.fight_mp_cost)}
			))
		if def.fight_cd > 0.0:
			lines.append(StringsZh.format_template(
				StringsZh.getp("item_info.fight_cd", "战斗冷却：{value} 秒"),
				{"value": _fmt_num(def.fight_cd)}
			))
		for effect_line in HoverTipEffectFormatter.format_lines(def.fight_effect):
			lines.append(effect_line)
	elif def.fight_id > 0:
		var fight_cfg := ConfigManager.item_by_fight_id(def.fight_id)
		if not fight_cfg.is_empty():
			if float(fight_cfg.get("mp_cost", 0.0)) > 0.0:
				lines.append(StringsZh.format_template(
					StringsZh.getp("item_info.fight_mp_cost", "战斗消耗：法力 {value}"),
					{"value": _fmt_num(float(fight_cfg.get("mp_cost", 0.0)))}
				))
			if float(fight_cfg.get("cd", fight_cfg.get("cd_total", 0.0))) > 0.0:
				lines.append(StringsZh.format_template(
					StringsZh.getp("item_info.fight_cd", "战斗冷却：{value} 秒"),
					{"value": _fmt_num(float(fight_cfg.get("cd", fight_cfg.get("cd_total", 0.0))))}
				))
			for effect_line in HoverTipEffectFormatter.format_lines(fight_cfg.get("effects", [])):
				lines.append(effect_line)
	return lines


static func _format_use_effect_lines(use_effect: Array) -> Array[String]:
	var lines: Array[String] = []
	for row_v in use_effect:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		var op := str(row.get("op", "")).strip_edges().to_lower()
		var args_v: Variant = row.get("args", [])
		var amount := 0.0
		if args_v is Array and not (args_v as Array).is_empty():
			amount = float((args_v as Array)[0])
		match op:
			"hp":
				if amount != 0.0:
					lines.append(StringsZh.format_template(
						StringsZh.getp("item_info.use_hp", "使用效果：恢复气血 {value}"),
						{"value": _fmt_num(amount)}
					))
			"mp":
				if amount != 0.0:
					lines.append(StringsZh.format_template(
						StringsZh.getp("item_info.use_mp", "使用效果：恢复法力 {value}"),
						{"value": _fmt_num(amount)}
					))
			"heart_demon":
				if amount != 0.0:
					lines.append(StringsZh.format_template(
						StringsZh.getp("item_info.use_heart_demon", "使用效果：心魔 {value}"),
						{"value": _fmt_num(amount)}
					))
	return lines


static func _rarity_label_from_int(quality: int) -> String:
	if quality >= 5:
		return "传说"
	if quality >= 3:
		return "稀有"
	return "普通"


static func _fmt_num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%0.1f" % value


static func _item_def(item_id: String) -> ItemDef:
	if ConfigManager != null:
		return ConfigManager.item_def_by_id(item_id)
	return null

