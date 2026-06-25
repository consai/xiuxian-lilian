class_name BattleStats
extends RefCounted

const BattleRecordTypesScript := preload("res://scripts/fight/battle_record_types.gd")
const CombatReportScript := preload("res://scripts/fight/combat_report.gd")

var _by_unit: Dictionary = {}


func reset() -> void:
	_by_unit = {}


func ensure_unit(unit_id: String) -> void:
	var uid := unit_id.strip_edges()
	if uid == "":
		return
	if _by_unit.has(uid):
		return
	_by_unit[uid] = {
		"damage_dealt": 0.0,
		"damage_taken": 0.0,
		"heal": 0.0,
		"shield_absorbed": 0.0,
		"by_action_kind": {},
	}


func record_entry(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	var src := str(entry.get("source_id", "")).strip_edges()
	var tgt := str(entry.get("target_id", "")).strip_edges()
	if src != "":
		ensure_unit(src)
	if tgt != "":
		ensure_unit(tgt)

	var kind := str(entry.get("action_kind", "")).strip_edges()
	if kind != "" and src != "":
		var row := _by_unit.get(src, {}) as Dictionary
		var by_kind: Dictionary = row.get("by_action_kind", {}) as Dictionary
		by_kind[kind] = int(by_kind.get(kind, 0)) + 1
		row["by_action_kind"] = by_kind
		_by_unit[src] = row

	var report_v: Variant = entry.get("report", {})
	if report_v is Dictionary:
		var report := CombatReportScript.normalize_report(report_v as Dictionary)
		var hp_damage := float(report.get(CombatReportScript.KEY_HP_DAMAGE, 0.0))
		var heal := float(report.get(CombatReportScript.KEY_HEAL, 0.0))
		var shield_abs := float(report.get(CombatReportScript.KEY_SHIELD_ABSORBED, 0.0))

		if src != "":
			var src_row := _by_unit.get(src, {}) as Dictionary
			src_row["damage_dealt"] = float(src_row.get("damage_dealt", 0.0)) + maxf(0.0, hp_damage)
			src_row["heal"] = float(src_row.get("heal", 0.0)) + maxf(0.0, heal)
			src_row["shield_absorbed"] = float(src_row.get("shield_absorbed", 0.0)) + maxf(0.0, shield_abs)
			_by_unit[src] = src_row

		if tgt != "":
			var tgt_row := _by_unit.get(tgt, {}) as Dictionary
			tgt_row["damage_taken"] = float(tgt_row.get("damage_taken", 0.0)) + maxf(0.0, hp_damage)
			_by_unit[tgt] = tgt_row


func get_unit(unit_id: String) -> Dictionary:
	var uid := unit_id.strip_edges()
	if uid == "":
		return {}
	if not _by_unit.has(uid):
		ensure_unit(uid)
	return (_by_unit.get(uid, {}) as Dictionary).duplicate(true)


func to_dict() -> Dictionary:
	return _by_unit.duplicate(true)

