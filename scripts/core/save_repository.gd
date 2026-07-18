class_name SaveRepository
extends RefCounted

const SCHEMA_VERSION := 2
const AUTO_SAVE_PATH := "user://saves/autosave.json"
const AUTO_SAVE_TEMP_PATH := "user://saves/autosave.tmp"
const AUTO_SAVE_BACKUP_PATH := "user://saves/autosave.bak"


static func save_auto(data: Dictionary) -> Dictionary:
	var directory_result := DirAccess.make_dir_recursive_absolute("user://saves")
	if directory_result != OK and directory_result != ERR_ALREADY_EXISTS:
		return {"ok": false, "error": "无法创建自动存档目录"}
	var envelope := {
		"schema_version": SCHEMA_VERSION,
		"app_version": "phase2",
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"slot_id": 1,
		"payload": data.duplicate(true),
	}
	var file := FileAccess.open(AUTO_SAVE_TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "无法写入自动存档临时文件"}
	file.store_string(JSON.stringify(envelope, "\t"))
	file.close()
	var checked := _read_envelope(AUTO_SAVE_TEMP_PATH)
	if not bool(checked.get("ok", false)):
		DirAccess.remove_absolute(AUTO_SAVE_TEMP_PATH)
		return {"ok": false, "error": "自动存档临时文件校验失败"}
	if FileAccess.file_exists(AUTO_SAVE_PATH):
		DirAccess.remove_absolute(AUTO_SAVE_BACKUP_PATH)
		if DirAccess.rename_absolute(AUTO_SAVE_PATH, AUTO_SAVE_BACKUP_PATH) != OK:
			DirAccess.remove_absolute(AUTO_SAVE_TEMP_PATH)
			return {"ok": false, "error": "无法备份现有自动存档"}
	if DirAccess.rename_absolute(AUTO_SAVE_TEMP_PATH, AUTO_SAVE_PATH) != OK:
		if FileAccess.file_exists(AUTO_SAVE_BACKUP_PATH):
			DirAccess.rename_absolute(AUTO_SAVE_BACKUP_PATH, AUTO_SAVE_PATH)
		return {"ok": false, "error": "无法替换自动存档"}
	var reread := _read_envelope(AUTO_SAVE_PATH)
	if not bool(reread.get("ok", false)):
		DirAccess.remove_absolute(AUTO_SAVE_PATH)
		if FileAccess.file_exists(AUTO_SAVE_BACKUP_PATH):
			DirAccess.rename_absolute(AUTO_SAVE_BACKUP_PATH, AUTO_SAVE_PATH)
		return {"ok": false, "error": "自动存档重读校验失败"}
	return {"ok": true, "saved_at_unix": int(envelope["saved_at_unix"])}


static func load_auto() -> Dictionary:
	return _read_envelope(AUTO_SAVE_PATH)


static func restore_auto_backup() -> Dictionary:
	if not FileAccess.file_exists(AUTO_SAVE_BACKUP_PATH):
		return {"ok": false, "error": "没有自动存档备份"}
	var checked := _read_envelope(AUTO_SAVE_BACKUP_PATH)
	if not bool(checked.get("ok", false)):
		return {"ok": false, "error": "自动存档备份损坏"}
	if FileAccess.file_exists(AUTO_SAVE_PATH):
		DirAccess.remove_absolute(AUTO_SAVE_PATH)
	if DirAccess.rename_absolute(AUTO_SAVE_BACKUP_PATH, AUTO_SAVE_PATH) != OK:
		return {"ok": false, "error": "无法恢复自动存档备份"}
	return _read_envelope(AUTO_SAVE_PATH)


static func _read_envelope(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "自动存档不存在"}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"ok": false, "error": "自动存档损坏"}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return {"ok": false, "error": "自动存档根节点无效"}
	var envelope := parsed as Dictionary
	if int(envelope.get("schema_version", -1)) != SCHEMA_VERSION:
		return {"ok": false, "error": "自动存档版本不兼容"}
	if str(envelope.get("app_version", "")).strip_edges() == "":
		return {"ok": false, "error": "自动存档缺少应用版本"}
	if int(envelope.get("slot_id", -1)) != 1:
		return {"ok": false, "error": "自动存档槽位无效"}
	var payload_v: Variant = envelope.get("payload")
	if not payload_v is Dictionary:
		return {"ok": false, "error": "自动存档缺少游戏状态"}
	return {
		"ok": true,
		"payload": (payload_v as Dictionary).duplicate(true),
		"saved_at_unix": int(envelope.get("saved_at_unix", 0)),
	}
