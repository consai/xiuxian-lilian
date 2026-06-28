class_name ItemInfoPayloadBuilder
extends RefCounted

const AbilityServiceScript := preload("res://scripts/dao/ability_service.gd")
const LiandanServiceScript := preload("res://scripts/sim/liandan_service.gd")
const ZhandouInitDataScript := preload("res://scripts/zhandou/zhandou_init_data.gd")
const XiulianMethodServiceScript := preload("res://scripts/sim/xiulian_method_service.gd")
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
	var use_action := _use_action_for_def(def)
	var learn_blocked := learning_book_condition_unmet(def)
	return {
		"item_id": iid,
		"count": count,
		"title": def.name,
		"title_color": EnumQuality.get_color(def.quality),
		"icon": icon,
		"quality": EnumQuality.display_label(def.quality),
		"tier": def.tier,
		"meta": _item_meta(def),
		"desc": def.desc.strip_edges(),
		"detail_lines": detail_lines,
		"footer": "\n".join(footer_lines),
		"can_use": bool(use_action.get("can_use", false)),
		"use_label": str(use_action.get("label", "")),
		"learn_blocked": learn_blocked,
	}


static func from_equip_id(equip_id: int) -> Dictionary:
	if equip_id <= 0:
		return {}
	var cfg := ConfigManager.equip_by_id(equip_id)
	if cfg.is_empty():
		return {}
	var title := str(cfg.get("name", "法宝")).strip_edges()
	var quality := maxi(1, int(cfg.get("quality", 1)))
	var tier := maxi(1, int(cfg.get("tier", 1)))
	var detail_lines: Array[String] = []
	detail_lines.append(StringsZh.getp("item_info.equip_kind", "战斗法宝"))
	var cost_text := str(cfg.get("cost_text", "")).strip_edges()
	if cost_text != "":
		detail_lines.append("消耗：%s" % cost_text)
	else:
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
	var quality_label := EnumQuality.display_label(quality)
	return {
		"title": title,
		"title_color": EnumQuality.get_color(quality),
		"icon": ZhandouInitDataScript._resolve_icon_texture(cfg),
		"quality": quality_label,
		"tier": tier,
		"meta": StringsZh.format_template(
			StringsZh.getp("item_info.type", "类型：{value}"),
			{
				"value": EnumItemType.full_label(
					EnumItemType.PRIMARY_TREASURE,
					EnumItemType.SECONDARY_ACTIVE_TREASURE
				)
			}
		) + " · " + StringsZh.format_template(
			"阶位：{value}",
			{"value": EnumItemTier.label(tier)}
		) + " · " + StringsZh.format_template(
			StringsZh.getp("item_info.quality", "品质：{value}"),
			{"value": quality_label}
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
	var quality_label := EnumQuality.display_label(def.quality)
	parts.append(StringsZh.format_template(
		"阶位：{value}",
		{"value": EnumItemTier.label(def.tier)}
	))
	if quality_label != "":
		parts.append(StringsZh.format_template(
			StringsZh.getp("item_info.quality", "品质：{value}"),
			{"value": quality_label}
		))
	if def.stackable and def.max_stack > 1:
		parts.append(StringsZh.format_template(
			StringsZh.getp("item_info.stack", "可堆叠（上限 {value}）"),
			{"value": str(def.max_stack)}
		))
	return " · ".join(parts)


static func _item_detail_lines(def: ItemDef) -> Array[String]:
	var lines: Array[String] = []
	for learn_line in _format_learning_lines(def):
		lines.append(learn_line)
	for use_line in format_use_effect_lines(def.use_effect):
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
			var cost_text := str(fight_cfg.get("cost_text", "")).strip_edges()
			if cost_text != "":
				lines.append("战斗消耗：%s" % cost_text)
			elif float(fight_cfg.get("mp_cost", 0.0)) > 0.0:
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


static func _format_learning_lines(def: ItemDef) -> Array[String]:
	var lines: Array[String] = []
	var ctx := _learning_context()
	var savedata: Dictionary = ctx.get("savedata", {})
	var major_realm := str(ctx.get("major_realm", "qi"))
	if def.learn_ability_id != "":
		var ability := AbilityServiceScript.by_id(def.learn_ability_id)
		var name := str(ability.get("name", def.learn_ability_id))
		lines.append(StringsZh.format_template(
			StringsZh.getp("item_info.learn_ability", "研读习得：技能 {value}"),
			{"value": name}
		))
		_append_unmet_learning_req_lines(
			lines,
			AbilityServiceScript.unmet_learning_requirement_lines(ability, savedata, major_realm)
		)
	elif def.learn_method_id != "":
		var method := XiulianMethodServiceScript.by_id(def.learn_method_id)
		var name := str(method.get("name", def.learn_method_id))
		lines.append(StringsZh.format_template(
			StringsZh.getp("item_info.learn_method", "研读习得：功法 {value}"),
			{"value": name}
		))
		_append_unmet_learning_req_lines(
			lines,
			XiulianMethodServiceScript.unmet_learning_requirement_lines(method, savedata, major_realm)
		)
	if not lines.is_empty():
		lines.append(StringsZh.getp("item_info.learn_hub_hint", "在洞府底部「研读」使用"))
	return lines


static func _append_unmet_learning_req_lines(lines: Array[String], req_lines: Array[String]) -> void:
	if req_lines.is_empty():
		return
	lines.append(StringsZh.getp("item_info.learn_req_header", "学习条件："))
	for req_line in req_lines:
		lines.append("· %s" % req_line)


static func _learning_context() -> Dictionary:
	var savedata: Dictionary = DataStore.savedata if DataStore != null else {}
	var major_realm := str(savedata.get("major_realm", "qi"))
	if GameState != null:
		major_realm = GameState.major_realm_id()
	return {"savedata": savedata, "major_realm": major_realm}


static func _use_action_for_def(def: ItemDef) -> Dictionary:
	if def.is_learning_book() or _has_alchemy_mastery_effect(def):
		return {"can_use": true, "label": StringsZh.getp("item_info.use_study", "研读")}
	return {"can_use": false, "label": ""}


static func _has_alchemy_mastery_effect(def: ItemDef) -> bool:
	for row_v in def.use_effect:
		if not row_v is Dictionary:
			continue
		if str((row_v as Dictionary).get("op", "")).strip_edges().to_lower() == "alchemy_mastery":
			return true
	return false


static func describe_item(def: ItemDef) -> String:
	if def == null:
		return ""
	var parts: PackedStringArray = []
	var desc := def.desc.strip_edges()
	if desc != "":
		parts.append(desc)
	for line in format_use_effect_lines(def.use_effect):
		parts.append(line)
	if def.use_effect.is_empty() and def.is_pill() and def.has_fight_config():
		for effect_line in HoverTipEffectFormatter.format_lines(def.fight_effect):
			parts.append(StringsZh.format_template(
				StringsZh.getp("item_info.use_fight_prefix", "战斗使用：{value}"),
				{"value": effect_line}
			))
	return "\n".join(parts)


static func format_use_effect_lines(use_effect: Array) -> Array[String]:
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
						{"value": _fmt_signed_num(amount)}
					))
			"mp":
				if amount != 0.0:
					lines.append(StringsZh.format_template(
						StringsZh.getp("item_info.use_mp", "使用效果：恢复法力 {value}"),
						{"value": _fmt_signed_num(amount)}
					))
			"heart_demon":
				if amount != 0.0:
					lines.append(StringsZh.format_template(
						StringsZh.getp("item_info.use_heart_demon", "使用效果：心魔 {value}"),
						{"value": _fmt_signed_num(amount)}
					))
			"cultivation":
				if amount != 0.0:
					lines.append(StringsZh.format_template(
						StringsZh.getp("item_info.use_cultivation", "使用效果：修为 +{value}"),
						{"value": _fmt_num(amount)}
					))
			"instability":
				if amount != 0.0:
					lines.append(StringsZh.format_template(
						StringsZh.getp("item_info.use_instability", "使用效果：灵力驳杂 {value}"),
						{"value": _fmt_signed_num(amount)}
					))
			"pill_cultivation":
				if amount != 0.0:
					lines.append(StringsZh.format_template(
						StringsZh.getp("item_info.use_pill_cultivation", "使用效果：修炼「丹药炼化」修为 +{value}"),
						{"value": _fmt_num(amount)}
					))
			"injury":
				if amount != 0.0:
					lines.append(StringsZh.format_template(
						StringsZh.getp("item_info.use_injury", "使用效果：缩短伤势 {value} 日"),
						{"value": _fmt_signed_num(amount)}
					))
			"sell_only":
				lines.append(StringsZh.getp("item_info.use_sell_only", "使用效果：无药效，仅可出售"))
			"alchemy_mastery":
				var recipe_name := "丹方"
				var mastery_gain := 180.0
				if args_v is Array and not (args_v as Array).is_empty():
					var args := args_v as Array
					var recipe := LiandanServiceScript.recipe_by_id(str(args[0]))
					recipe_name = str(recipe.get("pill_name", recipe.get("name", "丹方")))
					if args.size() > 1:
						mastery_gain = float(args[1])
				lines.append(StringsZh.format_template(
					StringsZh.getp("item_info.use_alchemy_mastery", "使用效果：{recipe} 熟练度 +{value}"),
					{"recipe": recipe_name, "value": _fmt_num(mastery_gain)}
				))
	return lines


