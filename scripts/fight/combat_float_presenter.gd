class_name CombatFloatPresenter
extends RefCounted
const CombatReportScript = preload("res://scripts/fight/combat_report.gd")
const BattleRecordTypesScript := preload("res://scripts/fight/battle_record_types.gd")


static func build_spawns(
		source_id: String,
		target_id: String,
		report: Dictionary,
		cfg: Dictionary,
		context: Dictionary = {}
) -> Array:
	report = CombatReportScript.normalize_report(report)
	var out: Array = []
	var suppress_skill_line := bool(context.get("suppress_skill_line", false))
	var damage_suffix := str(context.get("damage_suffix", "")).strip_edges()
	var skill_name := str(cfg.get("name", "")).strip_edges()
	var basic_name := StringsZh.getp("combat.float.basic_attack", "普攻")
	var is_basic_attack := bool(cfg.get("is_basic_attack", false))
	if skill_name == "":
		is_basic_attack = true
		skill_name = basic_name
	elif skill_name == basic_name:
		is_basic_attack = true
	if not suppress_skill_line and not is_basic_attack:
		_append_spawn(out, skill_name, source_id, "skill", 2)
	_append_shield_spawn(out, target_id, float(report.get("shield_absorbed", 0.0)))
	_append_damage_spawn(
		out,
		target_id,
		float(report.get("damage", 0.0)),
		bool(report.get("is_crit", false)),
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
		var prefix := StringsZh.getp("combat.float.buff_prefix", "")
		for name_v in buff_names_v as Array:
			var bname := str(name_v).strip_edges()
			if bname == "":
				continue
			var line := ("%s %s" % [prefix, bname]).strip_edges() if prefix != "" else bname
			_append_spawn(out, line, target_id, "buff_add", 6)

	if out.is_empty():
		# 便于调试飘字缺失问题。
		BattleDebugLog.write("飘字", "CombatFloatPresenter.build_spawns 结果为空", {
			"来源": BattleDebugLog.side_label(source_id),
			"目标": BattleDebugLog.side_label(target_id),
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
		_buff_name: String,
		names: Dictionary = {}
) -> Array:
	var target_name := _display_name(unit_id, names)
	if target_name == "":
		target_name = BattleDebugLog.side_label(unit_id)
	return build_spawns(
		unit_id,
		unit_id,
		report,
		{"name": target_name, "is_basic_attack": false}
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
		is_crit: bool,
		damage_suffix: String
) -> void:
	if damage <= 0.0:
		return
	var tone := "crit" if is_crit else "damage"
	var dmg_tpl := StringsZh.getp("combat.float.crit", "-%d！") if is_crit else StringsZh.getp("combat.float.damage", "-%d")
	var dmg_text := StringsZh.format_template(dmg_tpl, {"value": int(roundf(damage))})
	var suffix := damage_suffix.strip_edges()
	if suffix != "":
		dmg_text = "%s %s" % [dmg_text, suffix]
	_append_spawn(out, dmg_text, target_id, tone, 7)


static func _display_name(unit_id: String, names: Dictionary) -> String:
	var uid := unit_id.strip_edges()
	if uid == "":
		return ""
	if names.has(uid):
		return str(names.get(uid, uid)).strip_edges()
	match uid:
		BattleRecordTypesScript.UNIT_PLAYER:
			return "玩家"
		BattleRecordTypesScript.UNIT_ENEMY:
			return "敌方"
		_:
			return uid


static func _get_config_manager() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")
