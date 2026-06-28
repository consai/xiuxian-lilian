class_name ZhandouRecorder
extends RefCounted

const ZhandouRecordTypesScript := preload("res://scripts/zhandou/zhandou_record_types.gd")
const ZhandouStatsScript := preload("res://scripts/zhandou/zhandou_stats.gd")
const ZhandouReportScript := preload("res://scripts/zhandou/zhandou_report.gd")

const _MAX_ENTRIES := 200

var _seq: int = 0
var _entries: Array = []
var _stats: ZhandouStats = ZhandouStatsScript.new()
var _meta: Dictionary = {}

var _action_count: int = 0
var _tick_count: int = 0


func begin(meta: Dictionary = {}) -> void:
	_seq = 0
	_entries = []
	_stats.reset()
	_meta = meta.duplicate(true) if meta != null else {}
	_action_count = 0
	_tick_count = 0


func get_entries() -> Array:
	return _entries.duplicate(true)


func get_entries_tail(max_count: int) -> Array:
	var n := maxi(0, max_count)
	if n <= 0 or _entries.is_empty():
		return []
	if _entries.size() <= n:
		return _entries.duplicate(true)
	return (_entries.slice(_entries.size() - n, _entries.size()) as Array).duplicate(true)


func get_stats() -> Dictionary:
	return _stats.to_dict()


func record_resolution(payload: Dictionary, descriptor: Dictionary, at_advancing: float) -> Dictionary:
	if payload == null or not bool(payload.get("ok", false)):
		return {}
	var src := str(payload.get("source_id", "")).strip_edges()
	var tgt := str(payload.get("target_id", "")).strip_edges()
	if src == "" or tgt == "":
		return {}

	var action_kind := str(descriptor.get("action_kind", "")).strip_edges()
	var action_id := int(descriptor.get("action_id", -1))
	var action_name := str(descriptor.get("action_name", "")).strip_edges()
	if action_kind == "":
		action_kind = ZhandouRecordTypesScript.ACTION_SKILL
	if action_name == "":
		var cfg_v: Variant = payload.get("cfg", {})
		if cfg_v is Dictionary:
			action_name = str((cfg_v as Dictionary).get("name", "")).strip_edges()

	var report_v: Variant = payload.get("report", {})
	var report: Dictionary = (ZhandouReportScript.normalize_report(report_v as Dictionary) if report_v is Dictionary else ZhandouReportScript.empty_fx_report())

	var entry := {
		"schema_version": ZhandouRecordTypesScript.SCHEMA_VERSION,
		"seq": _seq,
		"at_advancing": maxf(0.0, at_advancing),
		"source_id": src,
		"target_id": tgt,
		"action_kind": action_kind,
		"action_id": action_id,
		"action_name": action_name,
		"report": report,
	}
	_seq += 1
	_action_count += 1
	_append_entry(entry)
	_stats.record_entry(entry)
	return entry.duplicate(true)


func record_buff_tick(victim_unit_id: String, report: Dictionary, buff_name: String, at_advancing: float) -> Dictionary:
	var victim := victim_unit_id.strip_edges()
	if victim == "":
		return {}
	var src := ZhandouRecordTypesScript.opposite_unit(victim)
	if src == "":
		return {}
	var normalized := ZhandouReportScript.normalize_report(report)
	var hp_damage := float(normalized.get(ZhandouReportScript.KEY_DAMAGE, 0.0))
	var shield_abs := float(normalized.get(ZhandouReportScript.KEY_SHIELD_ABSORBED, 0.0))
	if hp_damage <= 0.0 and shield_abs <= 0.0:
		return {}
	var label := buff_name.strip_edges()
	if label == "":
		label = str(normalized.get(ZhandouReportScript.KEY_BUFF_NAME, "")).strip_edges()

	var entry := {
		"schema_version": ZhandouRecordTypesScript.SCHEMA_VERSION,
		"seq": _seq,
		"at_advancing": maxf(0.0, at_advancing),
		"source_id": src,
		"target_id": victim,
		"action_kind": ZhandouRecordTypesScript.ACTION_BUFF_TICK,
		"action_id": 0,
		"action_name": label,
		"report": normalized,
	}
	_seq += 1
	_tick_count += 1
	_append_entry(entry)
	_stats.record_entry(entry)
	return entry.duplicate(true)


func finalize(end_reason: String, duration_advancing: float, names: Dictionary = {}) -> Dictionary:
	var reason := end_reason.strip_edges()
	var outcome := ZhandouRecordTypesScript.OUTCOME_DRAW
	match reason:
		"enemy_dead":
			outcome = ZhandouRecordTypesScript.OUTCOME_WIN
		"player_dead":
			outcome = ZhandouRecordTypesScript.OUTCOME_LOSS
		"time_limit":
			outcome = ZhandouRecordTypesScript.OUTCOME_LOSS
		"player_escaped":
			outcome = ZhandouRecordTypesScript.OUTCOME_ESCAPED
		_:
			outcome = ZhandouRecordTypesScript.OUTCOME_DRAW

	var player_stats := _stats.get_unit(ZhandouRecordTypesScript.UNIT_PLAYER)
	var enemy_stats := _stats.get_unit(ZhandouRecordTypesScript.UNIT_ENEMY)

	var summary := {
		"schema_version": ZhandouRecordTypesScript.SCHEMA_VERSION,
		"session_id": str(_meta.get("session_id", "")),
		"player_name": str(names.get(ZhandouRecordTypesScript.UNIT_PLAYER, _meta.get("player_name", ""))),
		"enemy_name": str(names.get(ZhandouRecordTypesScript.UNIT_ENEMY, _meta.get("enemy_name", ""))),
		"end_reason": reason,
		"outcome": outcome,
		"duration_advancing": maxf(0.0, duration_advancing),
		"action_count": _action_count,
		"tick_count": _tick_count,
		"event_count": _action_count + _tick_count,
		"player_stats": player_stats,
		"enemy_stats": enemy_stats,
	}
	return summary


func _append_entry(entry: Dictionary) -> void:
	_entries.append(entry)
	if _entries.size() > _MAX_ENTRIES:
		_entries = _entries.slice(_entries.size() - _MAX_ENTRIES, _entries.size())

