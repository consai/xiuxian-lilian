class_name ZhandouFloatPresenter
extends RefCounted
const ZhandouReportScript = preload("res://scripts/zhandou/zhandou_report.gd")
const ZhandouRecordTypesScript := preload("res://scripts/zhandou/zhandou_record_types.gd")


static func build_spawns(
		source_id: String,
		target_id: String,
		report: Dictionary,
		cfg: Dictionary,
		context: Dictionary = {}
) -> Array:
	report = ZhandouReportScript.normalize_report(report)
	var out: Array = []
	var suppress_skill_line := bool(context.get("suppress_skill_line", false))
	var damage_suffix := str(context.get("damage_suffix", "")).strip_edges()
	var skill_name := str(cfg.get("name", "")).strip_edges()
	var tiaoxi_name := StringsZh.getp("combat.float.tiaoxi", "调息")
	var is_tiaoxi := bool(cfg.get("is_tiaoxi", false))
	if skill_name == "":
		is_tiaoxi = true
		skill_name = tiaoxi_name
	elif skill_name == tiaoxi_name:
		is_tiaoxi = true
	if not suppress_skill_line and not is_tiaoxi:
		_append_spawn(out, skill_name, source_id, "skill", 2)
	if bool(report.get(ZhandouReportScript.KEY_MISSED, false)):
		_append_spawn(out, "未命中", target_id, "buff_expire", 8)
	if bool(report.get(ZhandouReportScript.KEY_CONTROL_RESISTED, false)):
		_append_spawn(out, "抵抗", target_id, "buff_expire", 8)
	_append_shield_spawn(out, _status_effect_unit_id(source_id, target_id, cfg), float(report.get("shield_absorbed", 0.0)))
	_append_damage_spawn(
		out,
		target_id,
		float(report.get("damage", 0.0)),
		damage_suffix
	)

	var heal := float(report.get("heal", 0.0))
	if heal > 0.0:
		var heal_text := StringsZh.format_template(
			StringsZh.getp("combat.float.heal", "+%d"),
			{"value": int(roundf(heal))}
		)
		_append_spawn(out, heal_text, source_id, "heal", 5)

	var mp_gain := float(report.get("mp_gain", 0.0))
	if mp_gain > 0.0:
		var mp_g_text := StringsZh.format_template(
			StringsZh.getp("combat.float.mp_gain", "+%d MP"),
			{"value": int(roundf(mp_gain))}
		)
		_append_spawn(out, mp_g_text, source_id, "mp_gain", 3)

	var buff_names_v: Variant = report.get("buff_names", [])
	if buff_names_v is Array:
		var buff_unit_id := _status_effect_unit_id(source_id, target_id, cfg)
		var prefix := StringsZh.getp("combat.float.buff_prefix", "")
		for name_v in buff_names_v as Array:
			var bname := str(name_v).strip_edges()
			if bname == "":
				continue
			var line := ("%s %s" % [prefix, bname]).strip_edges() if prefix != "" else bname
			_append_spawn(out, line, buff_unit_id, "buff_add", 6)

	if out.is_empty():
		# 便于调试飘字缺失问题。
		ZhandouDebugLog.write("飘字", "ZhandouFloatPresenter.build_spawns 结果为空", {
			"来源": ZhandouDebugLog.side_label(source_id),
			"目标": ZhandouDebugLog.side_label(target_id),
			"damage": report.get("damage", 0.0),
			"heal": report.get("heal", 0.0),
			"mp_gain": report.get("mp_gain", 0.0),
			"shield_absorbed": report.get("shield_absorbed", 0.0),
			"buff_names": report.get("buff_names", []),
		})
	return out


static func build_buff_tick_spawns(
		unit_id: String,
		report: Dictionary,
		buff_name: String,
		_names: Dictionary = {}
) -> Array:
	var line_name := buff_name.strip_edges()
	if line_name == "":
		line_name = StringsZh.getp("combat.float.buff_tick", "状态")
	return build_spawns(
		unit_id,
		unit_id,
		report,
		{"name": line_name, "is_tiaoxi": false}
	)


static func build_buff_expire_spawn(buff_id: String, unit_id: String) -> Dictionary:
	var bname := buff_id.strip_edges()
	var cm := _get_config_manager()
	if cm != null and cm.has_method("buff_by_id"):
		var row: Dictionary = cm.call("buff_by_id", bname) as Dictionary
		if not row.is_empty():
			bname = str(row.get("name", bname)).strip_edges()
	var text := StringsZh.format_template(
		StringsZh.getp("combat.float.buff_expire", "%s 消散"),
		{"name": bname}
	)
	return {"text": text, "unit_id": unit_id, "tone": "buff_expire", "priority": 0}


static func _status_effect_unit_id(source_id: String, target_id: String, cfg: Dictionary) -> String:
	# 技能 combat.target=self 时，buff/护盾等状态效果落在施法者身上，飘字应跟随受效单位
	if str(cfg.get("target", "")).strip_edges().to_lower() == EnumZhandouTarget.LABEL_SELF:
		return source_id
	return target_id


static func _append_spawn(out: Array, text: String, unit_id: String, tone: String, priority: int) -> void:
	if text.strip_edges() == "":
		return
	out.append({
		"text": text,
		"unit_id": unit_id,
		"tone": tone,
		"priority": priority,
	})


static func _append_shield_spawn(out: Array, target_id: String, shield_abs: float) -> void:
	if shield_abs <= 0.0:
		return
	var shield_label := StringsZh.getp("combat.float.shield_absorb", "吸收")
	var shield_text := "%s(%d)" % [shield_label, int(roundf(shield_abs))]
	_append_spawn(out, shield_text, target_id, "shield", 4)


static func _append_damage_spawn(
		out: Array,
		target_id: String,
		damage: float,
		damage_suffix: String
) -> void:
	if damage <= 0.0:
		return
	var dmg_tpl := StringsZh.getp("combat.float.damage", "-%d")
	var dmg_text := StringsZh.format_template(dmg_tpl, {"value": int(roundf(damage))})
	var suffix := damage_suffix.strip_edges()
	if suffix != "":
		dmg_text = "%s %s" % [dmg_text, suffix]
	_append_spawn(out, dmg_text, target_id, "damage", 7)


static func _display_name(unit_id: String, names: Dictionary) -> String:
	var uid := unit_id.strip_edges()
	if uid == "":
		return ""
	if names.has(uid):
		return str(names.get(uid, uid)).strip_edges()
	match uid:
		ZhandouRecordTypesScript.UNIT_PLAYER:
			return "玩家"
		ZhandouRecordTypesScript.UNIT_ENEMY:
			return "敌方"
		_:
			return uid


static func _get_config_manager() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")