static func _fmt_num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%0.1f" % value


static func _fmt_signed_num(value: float) -> String:
	if value > 0.0:
		return "+%s" % _fmt_num(value)
	if value < 0.0:
		return "-%s" % _fmt_num(absf(value))
	return "0"


static func learning_book_condition_unmet(def: ItemDef) -> bool:
	if def == null or not def.is_learning_book():
		return false
	var ctx := _learning_context()
	var savedata: Dictionary = ctx.get("savedata", {})
	var major_realm := str(ctx.get("major_realm", "qi"))
	if def.learn_method_id != "":
		var method_id := def.learn_method_id.strip_edges()
		if method_id == "":
			return false
		if (savedata.get("unlocked_methods", []) as Array).has(method_id):
			return false
		return XiulianMethodServiceScript.learning_condition_unmet(method_id, savedata, major_realm)
	var ability_id := def.learn_ability_id.strip_edges()
	if ability_id == "" or AbilityServiceScript.by_id(ability_id).is_empty():
		return false
	# 与 GameState.learn_ability 的「尚未满足学习条件」判断一致（含初始已入栏但未达研读门槛的技能）
	return not AbilityServiceScript.can_learn(ability_id, savedata, major_realm)


static func _item_def(item_id: String) -> ItemDef:
	if ConfigManager != null:
		return ConfigManager.item_def_by_id(item_id)
	return null
