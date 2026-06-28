class_name ZhandouRecordFormatter
extends RefCounted

const ZhandouRecordTypesScript := preload("res://scripts/zhandou/zhandou_record_types.gd")
const ZhandouReportScript := preload("res://scripts/zhandou/zhandou_report.gd")

const _COL_PLAYER := "#8b4513"
const _COL_ENEMY := "#4a3d6b"
const _COL_NEUTRAL := "#3d3d3d"
const _COL_BUFF := "#9a7b2e"


func format_entry(entry: Dictionary, names: Dictionary = {}) -> String:
	if entry.is_empty():
		return ""
	var src := str(entry.get("source_id", "")).strip_edges()
	var tgt := str(entry.get("target_id", "")).strip_edges()
	var src_name := _display_name(src, names)
	var tgt_name := _display_name(tgt, names)
	var kind := str(entry.get("action_kind", "")).strip_edges()
	var action_name := str(entry.get("action_name", "")).strip_edges()
	var report_v: Variant = entry.get("report", {})
	var report: Dictionary = (ZhandouReportScript.normalize_report(report_v as Dictionary) if report_v is Dictionary else ZhandouReportScript.empty_fx_report())

	var hp_damage := float(report.get(ZhandouReportScript.KEY_HP_DAMAGE, 0.0))
	var heal := float(report.get(ZhandouReportScript.KEY_HEAL, 0.0))
	var shield_abs := float(report.get(ZhandouReportScript.KEY_SHIELD_ABSORBED, 0.0))
	var missed := bool(report.get(ZhandouReportScript.KEY_MISSED, false))
	var resisted := bool(report.get(ZhandouReportScript.KEY_CONTROL_RESISTED, false))

	var parts: PackedStringArray = PackedStringArray()
	if kind == ZhandouRecordTypesScript.ACTION_BUFF_TICK:
		var buff_label := action_name.strip_edges()
		if buff_label == "":
			buff_label = str(report.get(ZhandouReportScript.KEY_BUFF_NAME, "")).strip_edges()
		if buff_label == "":
			buff_label = "持续伤害"
		parts.append(_colored(buff_label, _COL_BUFF))
		if tgt_name != "":
			parts.append("→")
			parts.append(_colored(tgt_name, _color_for_unit(tgt)))
		var tick_tail: PackedStringArray = PackedStringArray()
		if hp_damage > 0.0:
			tick_tail.append("-%d" % int(round(hp_damage)))
		if shield_abs > 0.0:
			if hp_damage <= 0.0:
				tick_tail.append(_colored("护盾吸收 %d" % int(round(shield_abs)), _COL_NEUTRAL))
			else:
				tick_tail.append(_colored("(护盾吸收 %d)" % int(round(shield_abs)), _COL_NEUTRAL))
		if not tick_tail.is_empty():
			parts.append(" ".join(tick_tail))
		return " ".join(parts)

	if src_name != "":
		parts.append(_colored(src_name, _color_for_unit(src)))

	var verb := "使用"
	if kind == ZhandouRecordTypesScript.ACTION_BASIC:
		verb = "普攻"
	elif kind == ZhandouRecordTypesScript.ACTION_ITEM:
		verb = "使用道具"
	elif kind == ZhandouRecordTypesScript.ACTION_EQUIP:
		verb = "催动法器"
	parts.append(verb)
	if action_name != "":
		parts.append("【%s】" % action_name)

	if tgt_name != "":
		parts.append("→")
		parts.append(_colored(tgt_name, _color_for_unit(tgt)))
	_append_buff_names(parts, report)

	var tail: PackedStringArray = PackedStringArray()
	if missed:
		tail.append("未命中")
	if resisted:
		tail.append("抵抗")
	if hp_damage > 0.0:
		tail.append("-%d" % int(round(hp_damage)))
	if heal > 0.0:
		tail.append("+%d" % int(round(heal)))
	if shield_abs > 0.0 and hp_damage <= 0.0:
		tail.append("护盾吸收 %d" % int(round(shield_abs)))
	if not tail.is_empty():
		parts.append(" ".join(tail))

	return " ".join(parts)


func format_summary(summary: Dictionary) -> String:
	if summary.is_empty():
		return ""
	var outcome := str(summary.get("outcome", "")).strip_edges()
	var reason := str(summary.get("end_reason", "")).strip_edges()
	var duration := float(summary.get("duration_advancing", 0.0))
	var action_count := int(summary.get("action_count", 0))
	var tick_count := int(summary.get("tick_count", 0))
	var event_count := int(summary.get("event_count", action_count + tick_count))

	var title := "战斗结束"
	match outcome:
		ZhandouRecordTypesScript.OUTCOME_WIN:
			title = "胜利"
		ZhandouRecordTypesScript.OUTCOME_LOSS:
			title = "战败"
		ZhandouRecordTypesScript.OUTCOME_DRAW:
			title = "平局"
		ZhandouRecordTypesScript.OUTCOME_ESCAPED:
			title = "脱身"
		_:
			pass

	var lines: PackedStringArray = PackedStringArray()
	lines.append("[b]%s[/b]" % title)
	lines.append("推进时间：%.1fs" % duration)
	lines.append("事件数：%d（出手 %d，DOT %d）" % [event_count, action_count, tick_count])
	if reason != "":
		lines.append("结束原因：%s" % reason)

	var p: Variant = summary.get("player_stats", {})
	var e: Variant = summary.get("enemy_stats", {})
	if p is Dictionary:
		lines.append("")
		lines.append("[b]%s[/b]" % _colored("玩家", _COL_PLAYER))
		lines.append(_format_stats_block(p as Dictionary))
	if e is Dictionary:
		lines.append("")
		lines.append("[b]%s[/b]" % _colored("敌方", _COL_ENEMY))
		lines.append(_format_stats_block(e as Dictionary))

	return "\n".join(lines).strip_edges()


func _format_stats_block(stats: Dictionary) -> String:
	var dmg := int(round(float(stats.get("damage_dealt", 0.0))))
	var taken := int(round(float(stats.get("damage_taken", 0.0))))
	var heal := int(round(float(stats.get("heal", 0.0))))
	var shield_abs := int(round(float(stats.get("shield_absorbed", 0.0))))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("造成伤害：%d" % dmg)
	lines.append("承受伤害：%d" % taken)
	lines.append("治疗量：%d" % heal)
	lines.append("护盾吸收：%d" % shield_abs)
	return "\n".join(lines)


func _display_name(unit_id: String, names: Dictionary) -> String:
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


func _color_for_unit(unit_id: String) -> String:
	match unit_id.strip_edges():
		ZhandouRecordTypesScript.UNIT_PLAYER:
			return _COL_PLAYER
		ZhandouRecordTypesScript.UNIT_ENEMY:
			return _COL_ENEMY
		_:
			return _COL_NEUTRAL


func _append_buff_names(parts: PackedStringArray, report: Dictionary) -> void:
	var buff_names_v: Variant = report.get(ZhandouReportScript.KEY_BUFF_NAMES, [])
	if not buff_names_v is Array:
		return
	for name_v in buff_names_v as Array:
		var bname := str(name_v).strip_edges()
		if bname == "":
			continue
		parts.append(_colored("【%s】" % bname, _COL_BUFF))


static func _colored(text: String, color_hex: String) -> String:
	var t := text.strip_edges()
	if t == "":
		return ""
	return "[color=%s]%s[/color]" % [color_hex, t]
